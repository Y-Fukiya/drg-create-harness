\name{rg_draft_guide}
\alias{rg_draft_guide}
\title{Draft an ADRG or cSDRG}
\usage{
rg_draft_guide(project_path, guide_type = c("adrg", "csdrg"), mode = c("dry_run", "mock", "ellmer"), sections = NULL, write = TRUE)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{guide_type}{Guide type, \code{"adrg"} or \code{"csdrg"}.}
\item{mode}{Drafting mode. \code{"dry_run"} creates deterministic rule-based
drafts. \code{"mock"} creates deterministic mock LLM drafts from metadata-only
context. \code{"ellmer"} is a guarded future integration point.}
\item{sections}{Optional section ids to draft.}
\item{write}{Whether to write \code{work/drafts/<guide_type>_draft.json}.}
}
\description{
Generate deterministic evidence-bound section drafts from extracted metadata.
\code{"dry_run"} and \code{"mock"} modes do not call an external LLM.
}
\value{A list containing guide metadata and drafted sections.}
