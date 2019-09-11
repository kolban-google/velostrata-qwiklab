help:
	@echo "apply"
	@echo "clean_state"

apply:
	terraform apply -auto-approve

clean_state:
	rm *tfstate*