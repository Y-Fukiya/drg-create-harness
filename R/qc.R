rg_read_draft <- function(project_path, guide_type) {
  path <- fs::path(project_path, "work", "drafts", paste0(guide_type, "_draft.json"))
  if (!fs::file_exists(path)) {
    return(NULL)
  }
  jsonlite::read_json(path, simplifyVector = FALSE)
}

rg_qc_row <- function(check_id, guide_type, severity, status, message, object_type = NA_character_, object_id = NA_character_) {
  tibble::tibble(
    check_id = check_id,
    guide_type = guide_type,
    severity = severity,
    status = status,
    message = message,
    object_type = object_type,
    object_id = object_id
  )
}

rg_qc_dataset_tokens <- function(draft_sections, dataset_names, study_id = NA_character_) {
  target_sections <- draft_sections[vapply(draft_sections, function(section) {
    grepl("data_standards|dataset_inventory", section$section_id %||% "")
  }, logical(1))]
  if (length(target_sections) == 0) {
    return(character())
  }
  text <- paste(vapply(target_sections, function(section) section$draft_markdown %||% "", character(1)), collapse = " ")
  matches <- gregexpr("\\b[A-Z][A-Z0-9_]{1,7}\\b", text, perl = TRUE)
  tokens <- unique(unlist(regmatches(text, matches), use.names = FALSE))
  tokens <- tokens[nzchar(tokens)]
  excluded <- c(
    "ADAM", "SDTM", "ADRG", "CSDRG", "TBD", "CSV", "XLSX", "DOCX", "PDF",
    "LLM", "RAG", "QC", "API", "OID", "ID", "MVP", "XML", "JSON", "URL",
    unlist(strsplit(toupper(study_id %||% ""), "[^A-Z0-9_]+"))
  )
  setdiff(tokens, c(toupper(stats::na.omit(dataset_names)), excluded))
}

