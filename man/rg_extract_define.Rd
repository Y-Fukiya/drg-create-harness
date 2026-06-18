\name{rg_extract_define}
\alias{rg_extract_define}
\title{Extract basic define.xml metadata}
\usage{
rg_extract_define(define_xml, study_id = NULL, data_class = c("auto", "sdtm", "adam", "unknown"))
}
\arguments{
\item{define_xml}{Path to a \code{define.xml} file.}
\item{study_id}{Optional study identifier.}
\item{data_class}{Data class: \code{"auto"}, \code{"sdtm"}, \code{"adam"}, or \code{"unknown"}.}
}
\description{
Extract dataset, variable, codelist, external codelist, method, origin,
limited value-level, and evidence metadata from \code{define.xml}. ValueListDef
and WhereClauseDef support is limited to ItemRef and RangeCheck metadata that
can be represented in the \code{define_valuelevel} table. More complex
value-level rows are marked as needing human review.
}
\value{A list of tibbles: \code{define_datasets}, \code{define_variables},
\code{define_codelists}, \code{define_methods}, \code{define_valuelevel}, and
\code{evidence_table}.}
