# Post-MVP Roadmap

This document records the post-MVP direction without expanding the current MVP
scope.

## Versioning

- Current development version: `0.0.0.9000`.
- First internal trial release target: `0.1.0`.
- Patch releases should preserve existing public function signatures unless a
  breaking change is explicitly called out.

## ellmer

- Keep `ellmer` in `Suggests`.
- Keep tests free of external provider calls and API keys.
- Add mock-driven structured output tests before any real provider workflow.
- Context sent to LLMs must remain metadata-only. XPT files and dataset records
  stay excluded from LLM paths.

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
