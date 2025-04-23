# Makefile for local development with Act, Docker, and setup for dependencies

# Define environment variables
ACT ?= act
DOCKER_IMAGE ?= khulnasoft/ml-workspace
BUILD_ARGS ?= "--make"
VERSION ?= "v1.0.0"
GITHUB_TOKEN ?= $(shell echo $GITHUB_TOKEN)
DEPENDENCY_INSTALL ?= true  # Flag to control dependency installation

# Default target (help)
help:
	@echo "Makefile for local development with Act and Docker"
	@echo "Available targets:"
	@echo "  build                - Compile, assemble, and package all components"
	@echo "  lint                 - Run linting and code style checks"
	@echo "  test                 - Run unit and integration tests"
	@echo "  check                - Run linting, style checks, and tests"
	@echo "  release              - Release a new version and publish artifacts"
	@echo "  release-local        - Release a new version locally"
	@echo "  setup                - Setup the environment and install dependencies"
	@echo "  install-deps         - Install dependencies within the container"
	@echo "  push-docker          - Push Docker image to the registry"
	@echo "  clean                - Clean up build artifacts"

# Build all components
build: setup
	$(ACT) -b -s BUILD_ARGS="--make" -j build

# Build a specific sub-component (example: docs)
build-subcomponent: setup
	$(ACT) -b -s BUILD_ARGS="--make" -s WORKING_DIRECTORY="./docs" -j build

# Run linting and style checks
lint: setup
	$(ACT) -b -s BUILD_ARGS="--check" -j build

# Run integration and unit tests
test: setup
	$(ACT) -b -s BUILD_ARGS="--test" -j build

# Combine linting, building, and testing in one command
check: setup
	$(ACT) -b -s BUILD_ARGS="--check --make --test" -j build

# Trigger a release process locally using Act
release-local: setup
	$(ACT) -b -s VERSION="$(VERSION)" -s GITHUB_TOKEN="$(GITHUB_TOKEN)" -j release

# Trigger a release pipeline from GitHub Actions (use the version as the argument)
release:
	$(ACT) -b -s VERSION="$(VERSION)" -s GITHUB_TOKEN="$(GITHUB_TOKEN)" -j release

# Clean up any previous builds or release artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build/*

# Ensure the environment is ready by building Docker image
setup:
	@echo "Setting up the environment for Docker and Act..."
	@docker build -t $(DOCKER_IMAGE) .
	@if [ "$(DEPENDENCY_INSTALL)" = "true" ]; then \
		make install-deps; \
	fi

# Install dependencies within the container
install-deps: setup
	@echo "Installing dependencies..."
	@docker run --rm -v $(PWD):/workspace $(DOCKER_IMAGE) make install

# Push Docker image to DockerHub or other registry
push-docker: setup
	@echo "Pushing Docker image to the registry..."
	@docker push $(DOCKER_IMAGE)

# Example clean and release sequence
release-clean: clean
	make release-local