rg_qc <- function(project_path, guide_type = c("adrg", "csdrg"), level = c("basic", "strict"), write = TRUE) {
  guide_type <- match.arg(guide_type)
  level <- match.arg(level)
  project_path <- rg_norm_path(project_path)
  spec <- rg_read_section_spec(guide_type)
  data <- rg_filter_for_guide(rg_load_extracted(project_path), guide_type)
  config <- rg_read_config(project_path)
  study_id <- rg_config_value(config, c("study", "study_id"), default = NA_character_)
  draft <- rg_read_draft(project_path, guide_type)
  rows <- list()

  draft_exists <- !is.null(draft)
  rows[[length(rows) + 1]] <- rg_qc_row(
    "draft_exists", guide_type,
    if (draft_exists) "info" else "error",
    if (draft_exists) "pass" else "fail",
    if (draft_exists) "Draft JSON exists." else "Draft JSON is missing.",
    "draft", paste0(guide_type, "_draft.json")
  )

  draft_sections <- if (draft_exists) draft$sections else list()
  section_ids <- vapply(draft_sections, function(x) x$section_id %||% NA_character_, character(1))
  required <- spec$section_id[isTRUE(spec$required) | spec$required]
  missing_sections <- setdiff(required, section_ids)
  rows[[length(rows) + 1]] <- rg_qc_row(
    "required_sections", guide_type,
    if (length(missing_sections) == 0) "info" else "error",
    if (length(missing_sections) == 0) "pass" else "fail",
    if (length(missing_sections) == 0) "All required sections are present." else paste("Missing required sections:", paste(missing_sections, collapse = ", ")),
    "section", paste(missing_sections, collapse = ", ")
  )

  has_datasets <- nrow(data$define_datasets) > 0
  rows[[length(rows) + 1]] <- rg_qc_row(
    "dataset_inventory", guide_type,
    if (has_datasets) "info" else "error",
    if (has_datasets) "pass" else "fail",
    if (has_datasets) "Dataset inventory was extracted." else "Dataset inventory is empty.",
    "define_datasets", NA_character_
  )

  dataset_names <- unique(stats::na.omit(data$define_datasets$dataset_name))
  unknown_draft_datasets <- if (length(draft_sections) == 0) {
    character()
  } else {
    rg_qc_dataset_tokens(draft_sections, dataset_names, study_id = study_id)
  }
  rows[[length(rows) + 1]] <- rg_qc_row(
    "draft_dataset_mentions_defined", guide_type,
    if (length(unknown_draft_datasets) == 0) "info" else "warning",
    if (length(unknown_draft_datasets) == 0) "pass" else "fail",
    if (length(unknown_draft_datasets) == 0) {
      "Dataset-like names in draft inventory sections are present in define_datasets."
    } else {
      paste("Draft inventory sections mention dataset-like names not found in define_datasets:", paste(unknown_draft_datasets, collapse = ", "))
    },
    "section", paste(unknown_draft_datasets, collapse = ", ")
  )

  validation_dataset_names <- unique(stats::na.omit(data$validation_findings$dataset_name))
  validation_dataset_names <- validation_dataset_names[nzchar(validation_dataset_names)]
  unknown_validation_datasets <- setdiff(toupper(validation_dataset_names), toupper(dataset_names))
  rows[[length(rows) + 1]] <- rg_qc_row(
    "validation_datasets_defined", guide_type,
    if (length(unknown_validation_datasets) == 0) "info" else "warning",
    if (length(unknown_validation_datasets) == 0) "pass" else "fail",
    if (length(unknown_validation_datasets) == 0) {
      "Validation finding dataset names are present in define_datasets."
    } else {
      paste("Validation findings reference dataset names not found in define_datasets:", paste(unknown_validation_datasets, collapse = ", "))
    },
    "validation_findings", paste(unknown_validation_datasets, collapse = ", ")
  )

  unsupported_define <- data$evidence_table |>
    dplyr::filter(grepl("^(ValueListDef|WhereClauseDef)\\[", .data$locator))
  rows[[length(rows) + 1]] <- rg_qc_row(
    "unsupported_define_metadata", guide_type,
    if (nrow(unsupported_define) == 0) "info" else "warning",
    if (nrow(unsupported_define) == 0) "pass" else "fail",
    if (nrow(unsupported_define) == 0) {
      "No unsupported ValueListDef or WhereClauseDef metadata was detected."
    } else {
      paste(
        "define.xml contains ValueListDef/WhereClauseDef metadata that the MVP parser detects but does not expand:",
        paste(unique(unsupported_define$locator), collapse = ", ")
      )
    },
    "define", paste(unique(unsupported_define$locator), collapse = ", ")
  )

  if (length(draft_sections) > 0) {
    for (section in draft_sections) {
      evidence_ids <- section$evidence_ids %||% character()
      has_evidence <- length(evidence_ids) > 0
      rows[[length(rows) + 1]] <- rg_qc_row(
        paste0("section_evidence_", section$section_id),
        guide_type,
        if (has_evidence) "info" else if (identical(level, "strict")) "error" else "warning",
        if (has_evidence) "pass" else "fail",
        if (has_evidence) "Section has evidence_ids." else "Section is missing evidence_ids.",
        "section", section$section_id
      )

      text <- section$draft_markdown %||% ""
      if (grepl("TBD", text, ignore.case = TRUE)) {
        rows[[length(rows) + 1]] <- rg_qc_row(
          paste0("tbd_", section$section_id), guide_type, "warning", "fail",
          "TBD text remains in draft section.", "section", section$section_id
        )
      }
      if (isTRUE(section$needs_human_review)) {
        rows[[length(rows) + 1]] <- rg_qc_row(
          paste0("needs_review_", section$section_id), guide_type, "warning", "fail",
          "Section is marked as needing human review.", "section", section$section_id
        )
      }
    }
  }

  finding_count <- nrow(data$validation_findings)
  conformance <- draft_sections[vapply(draft_sections, function(x) grepl("conformance", x$section_id %||% ""), logical(1))]
  conformance_text <- if (length(conformance) > 0) conformance[[1]]$draft_markdown %||% "" else ""
  reflected <- if (finding_count == 0) {
    length(conformance) > 0 && grepl("No validation findings|0 validation findings", conformance_text, ignore.case = TRUE)
  } else {
    length(conformance) > 0 && grepl(as.character(finding_count), conformance_text)
  }
  rows[[length(rows) + 1]] <- rg_qc_row(
    "validation_reflected", guide_type,
    if (reflected) "info" else "warning",
    if (reflected) "pass" else "fail",
    if (reflected) "Validation finding count is reflected in the draft." else "Validation findings may not be reflected in the conformance section.",
    "validation_findings", as.character(finding_count)
  )

  manifest <- rg_read_manifest(project_path)
  if (nrow(manifest) > 0) {
    changed <- manifest |>
      dplyr::rowwise() |>
      dplyr::mutate(current_hash = if (fs::file_exists(.data$file_path)) digest::digest(file = .data$file_path, algo = "sha256") else NA_character_) |>
      dplyr::ungroup() |>
      dplyr::filter(!is.na(.data$current_hash), .data$current_hash != .data$file_hash)
    rows[[length(rows) + 1]] <- rg_qc_row(
      "manifest_hashes", guide_type,
      if (nrow(changed) == 0) "info" else "warning",
      if (nrow(changed) == 0) "pass" else "fail",
      if (nrow(changed) == 0) "Manifest hashes match current files." else paste(nrow(changed), "source files changed since manifest creation."),
      "manifest", NA_character_
    )
  }

  report <- dplyr::bind_rows(rows)
  if (write) {
    rg_write_csv(report, fs::path(project_path, "work", "qc", "qc_report.csv"))
  }
  report
}
