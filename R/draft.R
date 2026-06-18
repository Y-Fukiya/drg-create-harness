rg_load_extracted <- function(project_path) {
  list(
    define_datasets = rg_read_csv_if_exists(fs::path(project_path, "work", "extracted", "define_datasets.csv"), rg_define_dataset_columns()),
    define_variables = rg_read_csv_if_exists(fs::path(project_path, "work", "extracted", "define_variables.csv"), rg_define_variable_columns()),
    define_codelists = rg_read_csv_if_exists(fs::path(project_path, "work", "extracted", "define_codelists.csv"), rg_define_codelist_columns()),
    define_methods = rg_read_csv_if_exists(fs::path(project_path, "work", "extracted", "define_methods.csv"), rg_define_method_columns()),
    define_valuelevel = rg_read_csv_if_exists(fs::path(project_path, "work", "extracted", "define_valuelevel.csv"), rg_define_valuelevel_columns()),
    validation_findings = rg_read_csv_if_exists(fs::path(project_path, "work", "extracted", "validation_findings.csv"), rg_validation_columns()),
    evidence_table = rg_read_csv_if_exists(fs::path(project_path, "work", "evidence", "evidence_table.csv"), rg_evidence_columns())
  )
}

rg_filter_for_guide <- function(data, guide_type) {
  target <- rg_guide_data_class(guide_type)
  lapply(data, function(x) {
    if ("data_class" %in% names(x)) {
      dplyr::filter(x, .data$data_class %in% c(target, "unknown", NA_character_))
    } else {
      x
    }
  })
}

rg_section_evidence <- function(..., limit = 100) {
  ids <- unique(stats::na.omit(unlist(list(...), use.names = FALSE)))
  utils::head(ids[nzchar(ids)], limit)
}

rg_unsupported_define_evidence <- function(data) {
  data$evidence_table |>
    dplyr::filter(
      grepl("^(ValueListDef|WhereClauseDef)\\[", .data$locator),
      .data$needs_human_review %in% c(TRUE, "TRUE", "true", "1")
    )
}

rg_unresolved_evidence_ids <- function(data) {
  datasets <- data$define_datasets
  tbd_dataset_ids <- character()
  if (nrow(datasets) > 0) {
    tbd_dataset_ids <- datasets |>
      dplyr::filter(grepl("TBD", paste(.data$dataset_label, .data$structure), ignore.case = TRUE)) |>
      dplyr::pull("evidence_id")
  }
  unsupported_ids <- rg_unsupported_define_evidence(data) |>
    dplyr::pull("evidence_id")
  unresolved_ids <- rg_section_evidence(tbd_dataset_ids, unsupported_ids)
  if (length(unresolved_ids) > 0) {
    return(unresolved_ids)
  }
  rg_section_evidence(data$define_datasets$evidence_id, data$validation_findings$evidence_id, limit = 25)
}

