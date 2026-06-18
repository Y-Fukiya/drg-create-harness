test_that("rg_extract_define extracts datasets, variables, codelists, and methods from namespaced XML", {
  define_xml <- rg_fixture("extdata", "synthetic_study", "source", "analysis", "define.xml")
  result <- rg_extract_define(define_xml, study_id = "TEST-001", data_class = "adam")

  expect_s3_class(result$define_datasets, "tbl_df")
  expect_true("ADSL" %in% result$define_datasets$dataset_name)
  expect_true("SAFFL" %in% result$define_variables$variable_name)
  expect_true("CL.NY" %in% result$define_codelists$codelist_oid)
  expect_true("MT.SAFFL" %in% result$define_methods$method_oid)
  expect_s3_class(result$define_valuelevel, "tbl_df")
  expect_true(all(nzchar(result$define_datasets$evidence_id)))
  expect_true(any(grepl("^ValueListDef\\[", result$evidence_table$locator)))
  expect_true(any(grepl("^WhereClauseDef\\[", result$evidence_table$locator)))
  expect_true(any(!is.na(result$define_valuelevel$value_list_oid)))
  expect_true(any(!is.na(result$define_valuelevel$where_clause_oid)))
  complex_evidence <- result$evidence_table[grepl("^(ValueListDef|WhereClauseDef)\\[", result$evidence_table$locator), ]
  expect_false(any(complex_evidence$needs_human_review))
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

test_that("rg_extract_define captures external codelists, origin detail, and complex value-level review signals", {
  define_xml <- tempfile(fileext = ".xml")
  writeLines(c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<odm:ODM xmlns:odm="http://www.cdisc.org/ns/odm/v1.3" xmlns:def="http://www.cdisc.org/ns/def/v2.1">',
    '  <odm:Study OID="S.COMPLEX">',
    '    <odm:GlobalVariables><odm:StudyName>COMPLEX-001</odm:StudyName></odm:GlobalVariables>',
    '    <odm:MetaDataVersion OID="MDV.COMPLEX" Name="Complex">',
    '      <def:ItemGroupDef OID="IG.ADX" Name="ADX" Label="Complex Analysis" Purpose="Analysis" def:Structure="One record per subject">',
    '        <odm:ItemRef ItemOID="IT.ADX.PARAMCD" Mandatory="Yes"/>',
    '        <odm:ItemRef ItemOID="IT.ADX.AVAL" Mandatory="No"/>',
    '      </def:ItemGroupDef>',
    '      <odm:ItemDef OID="IT.ADX.PARAMCD" Name="PARAMCD" Label="Parameter Code" DataType="text">',
    '        <odm:CodeListRef CodeListOID="CL.PARAM"/>',
    '      </odm:ItemDef>',
    '      <odm:ItemDef OID="IT.ADX.AVAL" Name="AVAL" Label="Analysis Value" DataType="float">',
    '        <def:Origin Type="Predecessor">',
    '          <odm:Description><odm:TranslatedText xml:lang="en">Source variable: SDTM.LB.LBSTRESN</odm:TranslatedText></odm:Description>',
    '        </def:Origin>',
    '      </odm:ItemDef>',
    '      <odm:CodeList OID="CL.PARAM" Name="Parameters" DataType="text">',
    '        <odm:CodeListItem CodedValue="RESP"><odm:Decode><odm:TranslatedText xml:lang="en">Response</odm:TranslatedText></odm:Decode></odm:CodeListItem>',
    '      </odm:CodeList>',
    '      <odm:CodeList OID="CL.MEDDRA" Name="MedDRA Terms" DataType="text">',
    '        <def:ExternalCodeList Dictionary="MedDRA" Version="25.1"/>',
    '      </odm:CodeList>',
    '      <def:ValueListDef OID="VL.ADX.AVAL">',
    '        <odm:ItemRef ItemOID="IT.UNKNOWN" Mandatory="No" def:WhereClauseOID="WC.MISSING"/>',
    '      </def:ValueListDef>',
    '      <def:WhereClauseDef OID="WC.ADX.COMPLEX">',
    '        <odm:RangeCheck SoftHard="Soft" def:ItemOID="IT.ADX.PARAMCD" Comparator="EQ"><odm:CheckValue>RESP</odm:CheckValue></odm:RangeCheck>',
    '        <odm:RangeCheck SoftHard="Soft" def:ItemOID="IT.MISSING" Comparator="EQ"/>',
    '      </def:WhereClauseDef>',
    '    </odm:MetaDataVersion>',
    '  </odm:Study>',
    '</odm:ODM>'
  ), define_xml)

  result <- rg_extract_define(define_xml, data_class = "adam")

  aval <- result$define_variables[result$define_variables$variable_name == "AVAL", ]
  expect_equal(aval$origin, "Predecessor")
  expect_equal(aval$origin_detail, "Source variable: SDTM.LB.LBSTRESN")

  external <- result$define_codelists[result$define_codelists$codelist_oid == "CL.MEDDRA", ]
  expect_equal(external$external_dictionary, "MedDRA")
  expect_equal(external$external_version, "25.1")

  expect_true(any(result$define_valuelevel$needs_human_review))
  complex_evidence <- result$evidence_table[grepl("^(ValueListDef|WhereClauseDef)\\[", result$evidence_table$locator), ]
  expect_true(any(complex_evidence$needs_human_review))
})
