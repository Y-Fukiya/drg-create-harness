\name{rg_draft_section_ellmer}
\alias{rg_draft_section_ellmer}
\title{ellmer drafting integration point}
\usage{
rg_draft_section_ellmer(project_path, guide_type, section_id, chat = NULL)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{guide_type}{Guide type.}
\item{section_id}{Section id to draft.}
\item{chat}{Optional future ellmer chat object.}
}
\description{
Guarded integration point for future ellmer-based drafting. The MVP does not
call external providers in tests.
}
\value{Raises a guarded error in the MVP.}
