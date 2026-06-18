PROJECT ?= /private/tmp/reviewerguideR-harness
STUDY_ID ?= STUDY-001
GUIDE ?= both
MODE ?= dry_run
QC_LEVEL ?= basic
EXAMPLE ?= anonymous
RSCRIPT ?= Rscript

.PHONY: help init run run-example test check

help:
	@echo "Harness commands:"
	@echo "  make init PROJECT=studies/ABC-001 STUDY_ID=ABC-001"
	@echo "  make run PROJECT=studies/ABC-001 GUIDE=both"
	@echo "  make run-example PROJECT=/private/tmp/rg-demo EXAMPLE=anonymous"
	@echo "  make test"
	@echo "  make check"

init:
	$(RSCRIPT) scripts/run_harness.R \
		--project "$(PROJECT)" \
		--study-id "$(STUDY_ID)" \
		--guide "$(GUIDE)" \
		--init \
		--no-run

run:
	$(RSCRIPT) scripts/run_harness.R \
		--project "$(PROJECT)" \
		--study-id "$(STUDY_ID)" \
		--guide "$(GUIDE)" \
		--mode "$(MODE)" \
		--qc-level "$(QC_LEVEL)"

run-example:
	$(RSCRIPT) scripts/run_harness.R \
		--project "$(PROJECT)" \
		--study-id "$(STUDY_ID)" \
		--guide "$(GUIDE)" \
		--mode "$(MODE)" \
		--qc-level "$(QC_LEVEL)" \
		--copy-example "$(EXAMPLE)"

test:
	$(RSCRIPT) -e 'testthat::test_local(reporter = "summary")'

check:
	R CMD build .
	R CMD check --no-manual --no-build-vignettes reviewerguideR_*.tar.gz
