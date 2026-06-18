#!/usr/bin/env Rscript

arg_value <- function(args, name, default = NULL) {
  hit <- which(args == name)
  if (length(hit) == 0) {
    prefix <- paste0(name, "=")
    inline <- args[startsWith(args, prefix)]
    if (length(inline) > 0) {
      return(sub(prefix, "", inline[[length(inline)]], fixed = TRUE))
    }
    return(default)
  }
  if (hit[[length(hit)]] == length(args)) {
    stop("Missing value for ", name, call. = FALSE)
  }
  args[[hit[[length(hit)]] + 1]]
}

has_flag <- function(args, name) {
  name %in% args
}

normalize_cli_path <- function(path) {
  path <- path.expand(path)
  is_absolute <- grepl("^([A-Za-z]:)?[\\/]", path) || startsWith(path, "\\\\")
  if (!is_absolute) {
    path <- file.path(getwd(), path)
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

usage <- function() {
  cat(paste(
    "Usage:",
    "  Rscript scripts/run_harness.R --project PATH [options]",
    "",
    "Options:",
    "  --project PATH             Harness project directory.",
    "  --study-id ID              Study id used when initializing a project.",
    "  --guide both|adrg|csdrg    Guides to generate. Default: both.",
    "  --mode dry_run             Drafting mode. Default: dry_run.",
    "  --qc-level basic|strict    QC level. Default: basic.",
    "  --init                     Initialize the project if needed.",
    "  --no-run                   Initialize/copy inputs only; skip generation.",
    "  --copy-example NAME        Copy bundled inputs: synthetic, anonymous, or none.",
    "  --interactive             Prompt for common harness options.",
    "  --summary PATH             Summary JSON path. Default: output/harness_summary.json.",
    "  --fail-on-qc               Exit with status 2 when any QC row fails.",
    "  --help                     Show this help.",
    "",
    "Typical flow:",
    "  Rscript scripts/run_harness.R --project studies/ABC-001 --study-id ABC-001 --init --no-run",
    "  # copy define.xml and validation CSV/XLSX under studies/ABC-001/source/",
    "  Rscript scripts/run_harness.R --project studies/ABC-001 --guide both",
    sep = "\n"
  ), "\n")
}

prompt_value <- function(label, default = NULL, choices = NULL) {
  suffix <- if (!is.null(default) && nzchar(default)) paste0(" [", default, "]") else ""
  cat(label, suffix, ": ", sep = "")
  answer <- readLines("stdin", n = 1, warn = FALSE)
  if (length(answer) == 0 || !nzchar(trimws(answer))) {
    answer <- default
  } else {
    answer <- trimws(answer)
  }
  if (!is.null(choices) && !answer %in% choices) {
    stop(label, " must be one of: ", paste(choices, collapse = ", "), call. = FALSE)
  }
  answer
}

prompt_yes_no <- function(label, default = TRUE) {
  default_text <- if (isTRUE(default)) "Y/n" else "y/N"
  answer <- prompt_value(label, default = default_text)
  if (identical(answer, default_text)) {
    return(isTRUE(default))
  }
  tolower(answer) %in% c("y", "yes", "true", "1")
}

script_file <- function() {
  cmd <- commandArgs(FALSE)
  file_arg <- grep("^--file=", cmd, value = TRUE)
  if (length(file_arg) == 0) {
    return(NA_character_)
  }
  normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = FALSE)
}

find_repo_root <- function(start) {
  if (is.na(start) || !nzchar(start)) {
    return(NA_character_)
  }
  current <- normalizePath(start, mustWork = FALSE)
  for (i in seq_len(8)) {
    if (file.exists(file.path(current, "DESCRIPTION")) && dir.exists(file.path(current, "R"))) {
      return(current)
    }
    parent <- dirname(current)
    if (identical(parent, current)) {
      break
    }
    current <- parent
  }
  NA_character_
}

repo_root <- function() {
  file <- script_file()
  if (!is.na(file)) {
    candidate <- find_repo_root(dirname(file))
    if (!is.na(candidate)) {
      return(candidate)
    }
  }
  find_repo_root(getwd())
}

load_engine <- function(root) {
  if (!is.na(root) && dir.exists(file.path(root, "R"))) {
    options(reviewerguideR.repo_root = root)
    files <- list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)
    for (file in sort(files)) {
      sys.source(file, envir = globalenv())
    }
    return(invisible("source"))
  }
  if (!requireNamespace("reviewerguideR", quietly = TRUE)) {
    stop(
      "reviewerguideR is not installed and this script is not running from a source checkout.",
      call. = FALSE
    )
  }
  suppressPackageStartupMessages(library("reviewerguideR", character.only = TRUE))
  invisible("package")
}

