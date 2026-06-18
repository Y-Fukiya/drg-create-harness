\name{reviewerguideR-package}
\alias{reviewerguideR-package}
\alias{rg_init_project}
\alias{rg_scan_sources}
\alias{rg_extract_define}
\alias{rg_extract_validation}
\alias{rg_extract_metadata}
\alias{rg_draft_guide}
\alias{rg_draft_section_ellmer}
\alias{rg_build_rag_index}
\alias{rg_retrieve_context}
\alias{rg_qc}
\alias{rg_render_docx}
\alias{rg_init_integrated_project}
\alias{rg_draft_integrated_guide}
\alias{rg_build_kg}
\alias{rg_query_kg}
\title{ADRG and cSDRG Draft Creation Harness}
\description{
Create basic ADRG and cSDRG draft reviewer guides from structured metadata.
The MVP supports deterministic dry-run drafting, evidence tables, QC reports,
and DOCX output. External LLM, RAG, GraphRAG, and integrated guide features are
provided only as guarded extension points or stubs.
}
\usage{
rg_init_project(path, study_id, guide_types = c("adrg", "csdrg"), overwrite = FALSE)
rg_scan_sources(project_path, write = TRUE)
rg_extract_define(define_xml, study_id = NULL, data_class = c("auto", "sdtm", "adam", "unknown"))
rg_extract_validation(path, study_id = NULL, data_class = c("auto", "sdtm", "adam", "unknown"))
rg_extract_metadata(project_path, write = TRUE)
rg_draft_guide(project_path, guide_type = c("adrg", "csdrg"), mode = c("dry_run", "ellmer"), sections = NULL, write = TRUE)
rg_draft_section_ellmer(project_path, guide_type, section_id, chat = NULL)
rg_build_rag_index(project_path, backend = c("none", "ragnar"))
rg_retrieve_context(project_path, query, filters = list(), backend = c("none", "mock", "ragnar", "graph", "hybrid"), top_k = 8)
rg_qc(project_path, guide_type = c("adrg", "csdrg"), level = c("basic", "strict"), write = TRUE)
rg_render_docx(project_path, guide_type = c("adrg", "csdrg"), template = NULL, output = NULL)
rg_init_integrated_project(...)
rg_draft_integrated_guide(...)
rg_build_kg(...)
rg_query_kg(...)
}
\arguments{
\item{path, project_path}{Project directory path.}
\item{study_id}{Study identifier.}
\item{guide_types, guide_type}{Guide type, either \code{"adrg"} or \code{"csdrg"}.}
\item{overwrite}{Whether to overwrite an existing config file.}
\item{write}{Whether to write generated artifacts to disk.}
\item{define_xml}{Path to a define.xml file.}
\item{data_class}{Data class: \code{"auto"}, \code{"sdtm"}, \code{"adam"}, or \code{"unknown"}.}
\item{mode}{Drafting mode. The MVP fully implements \code{"dry_run"}.}
\item{sections}{Optional section ids to draft.}
\item{section_id}{A single section id for future ellmer drafting integration.}
\item{chat}{Optional ellmer chat object for future integration.}
\item{backend}{RAG retrieval backend.}
\item{query}{Retrieval query.}
\item{filters}{Retrieval filters reserved for future use.}
\item{top_k}{Maximum number of contexts to return.}
\item{level}{QC level.}
\item{template}{Optional DOCX template path.}
\item{output}{Optional DOCX output path.}
\item{...}{Reserved arguments for future stubbed features.}
}
\value{
Functions return paths, tibbles, lists, or invisible output paths depending on
the operation. Stub functions raise clear not-implemented errors.
}
