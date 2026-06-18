test_that("rg_draft_guide dry-run works without LLM and writes JSON with evidence_ids", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  draft <- rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")

  expect_true(file.exists(file.path(proj, "work", "drafts", "adrg_draft.json")))
  expect_equal(draft$guide_type, "adrg")
  expect_true(length(draft$sections) > 0)
  expect_true(all(vapply(draft$sections, function(x) length(x$evidence_ids) > 0, logical(1))))
  unresolved <- draft$sections[[which(vapply(draft$sections, function(x) identical(x$section_id, "unresolved_items"), logical(1)))]]
  expect_match(unresolved$draft_markdown, "ValueListDef/WhereClauseDef", fixed = TRUE)
  expect_true(any(grepl("^DEFUNS-", unresolved$evidence_ids)))
  expect_true(all(grepl("^DEFUNS-", unresolved$evidence_ids)))
})

test_that("rg_draft_guide auto-extracts only when extracted metadata is missing", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)

  expect_false(file.exists(file.path(proj, "work", "extracted", "define_datasets.csv")))

  draft <- rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")

  expect_true(file.exists(file.path(proj, "work", "extracted", "define_datasets.csv")))
  expect_true(file.exists(file.path(proj, "work", "manifest.json")))
  expect_equal(draft$guide_type, "adrg")

  validation_path <- file.path(proj, "work", "extracted", "validation_findings.csv")
  validation <- utils::read.csv(validation_path, stringsAsFactors = FALSE, check.names = FALSE)
  utils::write.csv(validation[0, , drop = FALSE], validation_path, row.names = FALSE, na = "")

  draft_from_existing <- rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")
  conformance <- draft_from_existing$sections[[which(vapply(
    draft_from_existing$sections,
    function(x) grepl("conformance", x$section_id),
    logical(1)
  ))]]

  expect_match(conformance$draft_markdown, "No validation findings were imported", fixed = TRUE)
})

test_that("rg_draft_guide supports cSDRG dry-run sections", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  draft <- rg_draft_guide(proj, guide_type = "csdrg", mode = "dry_run")

  expect_equal(draft$guide_type, "csdrg")
  expect_true(file.exists(file.path(proj, "work", "drafts", "csdrg_draft.json")))
  section_ids <- vapply(draft$sections, function(x) x$section_id, character(1))
  expect_true("sdtm_dataset_inventory" %in% section_ids)
  expect_true(all(vapply(draft$sections, function(x) length(x$evidence_ids) > 0, logical(1))))
})