guide_types <- function(guide) {
  guide <- tolower(guide)
  if (identical(guide, "both")) {
    return(c("adrg", "csdrg"))
  }
  if (!guide %in% c("adrg", "csdrg")) {
    stop("--guide must be one of: both, adrg, csdrg", call. = FALSE)
  }
  guide
}

fixture_source <- function(name, root) {
  name <- tolower(name)
  if (identical(name, "none")) {
    return(NULL)
  }
  if (!name %in% c("synthetic", "anonymous")) {
    stop("--copy-example must be one of: synthetic, anonymous, none", call. = FALSE)
  }
  local <- if (!is.na(root)) {
    file.path(root, "inst", "extdata", paste0(name, "_study"), "source")
  } else {
    ""
  }
  if (nzchar(local) && dir.exists(local)) {
    return(normalizePath(local, mustWork = TRUE))
  }
  installed <- system.file("extdata", paste0(name, "_study"), "source", package = "reviewerguideR")
  if (!nzchar(installed) || !dir.exists(installed)) {
    stop("Bundled example source was not found: ", name, call. = FALSE)
  }
  installed
}

copy_fixture <- function(example, project_path, root) {
  source_root <- fixture_source(example, root)
  if (is.null(source_root)) {
    return(invisible(FALSE))
  }
  copied <- file.copy(
    list.files(source_root, full.names = TRUE, all.files = FALSE),
    file.path(project_path, "source"),
    recursive = TRUE,
    overwrite = TRUE
  )
  if (!all(copied)) {
    stop("Failed to copy one or more bundled example paths.", call. = FALSE)
  }
  invisible(TRUE)
}

