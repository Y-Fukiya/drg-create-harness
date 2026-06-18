rg_default_validation_column_mapping <- function() {
  list(
    tool_name = c("tool_name", "tool", "validator", "source"),
    tool_version = c("tool_version", "validator_version", "version"),
    standard = c("standard", "standard_name", "model"),
    standard_version = c("standard_version", "standard version", "model_version"),
    rule_id = c("rule_id", "rule id", "rule", "check_id", "check id", "id"),
    severity = c("severity", "severity level", "level", "type"),
    dataset_name = c("dataset_name", "dataset", "domain", "domain_name", "table"),
    variable_name = c("variable_name", "variable", "var", "column", "item"),
    message = c("message", "description", "finding", "issue", "details", "error_message", "error"),
    count = c("count", "records", "record_count", "occurrences", "n"),
    sponsor_explanation = c("sponsor_explanation", "explanation", "sponsor comment", "sponsor_comment", "comment", "response"),
    status = c("status", "outcome", "disposition", "state")
  )
}

rg_default_config <- function(study_id, project_id, guide_types = c("adrg", "csdrg")) {
  guide_types <- intersect(guide_types, c("adrg", "csdrg"))
  cfg <- list(
    project = list(
      project_id = project_id,
      output_language = "en"
    ),
    study = list(
      study_id = study_id,
      study_title = "TBD",
      compound = "TBD",
      indication = "TBD",
      phase = "TBD",
      sponsor = "TBD"
    ),
    guides = list(
      adrg = list(
        enabled = "adrg" %in% guide_types,
        template = "templates/adrg_template.docx",
        output = "output/adrg_draft.docx"
      ),
      csdrg = list(
        enabled = "csdrg" %in% guide_types,
        template = "templates/csdrg_template.docx",
        output = "output/csdrg_draft.docx"
      )
    ),
    validation = list(
      column_mapping = rg_default_validation_column_mapping()
    ),
    llm = list(
      enabled = FALSE,
      provider = "mock",
      chat_model = NULL,
      external_llm_allowed = FALSE
    ),
    rag = list(
      enabled = FALSE,
      backend = "none",
      retrieve_top_k = 8
    ),
    privacy = list(
      allow_subject_level_data_to_llm = FALSE,
      allow_dataset_records_to_llm = FALSE,
      metadata_only_llm_context = TRUE
    ),
    qc = list(
      require_evidence_for_each_section = TRUE,
      fail_on_missing_required_sections = TRUE,
      fail_on_missing_dataset_inventory = TRUE,
      fail_on_tbd = FALSE
    )
  )
  cfg
}

rg_write_config <- function(config, path, overwrite = FALSE) {
  if (fs::file_exists(path) && !overwrite) {
    stop(sprintf("%s already exists. Use overwrite = TRUE to replace it.", path), call. = FALSE)
  }
  fs::dir_create(fs::path_dir(path))
  yaml::write_yaml(config, path)
  invisible(path)
}
