test_that("synthetic E2E example script runs from package fixtures", {
  env <- new.env(parent = globalenv())

  sys.source(rg_fixture("examples", "synthetic-e2e.R"), envir = env)

  expect_true(file.exists(env$result$docx))
  expect_true(file.exists(env$result$qc_path))
  expect_equal(env$result$manifest_rows, 4)
  expect_true(env$result$dataset_rows > 0)
  expect_true(env$result$validation_finding_rows > 0)
  expect_equal(env$result$draft_sections, 5)
  expect_equal(env$result$qc_fail_rows, 0)
})
