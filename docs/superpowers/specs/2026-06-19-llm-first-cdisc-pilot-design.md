# LLM-First Drafting With CDISC Pilot External Fixtures

## Context

The next extension phase prioritizes LLM-assisted drafting before ragnar,
iADRG/icSDRG, GraphRAG, or GUI work. The first implementation step must be
mock-driven and deterministic. Real LLM provider calls remain disabled unless
the user explicitly enables them later.

The CDISC SDTM/ADaM Pilot Project can provide realistic public metadata and
submission-package documents for local evaluation. It must be treated as an
external reference fixture, not as package-bundled data.

Primary external source:

- Repository: <https://github.com/cdisc-org/sdtm-adam-pilot-project>
- Example package path:
  `updated-pilot-submission-package/900172/m5/datasets/cdiscpilot01`
- SDTM define path:
  `updated-pilot-submission-package/900172/m5/datasets/cdiscpilot01/tabulations/sdtm/define.xml`

## Goals

- Add a deterministic LLM drafting surface that works without network access,
  API keys, or installed LLM providers.
- Define the structured output contract before adding real `ellmer`
  integrations.
- Use CDISC Pilot metadata and documents as optional local E2E input so the
  mock path is tested against realistic public material.
- Preserve the harness safety model: generated guide text is draft-only,
  evidence-bound, and always reviewable by a human.
- Keep package tests independent of external downloads and external services.

## Non-Goals

- Do not call real LLM providers in automated tests.
- Do not require `ellmer` for package checks.
- Do not add `ragnar`, GraphRAG, iADRG/icSDRG, or GUI behavior in this phase.
- Do not commit CDISC Pilot data, XPT files, PDFs, generated subsets, or
  derived subject-level records into this repository.
- Do not send XPT contents, dataset records, or subject-level data to any LLM,
  RAG, or external API path.

## User Workflow

The initial user-facing workflow should remain local and explicit.

1. The user prepares a harness project.
2. The user optionally downloads or points to the CDISC Pilot Project under
   `.harness/external/cdisc-pilot/`.
3. The harness records source URL, source commit SHA, attribution, disclaimer
   location, and local file hashes in the project manifest.
4. The user runs the harness in deterministic mock LLM mode.
5. The harness produces draft section output with evidence IDs and human-review
   flags.
6. The generated DOCX remains a draft and is reviewed manually.

The initial implementation should support this CLI shape:

```sh
Rscript scripts/run_harness.R --project .harness/rg-cdisc-pilot --external-example cdisc-pilot --llm-mode mock
```

`--external-example cdisc-pilot` selects the optional external fixture, and
`--llm-mode mock` selects deterministic mock drafting. CDISC Pilot is an opt-in
external fixture, not an installed package fixture.

## Data Boundaries

Allowed LLM mock inputs:

- `define.xml` extracted metadata
- validation finding metadata
- guide section IDs and guide type
- manifest metadata for eligible non-subject-level files
- short document snippets from explicitly allowed non-subject-level documents,
  when a later implementation adds document extraction

Disallowed LLM inputs:

- XPT row contents
- subject-level dataset records
- sponsor or proprietary documents
- credentials, API keys, local user paths that are not needed for traceability
- any file not marked eligible by manifest/config rules

The LLM mock path should use the same eligibility rules expected for a future
real LLM path. This keeps the tests meaningful and prevents a later provider
adapter from widening the data surface by accident.

## CDISC Pilot Handling

CDISC Pilot content is useful because it is public, domain-relevant, and
contains realistic define metadata and supporting documents. It also carries
terms of use and attribution requirements. Therefore:

- Store CDISC Pilot files only under ignored local paths such as
  `.harness/external/cdisc-pilot/` or a user-supplied project path.
- Do not copy CDISC Pilot files into `inst/extdata/`.
- Do not commit downloaded CDISC Pilot files or generated subsets.
- Record the upstream repository URL and commit SHA in the local project
  manifest.
