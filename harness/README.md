# Reviewer Guide Harness

This repository is meant to be used as a local harness, not only as an R
package. The package functions are the engine. The harness entrypoints are:

- `make init`
- `make run`
- `make run-example`
- `Rscript scripts/run_harness.R ...`

## Directory Contract

A harness project has this shape:

```text
study-project/
  config.yml
  source/
    analysis/
      define.xml
      validation/
        adam_validation.csv
    tabulation/
      define.xml
      validation/
        sdtm_validation.csv
  work/
    manifest.json
    extracted/
    drafts/
    evidence/
    qc/
  output/
    adrg_draft.docx
    csdrg_draft.docx
    harness_summary.json
```

Only `source/` and selected fields in `config.yml` are intended to be edited by
users. `work/` and `output/` are generated artifacts.

## Start A New Study

```bash
make init PROJECT=studies/ABC-001 STUDY_ID=ABC-001
```

Then copy study inputs under `studies/ABC-001/source/`.

Minimum useful inputs:

- ADaM define.xml: `source/analysis/define.xml`
- ADaM validation findings: `source/analysis/validation/*.csv` or `*.xlsx`
- SDTM define.xml: `source/tabulation/define.xml`
- SDTM validation findings: `source/tabulation/validation/*.csv` or `*.xlsx`

Run both guides:

```bash
make run PROJECT=studies/ABC-001 GUIDE=both
```

## Run The Bundled Example

```bash
make run-example PROJECT=/private/tmp/rg-harness-demo EXAMPLE=anonymous
```

The output DOCX files and summary JSON will be written under:

```text
/private/tmp/rg-harness-demo/output/
```

## Direct CLI

```bash
Rscript scripts/run_harness.R \
  --project studies/ABC-001 \
  --study-id ABC-001 \
  --guide both
```

Useful options:

- `--init`: initialize the project if needed.
- `--no-run`: initialize/copy inputs and stop before generation.
- `--copy-example synthetic|anonymous`: populate `source/` from bundled fixtures.
- `--fail-on-qc`: return exit code 2 when any QC row fails.
- `--summary PATH`: write summary JSON somewhere other than `output/harness_summary.json`.

## What A Run Does

Each run performs the same deterministic pipeline:

1. scan files under `source/` into `work/manifest.json`
2. extract define.xml and validation metadata into `work/extracted/`
3. build evidence rows in `work/evidence/evidence_table.csv`
4. draft ADRG/cSDRG JSON under `work/drafts/`
5. write QC rows to `work/qc/qc_report.csv`
6. render DOCX files under `output/`
7. write `output/harness_summary.json`

QC failures do not stop DOCX generation by default. They are review signals for
the generated draft. Use `--fail-on-qc` when running this from automation that
should fail on any QC issue.

## Current MVP Boundaries

- XLSX support uses `readxl` when installed; otherwise the fallback handles only
  simple single-sheet workbooks.
- Multiple-sheet XLSX, merged cells, formula cells, and complex type inference
  are intentionally outside the MVP fallback.
- `ValueListDef` and `WhereClauseDef` are detected and surfaced as QC review
  items, but are not expanded into full reviewer-guide text yet.
- ellmer, ragnar, iADRG/icSDRG, and GraphRAG remain next-phase integration
  points.
