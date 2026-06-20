test_that("rg_collect_llm_context returns metadata-only section context", {
  proj <- tempfile("rg-llm-context-")
  rg_init_project(proj, study_id = "LLM-001")
  copy_synthetic_sources(proj)
  writeLines("dataset records stay out of LLM context", file.path(proj, "source", "analysis", "adsl.xpt"))
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  context <- rg_collect_llm_context(proj, guide_type = "adrg", section_id = "adam_dataset_inventory")

  expect_s3_class(context, "data.frame")
  expect_true(all(c(
    "context_id", "guide_type", "section_id", "context_type",
    "source_file", "text", "evidence_id", "include_in_llm"
  ) %in% names(context)))
  expect_true(nrow(context) > 0)
  expect_true(all(context$include_in_llm))
  expect_false(any(grepl("\\.xpt$", context$source_file, ignore.case = TRUE)))
  expect_false(any(grepl("dataset records stay out of LLM context", context$text, fixed = TRUE)))
  expect_true(any(nzchar(stats::na.omit(context$evidence_id))))

  expect_error(
    rg_collect_llm_context(proj, guide_type = "adrg", section_id = "adam_dataset_inventory", limit = 0),
    "limit must be a positive finite integer",
    fixed = TRUE
  )
})

test_that("rg_collect_llm_context fails closed without manifest or extracted metadata", {
  missing_manifest <- tempfile("rg-llm-no-manifest-")
  rg_init_project(missing_manifest, study_id = "LLM-001A")
  copy_synthetic_sources(missing_manifest)

  expect_error(
    rg_collect_llm_context(missing_manifest, guide_type = "adrg", section_id = "adam_dataset_inventory"),
    "Manifest is required",
    fixed = TRUE
  )

  missing_extracted <- tempfile("rg-llm-no-extracted-")
  rg_init_project(missing_extracted, study_id = "LLM-001B")
  copy_synthetic_sources(missing_extracted)
  rg_scan_sources(missing_extracted)

  expect_error(
    rg_collect_llm_context(missing_extracted, guide_type = "adrg", section_id = "adam_dataset_inventory"),
    "Extracted metadata is required",
    fixed = TRUE
  )
})

test_that("rg_collect_llm_context refuses dataset-like files marked for LLM use", {
  proj <- tempfile("rg-llm-unsafe-manifest-")
  rg_init_project(proj, study_id = "LLM-001C")
  copy_synthetic_sources(proj)
  dir.create(file.path(proj, "source", "analysis"), recursive = TRUE, showWarnings = FALSE)
  writeLines("dataset records stay out of LLM context", file.path(proj, "source", "analysis", "adsl.xpt"))
  rg_scan_sources(proj)

  manifest_path <- file.path(proj, "work", "manifest.json")
  manifest <- rg_read_manifest(proj)
  manifest$include_in_llm[manifest$file_name == "adsl.xpt"] <- TRUE
  jsonlite::write_json(manifest, manifest_path, dataframe = "rows", pretty = TRUE, auto_unbox = TRUE, na = "null")
  rg_extract_metadata(proj)

  expect_error(
    rg_collect_llm_context(proj, guide_type = "adrg", section_id = "adam_dataset_inventory"),
    "Dataset-like files are marked include_in_llm=TRUE",
    fixed = TRUE
  )
})

test_that("rg_draft_section_mock returns deterministic structured output", {
  proj <- tempfile("rg-llm-mock-")
  rg_init_project(proj, study_id = "LLM-002")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  first <- rg_draft_section_mock(proj, guide_type = "adrg", section_id = "adam_dataset_inventory")
  second <- rg_draft_section_mock(proj, guide_type = "adrg", section_id = "adam_dataset_inventory")

  expect_equal(first, second)
  expect_equal(first$guide_type, "adrg")
  expect_equal(first$section_id, "adam_dataset_inventory")
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

test_that("rg_draft_section_mock binds dataset claims to collected context", {
  proj <- tempfile("rg-llm-context-bound-")
  rg_init_project(proj, study_id = "LLM-002B")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  datasets_path <- file.path(proj, "work", "extracted", "define_datasets.csv")
  datasets <- utils::read.csv(datasets_path, stringsAsFactors = FALSE, check.names = FALSE)
  datasets <- datasets[rep(1, 45), , drop = FALSE]
  datasets$dataset_name <- sprintf("AD%03d", seq_len(nrow(datasets)))
  datasets$dataset_label <- sprintf("Analysis Dataset %03d", seq_len(nrow(datasets)))
  datasets$evidence_id <- paste0("DEFDS-", sprintf("%03d", seq_len(nrow(datasets))))
  utils::write.csv(datasets, datasets_path, row.names = FALSE, na = "")

  draft <- rg_draft_section_mock(proj, guide_type = "adrg", section_id = "adam_dataset_inventory")

  expect_match(draft$draft_text, "includes 40 dataset context rows", fixed = TRUE)
  expect_false(grepl("45 datasets", draft$draft_text, fixed = TRUE))
})

test_that("rg_draft_guide mode mock writes mock metadata into sections", {
  proj <- tempfile("rg-llm-guide-")
  rg_init_project(proj, study_id = "LLM-003")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  draft <- rg_draft_guide(proj, guide_type = "adrg", mode = "mock", sections = c("intro", "adam_dataset_inventory"))

  expect_equal(draft$generated_by, "mock")
  expect_equal(length(draft$sections), 2)
  section_ids <- vapply(draft$sections, `[[`, character(1), "section_id")
  expect_setequal(section_ids, c("intro", "adam_dataset_inventory"))
  expect_true(all(vapply(draft$sections, function(section) identical(section$generated_by, "mock"), logical(1))))
  expect_true(all(vapply(draft$sections, function(section) identical(section$llm_mode, "mock"), logical(1))))
  expect_true(all(vapply(draft$sections, function(section) identical(section$provider, "mock"), logical(1))))
  expect_true(all(vapply(draft$sections, function(section) length(section$source_context_ids) > 0, logical(1))))
})

test_that("rg_draft_guide mode mock fails closed without extracted metadata", {
  proj <- tempfile("rg-llm-guide-no-extracted-")
  rg_init_project(proj, study_id = "LLM-004")
  copy_synthetic_sources(proj)

  expect_error(
    rg_draft_guide(proj, guide_type = "adrg", mode = "mock"),
    "Extracted metadata is required before mock LLM drafting",
    fixed = TRUE
  )
})

test_that("rg_draft_guide preserves dry-run auto-extract and ellmer guard behavior", {
  dry_run_proj <- tempfile("rg-llm-dry-run-auto-")
  rg_init_project(dry_run_proj, study_id = "LLM-005")
  copy_synthetic_sources(dry_run_proj)

  expect_false(file.exists(file.path(dry_run_proj, "work", "extracted", "define_datasets.csv")))
  draft <- rg_draft_guide(dry_run_proj, guide_type = "adrg", mode = "dry_run", sections = "intro", write = FALSE)
  expect_equal(draft$generated_by, "dry_run")
  expect_true(file.exists(file.path(dry_run_proj, "work", "extracted", "define_datasets.csv")))

  ellmer_proj <- tempfile("rg-llm-ellmer-guard-")
  rg_init_project(ellmer_proj, study_id = "LLM-006")

  expect_error(
    rg_draft_guide(ellmer_proj, guide_type = "adrg", mode = "ellmer"),
    "LLM drafting is disabled",
    fixed = TRUE
  )
})
