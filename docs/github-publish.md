# GitHub Publish Notes

Use this checklist before making the repository public or cutting a public MVP
tag.

## Repository State

- Repository: `Y-Fukiya/drg-create-harness`
- Main development PR branch: `codex/reviewerguider-mvp`
- Default branch: `main`
- Public MVP tag target: `0.1.0`

## Public Readiness Checklist

- Confirm `DESCRIPTION` has the intended maintainer name, email, URL, and
  BugReports fields.
- Confirm `LICENSE` has the intended copyright holder.
- Confirm `README.md` explains that generated reviewer guides are drafts and
  require human review.
- Confirm no real study data, subject-level datasets, sponsor documents,
  protocols, SAPs, CSRs, aCRFs, API keys, local paths, or proprietary templates
  are tracked.
- Confirm `studies/` and `.harness/` remain ignored in both `.gitignore` and
  `.Rbuildignore`.
- Confirm bundled fixtures under `inst/extdata/` are synthetic or anonymous.
- Confirm fixtures cover both simple and review-required define.xml paths so QC
  signals do not depend only on happy-path metadata.
- Confirm GitHub Actions `R CMD check` passes on Ubuntu and Windows.
- Confirm the repository visibility change is intentional before switching from
  private to public.

## Validation Commands

Run locally before publishing:

```sh
Rscript -e 'testthat::test_local(reporter = "summary")'
R CMD build .
_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual --no-build-vignettes reviewerguideR_0.1.0.tar.gz
```

Run a harness example:

```sh
Rscript scripts/run_harness.R \
  --project .harness/public-readiness-check \
  --study-id PUBLIC-CHECK-001 \
  --guide both \
  --copy-example anonymous
```

## After Merge

After the PR is merged to `main`:

```sh
git switch main
git pull
git tag -a v0.1.0 -m "reviewerguideR MVP harness release"
git push origin v0.1.0
```

Only change repository visibility to public after the checklist above is clean.
