test_that("rg_collect_llm_context returns metadata-only section context", {
  proj <- tempfile("rg-llm-context-")
  rg_init_project(proj, study_id = "LLM-001")
  copy_synthetic_sources(proj)
  writeLines("dataset records stay out of LLM context", file.path(proj, "source", "analysis", "adsl.xpt"))
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  context <- rg_collect_llm_context(proj, guide_type = "adrg", section_id = "dataset_inventory")

  expect_s3_class(context, "data.frame")
  expect_true(all(c(
    "context_id", "guide_type", "section_id", "context_type",
    "source_file", "text", "evidence_id", "include_in_llm"
  ) %in% names(context)))
  expect_true(nrow(context) > 0)
  expect_true(all(context$include_in_llm))
  expect_false(any(grepl("\\.xpt$", context$source_file, ignore.case = TRUE)))
  expect_true(any(nzchar(stats::na.omit(context$evidence_id))))
})

test_that("rg_draft_section_mock returns deterministic structured output", {
  proj <- tempfile("rg-llm-mock-")
  rg_init_project(proj, study_id = "LLM-002")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  first <- rg_draft_section_mock(proj, guide_type = "adrg", section_id = "dataset_inventory")
  second <- rg_draft_section_mock(proj, guide_type = "adrg", section_id = "dataset_inventory")

  expect_equal(first, second)
  expect_equal(first$guide_type, "adrg")
  expect_equal(first$section_id, "dataset_inventory")
  expect_equal(first$llm_mode, "mock")
  expect_equal(first$provider, "mock")
  expect_type(first$draft_text, "character")
  expect_true(nzchar(first$draft_text))
  expect_true(length(first$evidence_ids) > 0)
  expect_true(length(first$source_context_ids) > 0)
  expect_true(is.numeric(first$confidence))
  expect_true(first$confidence >= 0 && first$confidence <= 1)
  expect_false(isTRUE(first$needs_human_review))
})

test_that("rg_draft_guide mode mock writes mock metadata into sections", {
  proj <- tempfile("rg-llm-guide-")
  rg_init_project(proj, study_id = "LLM-003")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  draft <- rg_draft_guide(proj, guide_type = "adrg", mode = "mock", sections = c("intro", "dataset_inventory"))

  expect_equal(draft$generated_by, "mock")
  expect_equal(length(draft$sections), 2)
  expect_true(all(vapply(draft$sections, function(section) identical(section$generated_by, "mock"), logical(1))))
  expect_true(all(vapply(draft$sections, function(section) identical(section$llm_mode, "mock"), logical(1))))
  expect_true(all(vapply(draft$sections, function(section) identical(section$provider, "mock"), logical(1))))
  expect_true(all(vapply(draft$sections, function(section) length(section$source_context_ids) > 0, logical(1))))
})
