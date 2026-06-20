\name{rg_collect_llm_context}
\alias{rg_collect_llm_context}
\title{Collect metadata-only LLM context}
\usage{
rg_collect_llm_context(project_path, guide_type = c("adrg", "csdrg"), section_id, limit = 40)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{guide_type}{Guide type, \code{"adrg"} or \code{"csdrg"}.}
\item{section_id}{Section id to collect context for.}
\item{limit}{Maximum number of context rows to return.}
}
\description{
Collect deterministic context rows from extracted define.xml metadata and
validation findings. Dataset-like files are never read, and context collection
refuses to proceed if the manifest marks dataset-like files as eligible for LLM
use.
}
\value{A tibble of metadata-only context rows.}
