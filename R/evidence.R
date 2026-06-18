rg_new_evidence <- function(evidence_id, study_id, source_file, source_type, data_class,
                            locator, extracted_value, extraction_method = "parser",
                            confidence = 0.85, needs_human_review = FALSE) {
  tibble::tibble(
    evidence_id = as.character(evidence_id),
    study_id = as.character(study_id %||% NA_character_),
    source_file = as.character(source_file %||% NA_character_),
    source_type = as.character(source_type %||% NA_character_),
    data_class = as.character(data_class %||% NA_character_),
    locator = as.character(locator %||% NA_character_),
    extracted_value = as.character(extracted_value %||% NA_character_),
    extraction_method = as.character(extraction_method),
    confidence = as.numeric(confidence),
    needs_human_review = as.logical(needs_human_review)
  )
}

rg_validation_evidence <- function(validation_findings) {
  if (nrow(validation_findings) == 0) {
    return(rg_empty_tbl(rg_evidence_columns()))
  }
  dplyr::mutate(
    validation_findings,
    source_type = "validation",
    locator = paste(rule_id %||% NA_character_, dataset_name %||% NA_character_, variable_name %||% NA_character_, sep = " / "),
    extracted_value = message,
    extraction_method = "validation_import",
    confidence = 0.9,
    needs_human_review = FALSE
  ) |>
    dplyr::select(dplyr::all_of(rg_evidence_columns()))
}