- Record an attribution note that the data comes from CDISC.
- Record the disclaimer/terms source path or URL in the manifest.
- Use only metadata-derived artifacts in the LLM mock context.

The existing synthetic and anonymous examples remain the only bundled examples
under `inst/extdata/`.

## Structured Output Contract

The mock LLM drafting result should be a typed table or list with these fields:

- `guide_type`: `adrg` or `csdrg`
- `section_id`: target guide section
- `draft_text`: generated draft text for the section
- `evidence_ids`: evidence IDs that support the draft text
- `source_context_ids`: context IDs supplied to the mock model
- `confidence`: numeric confidence between 0 and 1
- `needs_human_review`: logical flag
- `warnings`: character vector or delimited text of review warnings
- `llm_mode`: initially `mock`
- `provider`: initially `mock`

The mock model must be deterministic. Given the same extracted metadata and
section ID, it should return byte-stable output, except for allowed manifest
timestamps that are already handled elsewhere.

`needs_human_review` should be `TRUE` when:

- no evidence IDs support the section
- extracted metadata already has unresolved review flags
- the section is intentionally out of scope for mock drafting
- context eligibility excludes information needed for a complete answer

## Component Shape

Implementation should be planned around these components:

- `rg_collect_llm_context()`: builds metadata-only context for a section.
- `rg_draft_section_mock()`: deterministic structured draft helper.
- `rg_draft_section_ellmer()`: remains fail-closed until real provider support
  is explicitly implemented.
- Harness config: adds explicit LLM mode and external fixture controls.
- Manifest extension: records CDISC Pilot source URL, commit SHA, attribution,
  disclaimer source, and file hashes.
- Tests: validate the structured output contract, data-boundary rules, and
  CDISC Pilot manifest behavior without downloading external data.

If an existing package convention forces a name adjustment, keep a compatibility
alias or document the reason in the implementation plan. The boundaries above
should remain intact.

## Error Handling

- If LLM mode is disabled, drafting helpers must fail closed with a clear
  message.
- If `mode = "ellmer"` is requested and `ellmer` is not installed, keep the
  current clear installation error.
- If real external providers are disabled by config, provider calls must not be
  attempted.
- If CDISC Pilot files are missing, the optional external example should report
  setup instructions and skip rather than silently falling back to synthetic
  data.
- If disallowed files are detected in LLM context construction, fail closed and
  report the offending file class or path.

## Testing Strategy

Automated tests:

- exercise mock LLM structured output with bundled synthetic/anonymous fixtures
- assert no provider calls are required
- assert `ellmer` remains optional
- assert XPT paths and dataset records are excluded from LLM context
- assert evidence IDs propagate into draft results
- assert human-review flags are set for unsupported or evidence-poor sections
- assert CDISC Pilot manifest construction can be tested with tiny local fake
  files that mimic the external directory shape

Manual/local tests:

- download or clone the CDISC Pilot Project into `.harness/external/cdisc-pilot/`
- run the harness against SDTM and ADaM define metadata
- inspect generated QC, manifest, and DOCX draft
- confirm the manifest records source URL, commit SHA, attribution, disclaimer,
  and file hashes

CI must not require network access to GitHub or CDISC content.

## Acceptance Criteria

- A user can run deterministic mock LLM drafting without API keys.
- Mock drafting output has a stable structured contract and evidence IDs.
- External CDISC Pilot handling is opt-in and leaves no downloaded data in git.
- LLM context construction excludes subject-level records and XPT contents.
- Package checks pass without `ellmer`, `ragnar`, external downloads, or API
  credentials.
- Documentation tells users how to use CDISC Pilot as an external local fixture
  and how to respect its source terms and attribution requirements.

## Future Work

After this phase is stable:

- Add a real `ellmer` adapter behind explicit config gates.
- Add provider-specific structured response validation.
- Add ragnar retrieval only after metadata-only context and manifest eligibility
  are proven with mock retrieval.
- Revisit iADRG/icSDRG once single-study mock LLM drafting is reliable.
- Revisit GraphRAG only when a concrete graph traversal workflow is needed.
