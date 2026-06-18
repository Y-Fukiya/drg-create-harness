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