rg_draft_text_for_section <- function(section_id, title, guide_type, study_id, data) {
  data_name <- if (identical(guide_type, "adrg")) "analysis" else "tabulation"
  standard_name <- if (identical(guide_type, "adrg")) "ADaM" else "SDTM"
  datasets <- data$define_datasets
  variables <- data$define_variables
  findings <- data$validation_findings
  valuelevel <- data$define_valuelevel
  unsupported_define <- rg_unsupported_define_evidence(data)
  dataset_names <- sort(unique(stats::na.omit(datasets$dataset_name)))
  finding_count <- nrow(findings)
  dataset_count <- length(dataset_names)
  variable_count <- nrow(variables)

  if (identical(section_id, "intro")) {
    return(glue::glue(
      "This reviewer's guide summarizes the submitted {data_name} data for study {study_id}. ",
      "The draft was generated in dry-run mode from structured metadata and requires human review before use."
    ))
  }
  if (grepl("data_standards$", section_id)) {
    dataset_sentence <- if (dataset_count > 0) {
      glue::glue("The {standard_name} package includes {dataset_count} datasets described in define.xml.")
    } else {
      glue::glue("TBD: No {standard_name} dataset inventory was extracted from define.xml.")
    }
    return(dataset_sentence)
  }
  if (grepl("dataset_inventory$", section_id)) {
    if (dataset_count == 0) {
      return(glue::glue("TBD: No {standard_name} datasets were available for the inventory table."))
    }
    preview <- paste(utils::head(dataset_names, 12), collapse = ", ")
    return(glue::glue(
      "The submitted {standard_name} dataset inventory contains {dataset_count} datasets and {variable_count} variables. ",
      "Datasets identified from define.xml include {preview}. ",
      "Value-level metadata rows extracted from define.xml: {nrow(valuelevel)}."
    ))
  }
  if (grepl("conformance_findings$", section_id)) {
    if (finding_count == 0) {
      return("No validation findings were imported for this guide. Confirm that this accurately reflects the validation package.")
    }
    severity_summary <- findings |>
      dplyr::mutate(severity = dplyr::if_else(is.na(.data$severity) | !nzchar(.data$severity), "Unspecified", .data$severity)) |>
      tidyr::replace_na(list(severity = "Unspecified")) |>
      dplyr::count(.data$severity, name = "n") |>
      dplyr::mutate(text = paste0(.data$severity, ": ", .data$n)) |>
      dplyr::pull("text") |>
      paste(collapse = "; ")
    return(glue::glue(
      "{finding_count} validation findings were imported for the {standard_name} package. ",
      "Severity summary: {severity_summary}."
    ))
  }
  if (identical(section_id, "unresolved_items")) {
    unresolved <- character()
    if (dataset_count == 0) unresolved <- c(unresolved, "dataset inventory is missing")
    if (any(grepl("TBD", c(datasets$dataset_label, datasets$structure), ignore.case = TRUE), na.rm = TRUE)) {
      unresolved <- c(unresolved, "TBD values remain in extracted metadata")
    }
    if (nrow(unsupported_define) > 0) {
      unresolved <- c(
        unresolved,
        paste(
          "define.xml contains unsupported ValueListDef/WhereClauseDef metadata requiring human review:",
          paste(unique(unsupported_define$locator), collapse = ", ")
        )
      )
    }
    if (length(unresolved) == 0) {
      return("No unresolved metadata gaps were identified by the dry-run generator. Human review is still required.")
    }
    return(paste("Human review is required for:", paste(unresolved, collapse = "; "), "."))
  }
  glue::glue("TBD: Dry-run text for {title} requires human review.")
}

rg_draft_guide <- function(project_path, guide_type = c("adrg", "csdrg"), mode = c("dry_run", "ellmer"), sections = NULL, write = TRUE) {
  guide_type <- match.arg(guide_type)
  mode <- match.arg(mode)
  project_path <- rg_norm_path(project_path)
  study_id <- rg_project_study_id(project_path)

  if (identical(mode, "ellmer")) {
    return(rg_draft_section_ellmer(project_path, guide_type = guide_type, section_id = sections[[1]] %||% "intro"))
  }

  if (!fs::file_exists(fs::path(project_path, "work", "extracted", "define_datasets.csv"))) {
    rg_extract_metadata(project_path, write = TRUE)
  }

  spec <- rg_read_section_spec(guide_type)
  if (!is.null(sections)) {
    spec <- dplyr::filter(spec, .data$section_id %in% sections)
  }
  data <- rg_filter_for_guide(rg_load_extracted(project_path), guide_type)

  draft_sections <- lapply(seq_len(nrow(spec)), function(i) {
    section_id <- spec$section_id[[i]]
    text <- as.character(rg_draft_text_for_section(section_id, spec$title[[i]], guide_type, study_id, data))
    evidence_ids <- switch(
      section_id,
      intro = rg_section_evidence(data$define_datasets$evidence_id, data$validation_findings$evidence_id, limit = 25),
      unresolved_items = rg_unresolved_evidence_ids(data),
      rg_section_evidence(
        if (grepl("conformance", section_id)) data$validation_findings$evidence_id else NULL,
        if (grepl("dataset|standards", section_id)) data$define_datasets$evidence_id else NULL,
        if (grepl("dataset", section_id)) data$define_variables$evidence_id else NULL
      )
    )
    list(
      guide_type = guide_type,
      study_id = study_id,
      section_id = section_id,
      section_title = spec$title[[i]],
      draft_markdown = text,
      evidence_ids = evidence_ids,
      status = if (grepl("TBD", text, ignore.case = TRUE) || length(evidence_ids) == 0) "needs_review" else "draft",
      generated_by = "dry_run",
      generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      needs_human_review = grepl("TBD|human review|required", text, ignore.case = TRUE) || length(evidence_ids) == 0
    )
  })

  draft <- list(
    guide_type = guide_type,
    study_id = study_id,
    generated_by = "dry_run",
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    sections = draft_sections
  )

  if (write) {
    out <- fs::path(project_path, "work", "drafts", paste0(guide_type, "_draft.json"))
    fs::dir_create(fs::path_dir(out))
    jsonlite::write_json(draft, out, pretty = TRUE, auto_unbox = TRUE, null = "null")
  }
  draft
}
