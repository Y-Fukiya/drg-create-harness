# GitHub Publish Notes

The local repository is ready for GitHub publication, but no `origin` remote is
configured yet. Do not create a GitHub repository implicitly; choose the owner,
repository name, visibility, and default branch intentionally.

Suggested flow after the GitHub repository exists:

```sh
git remote add origin https://github.com/<owner>/<repo>.git
git branch -M main
git push -u origin main
```

For subsequent changes, create a feature branch and draft PR:

```sh
git switch -c codex/<short-description>
git push -u origin codex/<short-description>
gh pr create --draft --fill
```

Before pushing, run:

```sh
Rscript -e 'testthat::test_local(reporter = "summary")'
R CMD build .
_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual --no-build-vignettes reviewerguideR_0.0.0.9000.tar.gz
```
