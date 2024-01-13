# Linux/MacOS-specific targets
.ONESHELL:

VENV_PATH=$(shell pwd)/.venv
DOCKER_IMG_NAME=foobar_demo
DOCKER_CONTAINER_NAME=foobar_container
PYTHON=python3
PIP=$(VENV_PATH)/bin/pip3
APP=$(VENV_PATH)/bin/python3
PYTEST=$(VENV_PATH)/bin/pytest
ACTIVATE := . $(VENV_PATH)/bin/activate
CONDA=conda

help:
	@echo "Choose a command to run:"
	@echo
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup_directories: ## Create the project directory structure
	mkdir -p data/raw
	mkdir -p data/processed
	mkdir -p data/final
	mkdir -p data/external
	mkdir -p data/interim
	mkdir -p data/static
	mkdir -p notebook/exploratory
	mkdir -p notebook/report
	mkdir -p utils
	mkdir -p config
	mkdir -p logfiles
	mkdir -p model
	mkdir -p src
	mkdir -p tests
	mkdir -p docker

setup_initfiles:
	touch config/config.yaml
	touch src/app.py
	touch notebooks/exploratory/nb_descriptive.ipynb
	touch utils/helpers.py
	touch .gitignore
	touch run_app.sh

.DEFAULT_GOAL := run # if you run make without further specifying anything, then it's going to run the "run" target below.

setup_venv: environment.yml requirements.txt # Set up the virtual environment
	@if [ -z "$$(command -v conda)" ]; then \
		echo "Conda is not available. Falling back to python venv..."; \
		if [ -d "$(VENV_PATH)" ]; then \
			echo "Virtual environment at $(VENV_PATH) already exists. Removing..."; \
			rm -rf $(VENV_PATH); \
		fi; \
		$(PYTHON) -m venv $(VENV_PATH); \
		echo "Activating virtual environment and installing dependencies..."; \
		. $(VENV_PATH)/bin/activate; \
		$(PIP) install -r requirements.txt; \
		echo ""; \
		echo "To activate the virtual environment, copy and run: source $(VENV_PATH)/bin/activate"; \
	else \
		echo "Conda is available."; \
		if [ -d "$(VENV_PATH)" ]; then \
			echo "Conda environment at $(VENV_PATH) already exists. Removing..."; \
			conda env remove --prefix $(VENV_PATH) --yes; \
		fi; \
		echo "Creating conda environment at $(VENV_PATH)..."; \
		conda env create --prefix $(VENV_PATH) -f environment.yml; \
		echo ""; \
		echo "To activate the Conda environment, copy and run: conda activate $(VENV_PATH)"; \
	fi

test: ## Run tests
	@echo "Running tests with pytest..."
	@PYTHONPATH=./src $(PYTEST) -v tests/

docker_build: ## Build the Docker image
	docker build -t $(DOCKER_IMG_NAME) .

docker_run_shell: ## Start a new Docker container, mount the data volume, and enter into a shell
	docker run -it --name $(DOCKER_CONTAINER_NAME) -v $(PWD)/tests:/app/tests -v $(PWD)/data:/app/data $(DOCKER_IMG_NAME) /bin/sh


docker_deploy: ## Deploy the Docker container
	docker run -d --name $(DOCKER_CONTAINER_NAME) -p 8050:8050 -v $(PWD)/data:/app/data $(DOCKER_IMG_NAME)

ci: test docker_build docker_deploy ## Run CI/CD
	@echo "Continuous Integration and Deployment completed."


docker_stop: ## Stop and remove Docker container
	docker stop $(DOCKER_CONTAINER_NAME)
	docker rm $(DOCKER_CONTAINER_NAME)

run: $(VENV_PATH)
	PYTHONPATH=src $(APP) src/app.py

clean: ## Cleanup the development environment
	rm -rf $(VENV_PATH)
	docker rmi $(DOCKER_IMG_NAME)
	rm -rf __pycache__

setup_readme:  ## Create a README.md
	@if [ ! -f README.md ]; then \
		echo "# Project Name\n\
Description of the project.\n\n\
## Installation\n\
- Step 1\n\
- Step 2\n\n\
## Usage\n\
Explain how to use the project here.\n\n\
## Contributing\n\
Explain how to contribute to the project.\n\n\
## License\n\
License information." > README.md; \
		echo "README.md created."; \
	else \
		echo "README.md already exists."; \
	fi

# Make it PHONY
.PHONY: setup_venv test docker_build docker_deploy ci docker_stop clean help setup_readme