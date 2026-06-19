\name{rg_draft_section_mock}
\alias{rg_draft_section_mock}
\title{Draft one section with the mock LLM provider}
\usage{
rg_draft_section_mock(project_path, guide_type = c("adrg", "csdrg"), section_id)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{guide_type}{Guide type, \code{"adrg"} or \code{"csdrg"}.}
\item{section_id}{Section id to draft.}
}
\description{
Create a deterministic mock LLM section draft from metadata-only context. This
mode is intended for tests and local harness development without external LLM
calls.
}
\value{
A list containing draft text, evidence ids, source context ids, confidence,
review flags, and mock provider metadata.
}
