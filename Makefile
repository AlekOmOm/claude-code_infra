.PHONY: help run deploy test clean gcp-status gcp-connect gcp-costs

help:
	@echo "Claude Code Infrastructure Management"
	@echo ""
	@echo "Available targets:"
	@echo "  run         - Launch the interactive orchestrator"
	@echo "  deploy      - Run full deployment (requires configured .env)"
	@echo "  test        - Run deployment tests"
	@echo "  clean       - Clean up generated files"
	@echo ""
	@echo "GCP Management:"
	@echo "  gcp-status  - Check GCP instance status"
	@echo "  gcp-connect - Connect to GCP instance"
	@echo "  gcp-costs   - Show GCP cost estimates"
	@echo "  gcp-start   - Start GCP instance"
	@echo "  gcp-stop    - Stop GCP instance"
	@echo ""
	@echo "Quick start: make run"

run:
	@./run.sh

deploy:
	@./scripts/phases/4_execute_deployment_template.sh

test:
	@./tests/test_deployment.sh

clean:
	@rm -f DEPLOYMENT_SUMMARY.md
	@rm -f terraform.tfstate*
	@echo "Cleaned up deployment artifacts"

# GCP Management shortcuts
gcp-status:
	@./scripts/management/gcp_management.sh status

gcp-connect:
	@./scripts/management/gcp_management.sh connect

gcp-costs:
	@./scripts/management/gcp_management.sh costs

gcp-start:
	@./scripts/management/gcp_management.sh start

gcp-stop:
	@./scripts/management/gcp_management.sh stop

gcp-health:
	@./scripts/management/gcp_management.sh health

gcp-list:
	@./scripts/management/gcp_management.sh list