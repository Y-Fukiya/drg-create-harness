# Release Checklist

Use this checklist before pushing or opening a pull request.

- Run `Rscript -e 'testthat::test_local(reporter = "summary")'`.
- Run `R CMD build .`.
- Run `_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual --no-build-vignettes <tarball>`.
- Run the synthetic E2E example:
  `source(system.file("examples", "synthetic-e2e.R", package = "reviewerguideR"))`
  after installing the package.
- Confirm ADRG and cSDRG DOCX outputs are created.
- Confirm `work/qc/qc_report.csv` is present for sample projects.
- Confirm no PHUSE templates, PDFs, external API calls, or subject-level dataset
  records are included in tests.
- Confirm `git remote -v` points to the intended GitHub repository before
  pushing or creating a pull request.
