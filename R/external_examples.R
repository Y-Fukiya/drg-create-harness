rg_cdisc_pilot_spec <- function() {
  list(
    example = "cdisc-pilot",
    upstream_url = "https://github.com/cdisc-org/sdtm-adam-pilot-project",
    attribution = paste(
      "CDISC Pilot Project metadata copied from a local optional external",
      "fixture. Generated reviewer guides remain drafts and require human review."
    ),
    disclaimer_file = "CDISC.Pilot Project Data.Website Disclaimer.v1.pdf",
    files = tibble::tibble(
      data_class = c("sdtm", "adam"),
      project_path = c(
        fs::path("source", "tabulation", "define.xml"),
        fs::path("source", "analysis", "define.xml")
      ),
      source_path = c(
        fs::path(
          "updated-pilot-submission-package", "900172", "m5", "datasets",
          "cdiscpilot01", "tabulations", "sdtm", "define.xml"
        ),
        fs::path(
          "updated-pilot-submission-package", "900172", "m5", "datasets",
          "cdiscpilot01", "analysis", "adam", "datasets", "define.xml"
        )
      )
    )
  )
}

rg_prepare_external_example <- function(project_path,
                                        example = c("cdisc-pilot"),
                                        source_path = NULL,
                                        upstream_commit = NA_character_) {
  example <- rg_match_arg(example, c("cdisc-pilot"))
  commit_missing <- missing(upstream_commit) ||
    length(upstream_commit) == 0 ||
    is.na(upstream_commit[[1]]) ||
    !nzchar(upstream_commit[[1]])
  upstream_commit <- upstream_commit[1] %||% NA_character_

  project_path <- rg_norm_path(project_path)
  source_root <- fs::path(project_path, "source")
  if (!fs::dir_exists(source_root)) {
    stop("source/ was not found. Run rg_init_project() first.", call. = FALSE)
  }

  if (is.null(source_path)) {
    source_path <- fs::path(fs::path_dir(project_path), "external", example)
  }
  source_path <- rg_norm_path(source_path)

  spec <- rg_cdisc_pilot_spec()
  disclaimer_source <- fs::path(source_path, spec$disclaimer_file)
  source_files <- fs::path(source_path, spec$files$source_path)
  expected <- c(source_files, disclaimer_source)
  missing_files <- expected[!fs::file_exists(expected)]
  if (length(missing_files) > 0) {
    stop(
      paste(
        "CDISC Pilot external fixture is missing expected files:",
        paste(paste0("- ", missing_files), collapse = "\n"),
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  if (isTRUE(commit_missing)) {
    upstream_commit <- rg_detect_git_head(source_path)
  }

  project_files <- fs::path(project_path, spec$files$project_path)
  purrr::walk(fs::path_dir(project_files), fs::dir_create)
  copied <- file.copy(source_files, project_files, overwrite = TRUE)
  if (!all(copied)) {
    failed <- project_files[!copied]
    stop(
      paste(
        "Failed to copy external metadata files:",
        paste(paste0("- ", failed), collapse = "\n"),
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  copied_files <- tibble::tibble(
    data_class = spec$files$data_class,
    source_type = "define",
    source_path = as.character(rg_norm_path(source_files)),
    project_path = as.character(rg_norm_path(project_files)),
    file_name = fs::path_file(project_files),
    file_hash = vapply(
      project_files,
      function(path) digest::digest(file = path, algo = "sha256"),
      character(1)
    )
  )

  sidecar <- list(
    example = spec$example,
    source_path = as.character(source_path),
    upstream_url = spec$upstream_url,
    upstream_commit = upstream_commit,
    attribution = spec$attribution,
    disclaimer_source = as.character(rg_norm_path(disclaimer_source)),
    copied_files = copied_files
  )

  out <- fs::path(project_path, "work", "external_sources.json")
  fs::dir_create(fs::path_dir(out))
  jsonlite::write_json(sidecar, out, dataframe = "rows", pretty = TRUE, auto_unbox = TRUE, na = "null")
  invisible(sidecar)
}

rg_detect_git_head <- function(path) {
  if (!fs::file_exists(fs::path(path, ".git"))) {
    return(NA_character_)
  }

  out <- tryCatch(
    suppressWarnings(system2("git", c("-C", path, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)),
    error = function(e) character()
  )
  status <- attr(out, "status") %||% 0L
  if (!identical(as.integer(status), 0L) || length(out) == 0 || !nzchar(out[[1]])) {
    return(NA_character_)
  }
  out[[1]]
}

rg_read_external_sources <- function(project_path) {
  sidecar_path <- fs::path(project_path, "work", "external_sources.json")
  if (!fs::file_exists(sidecar_path)) {
    return(NULL)
  }
  tryCatch(
    jsonlite::read_json(sidecar_path, simplifyVector = TRUE),
    error = function(e) NULL
  )
}

rg_external_manifest_annotations <- function(project_path) {
  sidecar <- rg_read_external_sources(project_path)
  columns <- c(
    "project_path", "file_hash", "external_origin", "upstream_url",
    "upstream_commit", "attribution", "disclaimer_source"
  )
  if (is.null(sidecar) || is.null(sidecar$copied_files)) {
    return(rg_empty_tbl(columns))
  }

  copied <- tibble::as_tibble(sidecar$copied_files)
  if (nrow(copied) == 0 || !all(c("project_path", "file_hash") %in% names(copied))) {
    return(rg_empty_tbl(columns))
  }

  annotations <- tibble::tibble(
    project_path = as.character(rg_norm_path(copied$project_path)),
    file_hash = as.character(copied$file_hash),
    external_origin = rg_safe_text(sidecar$example),
    upstream_url = rg_safe_text(sidecar$upstream_url),
    upstream_commit = rg_safe_text(sidecar$upstream_commit),
    attribution = rg_safe_text(sidecar$attribution),
    disclaimer_source = rg_safe_text(sidecar$disclaimer_source)
  )
  dplyr::select(annotations, dplyr::all_of(columns))
}

rg_external_annotation_for_path <- function(path, annotations) {
  columns <- c(
    "external_origin", "upstream_url", "upstream_commit", "attribution",
    "disclaimer_source"
  )
  empty <- stats::setNames(rep(list(NA_character_), length(columns)), columns)
  if (nrow(annotations) == 0) {
    return(empty)
  }

  file_hash <- digest::digest(file = path, algo = "sha256")
  match <- annotations[
    annotations$project_path == as.character(rg_norm_path(path)) &
      annotations$file_hash == file_hash,
    columns,
    drop = FALSE
  ]
  if (nrow(match) == 0) {
    return(empty)
  }
  as.list(match[1, columns, drop = FALSE])
}
