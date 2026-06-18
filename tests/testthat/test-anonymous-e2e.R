test_that("anonymous study fixture supports ADRG and cSDRG E2E", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "ANON-101")
  copy_anonymous_sources(proj)

  manifest <- rg_scan_sources(proj)
  extracted <- rg_extract_metadata(proj)
  adrg <- rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")
  csdrg <- rg_draft_guide(proj, guide_type = "csdrg", mode = "dry_run")
  adrg_qc <- rg_qc(proj, guide_type = "adrg")
  csdrg_qc <- rg_qc(proj, guide_type = "csdrg")
  adrg_docx <- rg_render_docx(proj, guide_type = "adrg")
  csdrg_docx <- rg_render_docx(proj, guide_type = "csdrg")

  expect_equal(nrow(manifest), 4)
  expect_true(all(c("ADSL", "ADEFF", "DM", "LB") %in% extracted$define_datasets$dataset_name))
  expect_true("MT.AVAL" %in% extracted$define_methods$method_oid)
  expect_true("CL.PARAM" %in% extracted$define_codelists$codelist_oid)
  expect_true("ADAM-001" %in% extracted$validation_findings$rule_id)
  expect_true("SDTM-001" %in% extracted$validation_findings$rule_id)
  expect_equal(length(adrg$sections), 5)
  expect_equal(length(csdrg$sections), 5)
  expect_true(file.exists(adrg_docx))
  expect_true(file.exists(csdrg_docx))
  expect_true(any(adrg_qc$check_id == "unsupported_define_metadata" & adrg_qc$status == "fail"))
  expect_true(any(csdrg_qc$check_id == "unsupported_define_metadata" & csdrg_qc$status == "pass"))
})

test_that("anonymous validation data can be imported from generated XLSX", {
  xlsx <- tempfile(fileext = ".xlsx")
  write_minimal_xlsx(xlsx, data.frame(
    `Check ID` = "ADAM-XLSX-001",
    `Severity Level` = "Warning",
    `Dataset Name` = "ADEFF",
    `Variable Name` = "AVAL",
    Description = "Generated XLSX anonymous finding",
    `Record Count` = "5",
    `Sponsor Comment` = "Review in ADRG",
    Disposition = "Open",
    check.names = FALSE
  ))

  findings <- rg_extract_validation(xlsx, study_id = "ANON-101", data_class = "adam")

  expect_equal(findings$rule_id, "ADAM-XLSX-001")
  expect_equal(findings$dataset_name, "ADEFF")
  expect_equal(findings$variable_name, "AVAL")
  expect_equal(findings$count, 5L)
})

test_that("representative anonymous E2E supports project validation column mapping", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "ANON-REP-101")
  copy_anonymous_sources(proj)

  config <- rg_read_config(proj)
  config$validation$column_mapping$rule_id <- "Finding Identifier"
  config$validation$column_mapping$severity <- "Impact Classification"
  config$validation$column_mapping$dataset_name <- "Dataset Code"
  config$validation$column_mapping$variable_name <- "Variable Code"
  config$validation$column_mapping$message <- "Finding Narrative"
  config$validation$column_mapping$count <- "Records Impacted"
  config$validation$column_mapping$sponsor_explanation <- "Response Text"
  config$validation$column_mapping$status <- "Review Disposition"
  rg_write_config(config, file.path(proj, "config.yml"), overwrite = TRUE)

  custom_validation <- file.path(proj, "source", "analysis", "validation", "vendor_findings.csv")
  utils::write.csv(data.frame(
    `Finding Identifier` = "VENDOR-ADAM-001",
    `Impact Classification` = "Major",
    `Dataset Code` = "ADEFF",
    `Variable Code` = "AVAL",
    `Finding Narrative` = "Representative anonymous vendor finding",
    `Records Impacted` = "6",
    `Response Text` = "Discuss derivation and traceability in ADRG",
    `Review Disposition` = "Open",
    check.names = FALSE
  ), custom_validation, row.names = FALSE)

  rg_scan_sources(proj)
  extracted <- rg_extract_metadata(proj)
  rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")
  qc <- rg_qc(proj, guide_type = "adrg")
  qc_summary <- rg_qc_summary(proj, guide_type = "adrg", qc = qc)
  docx <- rg_render_docx(proj, guide_type = "adrg")

  expect_true("VENDOR-ADAM-001" %in% extracted$validation_findings$rule_id)
  expect_true(any(extracted$validation_findings$message == "Representative anonymous vendor finding"))
  expect_equal(qc_summary$guide_type, "adrg")
  expect_true(file.exists(file.path(proj, "work", "qc", "adrg_qc_summary.csv")))
  expect_true(file.exists(docx))
})
