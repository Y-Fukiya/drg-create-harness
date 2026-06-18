\name{rg_retrieve_context}
\alias{rg_retrieve_context}
\title{Retrieve RAG context}
\usage{
rg_retrieve_context(project_path, query, filters = list(), backend = c("none", "mock", "ragnar", "graph", "hybrid"), top_k = 8)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{query}{Retrieval query.}
\item{filters}{Reserved filter list.}
\item{backend}{Retrieval backend.}
\item{top_k}{Maximum contexts to return.}
}
\description{
Retrieve context from no-op or mock backends in the MVP. Future ragnar, graph,
and hybrid backends are guarded.
}
\value{A context tibble or guarded error.}
