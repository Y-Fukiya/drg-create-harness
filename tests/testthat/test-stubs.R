test_that("GraphRAG and integrated reviewer guide stubs return clear not implemented errors", {
  expect_error(rg_init_integrated_project(), "Integrated reviewer guide support is not implemented yet", fixed = TRUE)
  expect_error(rg_draft_integrated_guide(), "Integrated reviewer guide support is not implemented yet", fixed = TRUE)
  expect_error(rg_build_kg(), "Knowledge graph support is not implemented yet", fixed = TRUE)
  expect_error(rg_query_kg(), "Knowledge graph query support is not implemented yet", fixed = TRUE)
  expect_error(rg_retrieve_context(tempdir(), "query", backend = "graph"), "not implemented yet", fixed = TRUE)
})
