`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}

utils::globalVariables(c(".data", "rule_id", "dataset_name", "variable_name"))

rg_abs_path <- function(path) {
  fs::path_abs(path)
}

rg_norm_path <- function(path) {
  fs::path_norm(fs::path_abs(path))
}

rg_project_config_path <- function(project_path) {
  fs::path(project_path, "config.yml")
}

rg_read_config <- function(project_path) {
  config_path <- rg_project_config_path(project_path)
  if (!fs::file_exists(config_path)) {
    stop("config.yml was not found. Run rg_init_project() first.", call. = FALSE)
  }
  yaml::read_yaml(config_path)
}

rg_config_value <- function(config, path, default = NULL) {
  value <- config
  for (key in path) {
    if (is.null(value[[key]])) {
      return(default)
    }
    value <- value[[key]]
  }
  value %||% default
}

rg_project_study_id <- function(project_path) {
  config <- rg_read_config(project_path)
  rg_config_value(config, c("study", "study_id"), default = NA_character_)
}

rg_write_csv <- function(x, path) {
  fs::dir_create(fs::path_dir(path))
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

rg_read_csv_if_exists <- function(path, columns = NULL) {
  if (!fs::file_exists(path)) {
    if (is.null(columns)) {
      return(tibble::tibble())
    }
    out <- stats::setNames(rep(list(logical()), length(columns)), columns)
    return(tibble::as_tibble(out))
  }
  tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA"),
    colClasses = "character"
  ))
}

rg_empty_tbl <- function(columns) {
  tibble::as_tibble(stats::setNames(rep(list(logical()), length(columns)), columns))
}

rg_bind_or_empty <- function(rows, columns) {
  rows <- Filter(function(x) !is.null(x) && nrow(x) > 0, rows)
  if (length(rows) == 0) {
    return(rg_empty_tbl(columns))
  }
  out <- dplyr::bind_rows(rows)
  missing <- setdiff(columns, names(out))
  for (col in missing) {
    out[[col]] <- NA
  }
  dplyr::select(out, dplyr::all_of(columns))
}

rg_evidence_columns <- function() {
  c(
    "evidence_id", "study_id", "source_file", "source_type", "data_class",
    "locator", "extracted_value", "extraction_method", "confidence",
    "needs_human_review"
  )
}

rg_define_dataset_columns <- function() {
  c(
    "study_id", "data_class", "dataset_oid", "dataset_name", "dataset_label",
    "dataset_location", "structure", "purpose", "class", "repeating",
    "is_reference_data", "source_define", "evidence_id"
  )
}

rg_define_variable_columns <- function() {
  c(
    "study_id", "data_class", "dataset_oid", "dataset_name", "variable_oid",
    "variable_name", "variable_label", "variable_type", "length",
    "display_format", "mandatory", "key_sequence", "role", "origin",
    "origin_detail", "method_oid", "codelist_oid", "source_define",
    "evidence_id"
  )
}

rg_define_codelist_columns <- function() {
  c(
    "study_id", "codelist_oid", "codelist_name", "data_type",
    "coded_value", "decode", "external_dictionary", "external_version",
    "source_define", "evidence_id"
  )
}

rg_define_method_columns <- function() {
  c(
    "study_id", "method_oid", "method_name", "method_type",
    "method_text", "source_define", "evidence_id"
  )
}

rg_define_valuelevel_columns <- function() {
  c(
    "study_id", "data_class", "value_list_oid", "where_clause_oid",
    "dataset_oid", "dataset_name", "variable_oid", "variable_name",
    "mandatory", "method_oid", "where_item_oid", "where_variable_name",
    "comparator", "check_value", "soft_hard", "source_define",
    "evidence_id", "needs_human_review"
  )
}

rg_validation_columns <- function() {
  c(
    "study_id", "data_class", "source_file", "tool_name", "tool_version",
    "standard", "standard_version", "rule_id", "severity", "dataset_name",
    "variable_name", "message", "count", "sponsor_explanation", "status",
    "evidence_id"
  )
}

rg_manifest_columns <- function() {
  c(
    "doc_id", "study_id", "file_path", "file_name", "file_ext",
    "source_type", "data_class", "guide_scope", "file_hash",
    "modified_time", "include_in_llm", "include_in_rag", "status", "notes",
    "external_origin", "upstream_url", "upstream_commit", "attribution",
    "disclaimer_source"
  )
}

rg_empty_manifest <- function() {
  manifest <- tibble::tibble(
    doc_id = character(),
    study_id = character(),
    file_path = character(),
    file_name = character(),
    file_ext = character(),
    source_type = character(),
    data_class = character(),
    guide_scope = character(),
    file_hash = character(),
    modified_time = character(),
    include_in_llm = logical(),
    include_in_rag = logical(),
    status = character(),
    notes = character(),
    external_origin = character(),
    upstream_url = character(),
    upstream_commit = character(),
    attribution = character(),
    disclaimer_source = character()
  )
  dplyr::select(manifest, dplyr::all_of(rg_manifest_columns()))
}

rg_qc_summary_columns <- function() {
  c(
    "guide_type", "summary_status", "total_rows", "pass_rows", "fail_rows",
    "info_rows", "warning_rows", "error_rows", "warning_fail_rows",
    "error_fail_rows", "review_required_rows", "manifest_drift_rows",
    "missing_evidence_rows"
  )
}

rg_match_arg <- function(arg, choices) {
  arg <- arg[1]
  if (!arg %in% choices) {
    stop(sprintf("Expected one of: %s", paste(choices, collapse = ", ")), call. = FALSE)
  }
  arg
}

rg_infer_data_class <- function(path, requested = "auto") {
  requested <- requested[1]
  if (!identical(requested, "auto")) {
    return(requested)
  }
  lower <- tolower(as.character(path))
  lower <- gsub("\\\\", "/", lower)
  if (grepl("analysis|adam|adsl|adae|adtte|ad[a-z0-9_]*\\.xpt", lower)) {
    return("adam")
  }
  if (grepl("tabulation|sdtm|/dm\\.|/ae\\.|/ex\\.|/sv\\.|/vs\\.|/lb\\.", lower)) {
    return("sdtm")
  }
  "unknown"
}

rg_guide_data_class <- function(guide_type) {
  if (identical(guide_type, "adrg")) "adam" else "sdtm"
}

rg_safe_text <- function(x) {
  x <- as.character(x %||% NA_character_)
  if (length(x) == 0) NA_character_ else x[1]
}

rg_make_evidence_id <- function(prefix, source_file, locator, index = NULL) {
  seed <- paste(prefix, source_file, locator, index %||% "", sep = "|")
  paste0(prefix, "-", substr(digest::digest(seed, algo = "xxhash64"), 1, 12))
}

rg_read_manifest <- function(project_path) {
  manifest_path <- fs::path(project_path, "work", "manifest.json")
  if (!fs::file_exists(manifest_path)) {
    return(tibble::tibble())
  }
  out <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  tibble::as_tibble(out)
}

rg_markdown_to_paragraphs <- function(text) {
  text <- text %||% ""
  parts <- unlist(strsplit(text, "\n+", perl = TRUE), use.names = FALSE)
  parts[nzchar(trimws(parts))]
}
