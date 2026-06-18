test_that("harness CLI runs bundled example end to end", {
  candidates <- c(
    file.path("scripts", "run_harness.R"),
    file.path("..", "..", "scripts", "run_harness.R")
  )
  found <- candidates[file.exists(candidates)]
  script <- if (length(found) > 0) found[[1]] else candidates[[1]]
  script <- normalizePath(script, winslash = "/", mustWork = FALSE)
  skip_if_not(file.exists(script), "harness CLI script is not available in this check context")

  project <- tempfile("rg-harness-cli-")
  rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  output <- system2(
    rscript,
    c(
      script,
      "--project", project,
      "--study-id", "HARNESS-CLI-001",
      "--guide", "both",
      "--copy-example", "synthetic"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status")
  if (is.null(status)) {
    status <- 0L
  }

  expect_equal(status, 0L, info = paste(output, collapse = "\n"))
  expect_true(file.exists(file.path(project, "output", "adrg_draft.docx")))
  expect_true(file.exists(file.path(project, "output", "csdrg_draft.docx")))
  expect_true(file.exists(file.path(project, "output", "harness_summary.json")))
  expect_true(file.exists(file.path(project, "work", "qc", "adrg_qc_summary.csv")))
  expect_true(file.exists(file.path(project, "work", "qc", "csdrg_qc_summary.csv")))
  expect_true(file.exists(file.path(project, "work", "qc", "qc_summary.csv")))

  summary <- jsonlite::read_json(file.path(project, "output", "harness_summary.json"), simplifyVector = TRUE)
  expect_equal(summary$status, "completed")
  expect_equal(summary$manifest_rows, 4)
  expect_true(summary$define_dataset_rows > 0)
  expect_true(summary$validation_finding_rows > 0)
  expect_equal(summary$outputs$adrg$qc_summary_path, file.path(project, "work", "qc", "adrg_qc_summary.csv"))
  expect_true(summary$outputs$adrg$qc$summary_status %in% c("pass", "review", "fail"))
})

test_that("harness CLI interactive mode accepts prompted defaults and choices", {
  candidates <- c(
    file.path("scripts", "run_harness.R"),
    file.path("..", "..", "scripts", "run_harness.R")
  )
  found <- candidates[file.exists(candidates)]
  script <- if (length(found) > 0) found[[1]] else candidates[[1]]
  script <- normalizePath(script, winslash = "/", mustWork = FALSE)
  skip_if_not(file.exists(script), "harness CLI script is not available in this check context")

  project <- tempfile("rg-harness-interactive-")
  rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  output <- system2(
    rscript,
    c(
      script,
      "--interactive",
      "--project", project,
      "--study-id", "HARNESS-INT-001",
      "--guide", "adrg",
      "--copy-example", "synthetic"
    ),
    input = c("", "", "", "", ""),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status")
  if (is.null(status)) {
    status <- 0L
  }

  expect_equal(status, 0L, info = paste(output, collapse = "\n"))
  expect_true(file.exists(file.path(project, "output", "adrg_draft.docx")))
  expect_false(file.exists(file.path(project, "output", "csdrg_draft.docx")))
  expect_true(file.exists(file.path(project, "work", "qc", "adrg_qc_summary.csv")))
})
