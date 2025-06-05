.PHONY: help run deploy test clean

help:
	@echo "Claude Code Infrastructure Management"
	@echo ""
	@echo "Available targets:"
	@echo "  run      - Launch the interactive orchestrator"
	@echo "  deploy   - Run full deployment (requires configured .env)"
	@echo "  test     - Run deployment tests"
	@echo "  clean    - Clean up generated files"
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