test_that("rg_qc detects missing sections, TBD text, and missing evidence", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)
  draft <- rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")

  draft$sections <- draft$sections[1]
  draft$sections[[1]]$draft_markdown <- "TBD: content requires review."
  draft$sections[[1]]$evidence_ids <- character()
  jsonlite::write_json(draft, file.path(proj, "work", "drafts", "adrg_draft.json"), pretty = TRUE, auto_unbox = TRUE)

  report <- rg_qc(proj, guide_type = "adrg")

  expect_true(any(report$check_id == "required_sections" & report$status == "fail"))
  expect_true(any(grepl("^tbd_", report$check_id) & report$status == "fail"))
  expect_true(any(grepl("^section_evidence_", report$check_id) & report$status == "fail"))
})

test_that("rg_qc warns when unsupported define.xml metadata is detected", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)
  rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")

  report <- rg_qc(proj, guide_type = "adrg")

  unsupported <- report[report$check_id == "unsupported_define_metadata", ]
  expect_equal(unsupported$severity, "warning")
  expect_equal(unsupported$status, "fail")
  expect_match(unsupported$message, "ValueListDef/WhereClauseDef", fixed = TRUE)
})

test_that("rg_qc checks draft and validation dataset names against define_datasets", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)
  draft <- rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")

  inventory_index <- which(vapply(draft$sections, function(x) identical(x$section_id, "adam_dataset_inventory"), logical(1)))
  draft$sections[[inventory_index]]$draft_markdown <- paste(draft$sections[[inventory_index]]$draft_markdown, "ADZZ")
  jsonlite::write_json(draft, file.path(proj, "work", "drafts", "adrg_draft.json"), pretty = TRUE, auto_unbox = TRUE)

  validation_path <- file.path(proj, "work", "extracted", "validation_findings.csv")
  validation <- utils::read.csv(validation_path, stringsAsFactors = FALSE, check.names = FALSE)
  validation <- rbind(validation, validation[1, , drop = FALSE])
  validation$dataset_name[nrow(validation)] <- "ADXX"
  validation$evidence_id[nrow(validation)] <- "VAL-UNKNOWN"
  utils::write.csv(validation, validation_path, row.names = FALSE, na = "")

  report <- rg_qc(proj, guide_type = "adrg")

  expect_true(any(report$check_id == "draft_dataset_mentions_defined" & report$status == "fail"))
  expect_true(any(report$check_id == "validation_datasets_defined" & report$status == "fail"))
})

test_that("rg_qc requires zero validation findings to be explicit in the conformance section", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  validation_path <- file.path(proj, "work", "extracted", "validation_findings.csv")
  validation <- utils::read.csv(validation_path, stringsAsFactors = FALSE, check.names = FALSE)
  utils::write.csv(validation[0, , drop = FALSE], validation_path, row.names = FALSE, na = "")

  draft <- rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")
  report <- rg_qc(proj, guide_type = "adrg")
  expect_true(any(report$check_id == "validation_reflected" & report$status == "pass"))

  conformance_index <- which(vapply(draft$sections, function(x) grepl("conformance", x$section_id), logical(1)))
  draft$sections[[conformance_index]]$draft_markdown <- "Validation status is pending review."
  jsonlite::write_json(draft, file.path(proj, "work", "drafts", "adrg_draft.json"), pretty = TRUE, auto_unbox = TRUE)

  report_missing_zero <- rg_qc(proj, guide_type = "adrg")
  expect_true(any(report_missing_zero$check_id == "validation_reflected" & report_missing_zero$status == "fail"))
})