write_summary <- function(summary, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(summary, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(path)
}

run_harness <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (has_flag(args, "--help") || length(args) == 0) {
    usage()
    return(invisible(0L))
  }

  root <- repo_root()
  load_engine(root)

  project_path <- arg_value(args, "--project")
  interactive_mode <- has_flag(args, "--interactive")
  if (isTRUE(interactive_mode) && (is.null(project_path) || !nzchar(project_path))) {
    project_path <- prompt_value("Project path", default = "studies/ABC-001")
  }
  if (is.null(project_path) || !nzchar(project_path)) {
    stop("--project is required.", call. = FALSE)
  }
  project_path <- normalize_cli_path(project_path)

  study_id <- arg_value(args, "--study-id", "STUDY-001")
  guide <- arg_value(args, "--guide", "both")
  copy_example <- arg_value(args, "--copy-example", "none")
  if (isTRUE(interactive_mode)) {
    study_id <- prompt_value("Study id", default = study_id)
    guide <- prompt_value("Guide", default = guide, choices = c("both", "adrg", "csdrg"))
    copy_example <- prompt_value("Copy bundled example", default = copy_example, choices = c("none", "synthetic", "anonymous"))
  }
  guides <- guide_types(guide)
  mode <- arg_value(args, "--mode", "dry_run")
  qc_level <- arg_value(args, "--qc-level", "basic")
  summary_path <- arg_value(args, "--summary", file.path(project_path, "output", "harness_summary.json"))
  summary_path <- normalize_cli_path(summary_path)
  should_init <- has_flag(args, "--init") || !file.exists(file.path(project_path, "config.yml"))
  no_run <- has_flag(args, "--no-run")
  fail_on_qc <- has_flag(args, "--fail-on-qc")
  if (isTRUE(interactive_mode)) {
    no_run <- !prompt_yes_no("Run generation now", default = !no_run)
    fail_on_qc <- prompt_yes_no("Fail on QC findings", default = fail_on_qc)
  }

  if (!mode %in% c("dry_run", "ellmer")) {
    stop("--mode must be one of: dry_run, ellmer", call. = FALSE)
  }
  if (!qc_level %in% c("basic", "strict")) {
    stop("--qc-level must be one of: basic, strict", call. = FALSE)
  }

  if (isTRUE(should_init)) {
    rg_init_project(project_path, study_id = study_id, guide_types = guides, overwrite = FALSE)
  }
  copy_fixture(copy_example, project_path, root)

  summary <- list(
    project_path = project_path,
    study_id = study_id,
    guides_requested = guides,
    initialized = should_init,
    copied_example = copy_example,
    mode = mode,
    status = if (isTRUE(no_run)) "initialized" else "running",
    outputs = list()
  )

  if (isTRUE(no_run)) {
    summary$status <- "initialized"
    write_summary(summary, summary_path)
    cat("Initialized harness project:\n")
    cat("  project: ", project_path, "\n", sep = "")
    cat("  summary: ", summary_path, "\n", sep = "")
    return(invisible(0L))
  }

  manifest <- rg_scan_sources(project_path, write = TRUE)
  extracted <- rg_extract_metadata(project_path, write = TRUE)

  outputs <- lapply(guides, function(guide_type) {
    draft <- rg_draft_guide(project_path, guide_type = guide_type, mode = mode, write = TRUE)
    qc <- rg_qc(project_path, guide_type = guide_type, level = qc_level, write = TRUE)
    qc_summary <- rg_qc_summary(project_path, guide_type = guide_type, qc = qc, write = TRUE)
    docx <- rg_render_docx(project_path, guide_type = guide_type)
    qc_summary_row <- as.list(qc_summary[1, ])
    list(
      guide_type = guide_type,
      draft_path = file.path(project_path, "work", "drafts", paste0(guide_type, "_draft.json")),
      qc_path = file.path(project_path, "work", "qc", paste0(guide_type, "_qc_report.csv")),
      qc_summary_path = file.path(project_path, "work", "qc", paste0(guide_type, "_qc_summary.csv")),
      docx_path = docx,
      sections = length(draft$sections),
      qc = qc_summary_row
    )
  })
  names(outputs) <- guides

  summary$status <- "completed"
  summary$manifest_rows <- nrow(manifest)
  summary$define_dataset_rows <- nrow(extracted$define_datasets)
  summary$validation_finding_rows <- nrow(extracted$validation_findings)
  summary$outputs <- outputs
  summary$total_qc_fail_rows <- sum(vapply(outputs, function(x) x$qc$fail_rows, numeric(1)))
  summary$total_qc_error_fail_rows <- sum(vapply(outputs, function(x) x$qc$error_fail_rows, numeric(1)))

  write_summary(summary, summary_path)

  cat("Harness run completed:\n")
  cat("  project: ", project_path, "\n", sep = "")
  cat("  manifest rows: ", summary$manifest_rows, "\n", sep = "")
  cat("  define datasets: ", summary$define_dataset_rows, "\n", sep = "")
  cat("  validation findings: ", summary$validation_finding_rows, "\n", sep = "")
  for (out in outputs) {
    cat("  ", out$guide_type, ": ", out$docx_path, " (QC status: ", out$qc$summary_status, ", fail rows: ", out$qc$fail_rows, ")\n", sep = "")
  }
  cat("  summary: ", summary_path, "\n", sep = "")

  if (isTRUE(fail_on_qc) && summary$total_qc_fail_rows > 0) {
    return(invisible(2L))
  }
  invisible(0L)
}

status <- tryCatch(
  run_harness(),
  error = function(e) {
    message("Harness run failed: ", conditionMessage(e))
    1L
  }
)

if (!identical(status, 0L)) {
  quit(status = status, save = "no")
}
