# Reviewer Guide Harness

This repository is meant to be used as a local harness, not only as an R
package. The package functions are the engine. The harness entrypoints are:

- `make init`
- `make run`
- `make run-example`
- `Rscript scripts/run_harness.R ...`
- `scripts\run_harness.ps1` on Windows PowerShell
- `scripts\run_harness.cmd` on Windows Command Prompt

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
  templates/
    reviewers-guide.Rmd
    word/
      base.docx
  work/
    manifest.json
    extracted/
      define_valuelevel.csv
    drafts/
    evidence/
    qc/
      adrg_qc_report.csv
      csdrg_qc_report.csv
      qc_report.csv
      adrg_qc_summary.csv
      csdrg_qc_summary.csv
      qc_summary.csv
  output/
    adrg_draft.docx
    csdrg_draft.docx
    harness_summary.json
```

Only `source/` and selected fields in `config.yml` are intended to be edited by
users. `templates/reviewers-guide.Rmd` and `templates/word/base.docx` may be
edited when changing Word output structure or styles. `work/` and `output/` are
generated artifacts.

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

If your validation export uses non-standard column names, edit
`config.yml` before running:

```yaml
validation:
  column_mapping:
    rule_id: ["Finding Identifier", "Rule Reference"]
    severity: ["Impact Classification", "Finding Grade"]
    dataset_name: ["Dataset Code", "Data Set"]
    variable_name: ["Variable Code", "Variable Column"]
    message: ["Finding Narrative", "Finding Text"]
    count: ["Records Impacted", "Rows Impacted"]
    sponsor_explanation: ["Response Text"]
    status: ["Review Disposition"]
```

You only need to list the fields that differ from the built-in defaults.

Run both guides:

```bash
make run PROJECT=studies/ABC-001 GUIDE=both
```

On Windows PowerShell, the same flow is:

```powershell
.\scripts\run_harness.ps1 -Project .\studies\ABC-001 -StudyId ABC-001 -Init -NoRun
.\scripts\run_harness.ps1 -Project .\studies\ABC-001 -Guide both
```

## Run The Bundled Example

```bash
make run-example PROJECT=.harness/rg-harness-demo EXAMPLE=anonymous
```

The output DOCX files and summary JSON will be written under:

```text
.harness/rg-harness-demo/output/
```

Windows PowerShell:

```powershell
.\scripts\run_harness.ps1 -Project .\.harness\rg-harness-demo -CopyExample anonymous
```

## Run Mock LLM Drafting

Mock mode produces deterministic structured draft sections without API keys or
external provider calls:

```bash
Rscript scripts/run_harness.R --project .harness/rg-demo --copy-example anonymous --llm-mode mock
```

The mock context is built from extracted `define.xml` metadata and validation
findings only. XPT contents and dataset records are excluded. Generated DOCX
files remain drafts that require human review.

## Run The CDISC Pilot External Fixture

CDISC Pilot data are not bundled in `inst/extdata/`. Clone or download the
upstream project locally, then opt in to the external fixture.

macOS/Linux:

```bash
git clone https://github.com/cdisc-org/sdtm-adam-pilot-project .harness/external/cdisc-pilot
Rscript scripts/run_harness.R --project .harness/rg-cdisc-pilot --external-example cdisc-pilot --llm-mode mock
```

Windows PowerShell:

```powershell
git clone https://github.com/cdisc-org/sdtm-adam-pilot-project .\.harness\external\cdisc-pilot
.\scripts\run_harness.ps1 -Project .\.harness\rg-cdisc-pilot -ExternalExample cdisc-pilot -LlmMode mock
```

If the external source is not under the default `.harness/external/cdisc-pilot`
path, pass it explicitly:

```bash
Rscript scripts/run_harness.R --project .harness/rg-cdisc-pilot --external-example cdisc-pilot --external-source PATH --llm-mode mock
```

```powershell
.\scripts\run_harness.ps1 -Project .\.harness\rg-cdisc-pilot -ExternalExample cdisc-pilot -ExternalSource PATH -LlmMode mock
```

The project work area records the upstream URL, optional commit SHA when
available, attribution, disclaimer source, and local file hashes.
Only `define.xml` metadata files are copied into the harness project. CDISC
Pilot datasets and PDFs remain external and should not be committed.

## Direct CLI

```bash
Rscript scripts/run_harness.R \
  --project studies/ABC-001 \
  --study-id ABC-001 \
  --guide both
```

Windows Command Prompt:

```bat
scripts\run_harness.cmd --project studies\ABC-001 --study-id ABC-001 --guide both
```

Guided prompt flow:

```bash
Rscript scripts/run_harness.R --interactive --project studies/ABC-001
```

Useful options:

- `--init`: initialize the project if needed.
- `--no-run`: initialize/copy inputs and stop before generation.
- `--copy-example synthetic|anonymous`: populate `source/` from bundled fixtures.
- `--llm-mode dry_run|mock|ellmer`: choose the drafting mode.
- `--external-example cdisc-pilot`: prepare an optional local external fixture.
- `--external-source PATH`: use a non-default external fixture source path.
- `--interactive`: prompt for common project, guide, example, and run options.
- `--fail-on-qc`: return exit code 2 when any QC row fails.
- `--summary PATH`: write summary JSON somewhere other than `output/harness_summary.json`.

## Word Rendering

The default DOCX path is:

```text
templates/reviewers-guide.Rmd
  -> officedown::rdocx_document()
  -> output/*_draft.docx
```

`templates/word/base.docx` is the only default Word style base. Replace that
file with a company or study style base when you need fixed paragraph, heading,
caption, list, or table styles. Generated tables are built with `flextable`.

The relevant `config.yml` fields are:

```yaml
render:
  engine: officedown
  rmd: templates/reviewers-guide.Rmd
  reference_docx: templates/word/base.docx
```

Guide-specific `rmd`, `reference_docx`, and `output` values can also be set
under `guides.adrg` or `guides.csdrg`. Use `engine: officer` only when you need
the legacy direct DOCX fallback.

## What A Run Does

Each run performs the same deterministic pipeline:

1. scan files under `source/` into `work/manifest.json`
2. extract define.xml and validation metadata into `work/extracted/`
3. build evidence rows in `work/evidence/evidence_table.csv`
4. draft ADRG/cSDRG JSON under `work/drafts/`
5. write guide-specific QC rows and summaries under `work/qc/`
6. render DOCX files under `output/` from the officedown Rmd template,
   including a compact QC summary when available
7. write `output/harness_summary.json`

QC failures do not stop DOCX generation by default. They are review signals for
the generated draft. Use `--fail-on-qc` when running this from automation that
should fail on any QC issue.

## Current MVP Boundaries

- XLSX support uses `readxl` when installed; otherwise the fallback handles only
  simple single-sheet workbooks.
- Multiple-sheet XLSX, merged cells, formula cells, and complex type inference
  are intentionally outside the MVP fallback.
- `ValueListDef` and `WhereClauseDef` are expanded into the flat
  `work/extracted/define_valuelevel.csv` table when ItemRef and RangeCheck
  metadata are present. More complex relationships are flagged as human-review
  items.
- External codelist dictionary/version attributes and Origin detail text are
  extracted when present.
- Real ellmer providers, ragnar, iADRG/icSDRG, and GraphRAG remain next-phase
  integration points.
