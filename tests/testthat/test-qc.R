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
