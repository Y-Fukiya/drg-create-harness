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

test_that("rg_extract_define handles prefixed define.xml metadata elements", {
  define_xml <- tempfile(fileext = ".xml")
  writeLines(c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<odm:ODM xmlns:odm="http://www.cdisc.org/ns/odm/v1.3" xmlns:def="http://www.cdisc.org/ns/def/v2.1" xmlns:xlink="http://www.w3.org/1999/xlink">',
    '  <odm:Study OID="S.PREFIX">',
    '    <odm:GlobalVariables><odm:StudyName>PREFIX-001</odm:StudyName></odm:GlobalVariables>',
    '    <odm:MetaDataVersion OID="MDV.PREFIX" Name="Prefixed">',
    '      <def:ItemGroupDef OID="IG.ADVS" Name="ADVS" Label="Vital Signs Analysis" Purpose="Analysis" def:Structure="One record per parameter">',
    '        <def:leaf xlink:href="advs.xpt"><def:title>advs.xpt</def:title></def:leaf>',
    '        <odm:ItemRef ItemOID="IT.ADVS.AVAL" Mandatory="Yes" MethodOID="MT.AVAL"/>',
    '      </def:ItemGroupDef>',
    '      <odm:ItemDef OID="IT.ADVS.AVAL" Name="AVAL" Label="Analysis Value" DataType="float"/>',
    '      <def:MethodDef OID="MT.AVAL" Name="Analysis value" Type="Computation">',
    '        <odm:Description><odm:TranslatedText xml:lang="en">Copied from source.</odm:TranslatedText></odm:Description>',
    '      </def:MethodDef>',
    '    </odm:MetaDataVersion>',
    '  </odm:Study>',
    '</odm:ODM>'
  ), define_xml)

  result <- rg_extract_define(define_xml, data_class = "adam")

  expect_equal(result$define_datasets$dataset_name, "ADVS")
  expect_equal(result$define_variables$variable_name, "AVAL")
  expect_equal(result$define_methods$method_oid, "MT.AVAL")
  expect_equal(result$define_datasets$dataset_location, "advs.xpt")
})
