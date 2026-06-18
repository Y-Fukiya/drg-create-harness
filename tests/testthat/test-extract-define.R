test_that("rg_extract_define extracts datasets, variables, codelists, and methods from namespaced XML", {
  define_xml <- rg_fixture("extdata", "synthetic_study", "source", "analysis", "define.xml")
  result <- rg_extract_define(define_xml, study_id = "TEST-001", data_class = "adam")

  expect_s3_class(result$define_datasets, "tbl_df")
  expect_true("ADSL" %in% result$define_datasets$dataset_name)
  expect_true("SAFFL" %in% result$define_variables$variable_name)
  expect_true("CL.NY" %in% result$define_codelists$codelist_oid)
  expect_true("MT.SAFFL" %in% result$define_methods$method_oid)
  expect_true(all(nzchar(result$define_datasets$evidence_id)))
  expect_true(any(grepl("^ValueListDef\\[", result$evidence_table$locator)))
  expect_true(any(grepl("^WhereClauseDef\\[", result$evidence_table$locator)))
  expect_true(any(result$evidence_table$needs_human_review))
})
