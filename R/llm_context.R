rg_llm_context_columns <- function() {
  c(
    "context_id", "study_id", "guide_type", "section_id", "context_type",
    "source_file", "text", "evidence_id", "include_in_llm"
  )
}

rg_context_row <- function(study_id, guide_type, section_id, context_type, source_file, text, evidence_id) {
  seed <- paste(study_id, guide_type, section_id, context_type, evidence_id, text, sep = "|")
  tibble::tibble(
    context_id = paste0("CTX-", substr(digest::digest(seed, algo = "xxhash64"), 1, 12)),
    study_id = as.character(study_id %||% NA_character_),
    guide_type = as.character(guide_type),
    section_id = as.character(section_id),
    context_type = as.character(context_type),
    source_file = as.character(source_file %||% NA_character_),
    text = as.character(text %||% NA_character_),
    evidence_id = as.character(evidence_id %||% NA_character_),
    include_in_llm = TRUE
  )
}

rg_collect_llm_context <- function(project_path, guide_type = c("adrg", "csdrg"), section_id, limit = 40) {
  guide_type <- match.arg(guide_type)
  project_path <- rg_norm_path(project_path)
  study_id <- rg_project_study_id(project_path)

  if (!fs::file_exists(fs::path(project_path, "work", "extracted", "define_datasets.csv"))) {
    rg_extract_metadata(project_path, write = TRUE)
  }

  manifest <- rg_read_manifest(project_path)
  if (nrow(manifest) == 0) {
    manifest <- rg_scan_sources(project_path, write = TRUE)
  }
  disallowed <- manifest |>
    dplyr::filter(.data$source_type == "dataset" | tolower(.data$file_ext) %in% c("xpt", "sas7bdat", "parquet", "rds")) |>
    dplyr::filter(.data$include_in_llm %in% c(TRUE, "TRUE", "true", "1"))
  if (nrow(disallowed) > 0) {
    stop("Dataset-like files are marked include_in_llm=TRUE. Refusing to build LLM context.", call. = FALSE)
  }

  data <- rg_filter_for_guide(rg_load_extracted(project_path), guide_type)
  rows <- list()

  if (nrow(data$define_datasets) > 0 && grepl("intro|data_standards|dataset_inventory|unresolved", section_id)) {
    dataset_rows <- utils::head(data$define_datasets, limit)
    for (i in seq_len(nrow(dataset_rows))) {
      row <- dataset_rows[i, ]
      text <- paste(
        "Dataset", row$dataset_name,
        "label", row$dataset_label,
        "structure", row$structure,
        "purpose", row$purpose
      )
      rows[[length(rows) + 1]] <- rg_context_row(
        study_id, guide_type, section_id, "define_dataset",
        row$source_define, text, row$evidence_id
      )
    }
  }

  if (nrow(data$define_variables) > 0 && grepl("dataset_inventory|unresolved", section_id)) {
    variable_rows <- utils::head(data$define_variables, limit)
    for (i in seq_len(nrow(variable_rows))) {
      row <- variable_rows[i, ]
      text <- paste(
        "Variable", row$dataset_name, row$variable_name,
        "label", row$variable_label,
        "type", row$variable_type,
        "origin", row$origin,
        "detail", row$origin_detail
      )
      rows[[length(rows) + 1]] <- rg_context_row(
        study_id, guide_type, section_id, "define_variable",
        row$source_define, text, row$evidence_id
      )
    }
  }

  if (nrow(data$validation_findings) > 0 && grepl("conformance|unresolved", section_id)) {
    finding_rows <- utils::head(data$validation_findings, limit)
    for (i in seq_len(nrow(finding_rows))) {
      row <- finding_rows[i, ]
      text <- paste(
        "Validation", row$rule_id,
        "severity", row$severity,
        "dataset", row$dataset_name,
        "variable", row$variable_name,
        "message", row$message,
        "count", row$count
      )
      rows[[length(rows) + 1]] <- rg_context_row(
        study_id, guide_type, section_id, "validation_finding",
        row$source_file, text, row$evidence_id
      )
    }
  }

  out <- rg_bind_or_empty(rows, rg_llm_context_columns())
  out <- dplyr::filter(out, .data$include_in_llm %in% c(TRUE, "TRUE", "true", "1"))
  utils::head(out, limit)
}
