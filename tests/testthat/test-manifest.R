test_that("rg_scan_sources creates manifest and excludes XPT files from LLM/RAG", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  writeLines("", file.path(proj, "source", "analysis", "adsl.xpt"))

  manifest <- rg_scan_sources(proj)

  expect_true(file.exists(file.path(proj, "work", "manifest.json")))
  expect_true("define" %in% manifest$source_type)
  expect_true("validation" %in% manifest$source_type)
  xpt <- manifest[manifest$file_name == "adsl.xpt", ]
  expect_equal(xpt$source_type, "dataset")
  expect_false(xpt$include_in_llm)
  expect_false(xpt$include_in_rag)
})

test_that("rg_extract_metadata does not auto-rescan an existing manifest", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)

  utils::write.csv(
    data.frame(
      `Rule ID` = "NEW001",
      Severity = "Warning",
      Dataset = "ADSL",
      Variable = "SAFFL",
      Message = "Added after manifest creation",
      Count = 1,
      check.names = FALSE
    ),
    file.path(proj, "source", "analysis", "validation", "new_validation.csv"),
    row.names = FALSE
  )

  extracted <- rg_extract_metadata(proj)

  expect_false("NEW001" %in% extracted$validation_findings$rule_id)
})

test_that("rg_extract_metadata auto-scans only when manifest is missing", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)

  expect_false(file.exists(file.path(proj, "work", "manifest.json")))

  extracted <- rg_extract_metadata(proj)

  expect_true(file.exists(file.path(proj, "work", "manifest.json")))
  expect_true(nrow(extracted$define_datasets) > 0)
  expect_true(nrow(extracted$validation_findings) > 0)
})
