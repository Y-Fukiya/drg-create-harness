rg_draft_section_ellmer <- function(project_path, guide_type, section_id, chat = NULL) {
  project_path <- rg_norm_path(project_path)
  config <- rg_read_config(project_path)
  if (!isTRUE(rg_config_value(config, c("llm", "enabled"), default = FALSE))) {
    stop("LLM drafting is disabled in config.yml (llm.enabled is false).", call. = FALSE)
  }
  if (!isTRUE(rg_config_value(config, c("llm", "external_llm_allowed"), default = FALSE))) {
    stop("External LLM providers are disabled by config.yml.", call. = FALSE)
  }
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("ellmer is not installed. Install ellmer to use mode = 'ellmer'.", call. = FALSE)
  }
  stop("ellmer drafting is an integration point in the MVP and is not implemented yet.", call. = FALSE)
}

rg_mock_context_excerpt <- function(context, context_type, empty_text) {
  rows <- context[context$context_type == context_type, , drop = FALSE]
  texts <- unique(stats::na.omit(rows$text))
  texts <- texts[nzchar(texts)]
  if (length(texts) == 0) {
    return(empty_text)
  }
  paste(utils::head(texts, 3), collapse = "; ")
}

rg_draft_section_mock <- function(project_path, guide_type = c("adrg", "csdrg"), section_id) {
  guide_type <- match.arg(guide_type)
  project_path <- rg_norm_path(project_path)
  study_id <- rg_project_study_id(project_path)
  context <- rg_collect_llm_context(project_path, guide_type = guide_type, section_id = section_id)
  data <- rg_filter_for_guide(rg_load_extracted(project_path), guide_type)
  evidence_ids <- unique(stats::na.omit(context$evidence_id))
  evidence_ids <- evidence_ids[nzchar(evidence_ids)]
  context_ids <- unique(stats::na.omit(context$context_id))

  dataset_context <- context[context$context_type == "define_dataset", , drop = FALSE]
  variable_context <- context[context$context_type == "define_variable", , drop = FALSE]
  finding_context <- context[context$context_type == "validation_finding", , drop = FALSE]
  standard_name <- if (identical(guide_type, "adrg")) "ADaM" else "SDTM"
  dataset_summary <- rg_mock_context_excerpt(dataset_context, "define_dataset", "no dataset context rows were attached")

  draft_text <- if (identical(section_id, "intro")) {
    glue::glue(
      "This mock LLM draft summarizes {nrow(context)} metadata-only context rows for study {study_id}. ",
      "It covers the {standard_name} reviewer guide inputs represented by the attached context and must be reviewed before use."
    )
  } else if (grepl("dataset_inventory$", section_id)) {
    glue::glue(
      "The {standard_name} metadata-only context includes {nrow(dataset_context)} dataset context rows ",
      "and {nrow(variable_context)} variable context rows. Context excerpts: {dataset_summary}."
    )
  } else if (grepl("conformance_findings$", section_id)) {
    glue::glue(
      "{nrow(finding_context)} validation finding context rows were attached for the {standard_name} package."
    )
  } else if (identical(section_id, "unresolved_items")) {
    glue::glue(
      "The mock LLM draft reviewed {nrow(context)} metadata-only context rows for unresolved-item signals. ",
      "Human review remains required."
    )
  } else {
    glue::glue(
      "The mock LLM draft prepared section {section_id} from {nrow(context)} metadata-only context rows for the {standard_name} package."
    )
  }

  needs_review <- length(evidence_ids) == 0 ||
    rg_has_unresolved_metadata(data) ||
    nrow(context) == 0

  list(
    guide_type = guide_type,
    section_id = section_id,
    draft_text = as.character(draft_text),
    evidence_ids = evidence_ids,
    source_context_ids = context_ids,
    confidence = if (isTRUE(needs_review)) 0.6 else 0.85,
    needs_human_review = needs_review,
    warnings = if (isTRUE(needs_review)) "Review required by structured metadata signals or missing context." else character(),
    llm_mode = "mock",
    provider = "mock"
  )
}
