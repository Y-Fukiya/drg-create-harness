test_that("GraphRAG and integrated reviewer guide stubs return clear not implemented errors", {
  expect_error(rg_init_integrated_project(), "Integrated reviewer guide support is not implemented yet", fixed = TRUE)
  expect_error(rg_draft_integrated_guide(), "Integrated reviewer guide support is not implemented yet", fixed = TRUE)
  expect_error(rg_build_kg(), "Knowledge graph support is not implemented yet", fixed = TRUE)
  expect_error(rg_query_kg(), "Knowledge graph query support is not implemented yet", fixed = TRUE)
  expect_error(rg_retrieve_context(tempdir(), "query", backend = "graph"), "not implemented yet", fixed = TRUE)
})

test_that("ellmer and ragnar integration points stay local and guarded", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")

  expect_error(
    rg_draft_guide(proj, guide_type = "adrg", mode = "ellmer"),
    "LLM drafting is disabled",
    fixed = TRUE
  )

  rag_none <- rg_build_rag_index(proj, backend = "none")
  expect_equal(rag_none$status, "skipped")

  context_none <- rg_retrieve_context(proj, "dataset inventory", backend = "none")
  expect_equal(nrow(context_none), 0)

  context_mock <- rg_retrieve_context(proj, "dataset inventory", backend = "mock")
  expect_equal(context_mock$context_id, "mock-1")

  expect_error(
    rg_retrieve_context(proj, "dataset inventory", backend = "hybrid"),
    "not implemented yet",
    fixed = TRUE
  )

  expect_error(
    rg_build_rag_index(proj, backend = "ragnar"),
    "ragnar",
    fixed = TRUE
  )
})
