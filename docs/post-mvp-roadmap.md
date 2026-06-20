# Post-MVP Roadmap

This document records the post-MVP direction without expanding the current MVP
scope.

## Versioning

- Current public MVP version: `0.1.0`.
- Next development version after release should return to a `.9000` suffix.
- Patch releases should preserve existing public function signatures unless a
  breaking change is explicitly called out.

## ellmer

- Keep `ellmer` in `Suggests`.
- Current next step: validate deterministic mock structured output before any
  real provider workflow.
- Keep tests free of external provider calls and API keys.
- Context sent to LLMs must remain metadata-only. XPT files and dataset records
  stay excluded from LLM paths.
- Add real provider support only after mock output validation is stable.

## CDISC Pilot External Fixture

- Treat CDISC Pilot as an optional local external fixture.
- Do not bundle CDISC Pilot files or generated subsets in `inst/extdata/`.
- Record the upstream URL, commit SHA when available, attribution, disclaimer
  source, and local file hashes in the project work area.
- CI must not require downloading CDISC content.

## ragnar

- Keep `ragnar` in `Suggests`.
- Add local mock retrieval and fixture-based tests before enabling real indexes.
- Do not call embedding APIs in automated tests.
- RAG inputs should use manifest eligibility flags and exclude subject-level
  datasets.

## iADRG and icSDRG

- Keep `study_id` in all major data tables.
- Implement integrated guide support only after single-study ADRG/cSDRG behavior
  is stable on representative fixtures.
- Start with deterministic metadata joins across studies before adding any LLM
  generation path.

## GraphRAG

- Keep GraphRAG as a stub until there is a concrete user workflow that requires
  graph traversal beyond table joins and simple retrieval.
- Avoid Neo4j or other graph database dependencies in the package MVP line.

## Tauri and shinylive

- shinylive is suitable for demos or UI prototypes only.
- Production app packaging should use Tauri with a local R sidecar.
- Heavy tasks such as DOCX rendering, retrieval, and LLM integration should run
  in the local R process.

## Word and Multi-Output Publishing

- Keep `officedown` as the primary DOCX renderer while Word remains the review
  and delivery surface.
- Treat `templates/reviewers-guide.Rmd` as the editable document source and
  `templates/word/base.docx` as the single style base.
- Reconsider Quarto only if HTML/PDF/multi-output publishing becomes a real
  workflow requirement.
