test_that("rg_extract_validation reads CSV validation findings and adds evidence_id", {
  csv <- rg_fixture("extdata", "synthetic_study", "source", "analysis", "validation", "adam_validation.csv")
  findings <- rg_extract_validation(csv, study_id = "TEST-001", data_class = "adam")

  expect_equal(nrow(findings), 2)
  expect_equal(findings$rule_id[[1]], "AD001")
  expect_true(all(nzchar(findings$evidence_id)))
})

test_that("rg_extract_validation reads XLSX validation findings", {
  xlsx <- tempfile(fileext = ".xlsx")
  write_minimal_xlsx(xlsx, data.frame(
    `Rule ID` = "XL001",
    Severity = "Warning",
    Dataset = "ADSL",
    Variable = "SAFFL",
    Message = "XLSX validation finding",
    Count = "3",
    check.names = FALSE
  ))

  findings <- rg_extract_validation(xlsx, study_id = "TEST-001", data_class = "adam")

  expect_equal(nrow(findings), 1)
  expect_equal(findings$rule_id, "XL001")
  expect_equal(findings$count, 3L)
  expect_true(nzchar(findings$evidence_id))
})

test_that("rg_extract_validation supports explicit validation column mapping", {
  csv <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(
    `Finding Identifier` = "CUSTOM-001",
    `Impact Tier` = "Major",
    `Dataset Alias` = "ADSL",
    `Field Alias` = "SAFFL",
    `Finding Narrative` = "Custom mapped validation finding",
    `Affected Rows` = "7",
    `Team Response` = "Explain in ADRG",
    `Review State` = "Open",
    check.names = FALSE
  ), csv, row.names = FALSE)

  findings <- rg_extract_validation(
    csv,
    study_id = "TEST-001",
    data_class = "adam",
    column_mapping = list(
      rule_id = "Finding Identifier",
      severity = "Impact Tier",
      dataset_name = "Dataset Alias",
      variable_name = "Field Alias",
      message = "Finding Narrative",
      count = "Affected Rows",
      sponsor_explanation = "Team Response",
      status = "Review State"
    )
  )

  expect_equal(findings$rule_id, "CUSTOM-001")
  expect_equal(findings$severity, "Major")
  expect_equal(findings$dataset_name, "ADSL")
  expect_equal(findings$variable_name, "SAFFL")
  expect_equal(findings$count, 7L)
  expect_equal(findings$sponsor_explanation, "Explain in ADRG")
})

test_that("rg_extract_validation keeps CSV identifiers as text and parses comma counts", {
  csv <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(
    `Rule ID` = "00123",
    Severity = "Warning",
    Dataset = "ADSL",
    Variable = "USUBJID",
    Message = "Identifier retains leading zeros",
    Count = "1,234",
    check.names = FALSE
  ), csv, row.names = FALSE)

  findings <- rg_extract_validation(csv, study_id = "TEST-001", data_class = "adam")

  expect_equal(findings$rule_id, "00123")
  expect_equal(findings$count, 1234L)
})

test_that("rg_extract_metadata applies validation column mapping from config.yml", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)

  custom_validation <- file.path(proj, "source", "analysis", "validation", "mapped_validation.csv")
  utils::write.csv(data.frame(
    `Rule Reference` = "CFG-001",
    `Finding Grade` = "Warning",
    `Data Set` = "ADSL",
    `Variable Column` = "SAFFL",
    `Finding Text` = "Config mapped validation finding",
    `Rows Impacted` = "4",
    check.names = FALSE
  ), custom_validation, row.names = FALSE)

  config <- rg_read_config(proj)
  config$validation$column_mapping$rule_id <- "Rule Reference"
  config$validation$column_mapping$severity <- "Finding Grade"
  config$validation$column_mapping$dataset_name <- "Data Set"
  config$validation$column_mapping$variable_name <- "Variable Column"
  config$validation$column_mapping$message <- "Finding Text"
  config$validation$column_mapping$count <- "Rows Impacted"
  rg_write_config(config, file.path(proj, "config.yml"), overwrite = TRUE)

  rg_scan_sources(proj)
  extracted <- rg_extract_metadata(proj)

  mapped <- extracted$validation_findings[extracted$validation_findings$rule_id == "CFG-001", ]
  expect_equal(nrow(mapped), 1)
  expect_equal(mapped$dataset_name, "ADSL")
  expect_equal(mapped$variable_name, "SAFFL")
  expect_equal(mapped$count, 4L)
})

test_that("built-in XLSX fallback rejects workbook features outside MVP scope", {
  skip_if(requireNamespace("readxl", quietly = TRUE), "readxl installed; fallback is bypassed")

  multi_sheet <- tempfile(fileext = ".xlsx")
  write_minimal_xlsx(multi_sheet, data.frame(
    `Rule ID` = "XL001",
    Severity = "Warning",
    Dataset = "ADSL",
    check.names = FALSE
  ), extra_sheet = TRUE)
  expect_error(
    rg_extract_validation(multi_sheet, study_id = "TEST-001", data_class = "adam"),
    "single-sheet workbooks",
    fixed = TRUE
  )

  merged <- tempfile(fileext = ".xlsx")
  write_minimal_xlsx(merged, data.frame(
    `Rule ID` = "XL001",
    Severity = "Warning",
    Dataset = "ADSL",
    check.names = FALSE
  ), merged_cells = TRUE)
  expect_error(
    rg_extract_validation(merged, study_id = "TEST-001", data_class = "adam"),
    "merged cells",
    fixed = TRUE
  )
})

test_that("rg_extract_validation rejects unsupported validation file formats", {
  pdf <- tempfile(fileext = ".pdf")
  writeLines("not a parsed validation report", pdf)

  expect_error(
    rg_extract_validation(pdf, study_id = "TEST-001"),
    "supports only .csv and .xlsx",
    fixed = TRUE
  )
})
