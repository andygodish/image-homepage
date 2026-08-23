# ==============================================================================
# Homepage Custom Production Build System
# ==============================================================================

HOMEPAGE_VERSION ?= $(shell sed -n 's/^ARG HOMEPAGE_VERSION="//p' Dockerfile | cut -d'"' -f1 | head -n 1 | tr -d '\n\r ')
VERSION_TAG      ?= $(shell [ -s version.txt ] && VERSION=$$(cat version.txt | tr -d "[:space:]") && echo "v$${VERSION#v}" || echo "latest")

REGISTRY        := ghcr.io/andygodish
IMAGE_NAME      := homepage
FULL_TAG        := $(REGISTRY)/$(IMAGE_NAME):$(VERSION_TAG)
LATEST_TAG      := $(REGISTRY)/$(IMAGE_NAME):latest
REPO_ROOT       := $(shell pwd)

PLATFORMS       ?= linux/amd64,linux/arm64

CONTAINER_NAME  := homepage
HOST_PORT       ?= 3000
VOLUME_NAME     := homepage_config_dir
PUID            ?= 10004
PGID            ?= 10004
HOMEPAGE_ALLOWED_HOSTS ?= localhost:$(HOST_PORT),127.0.0.1:$(HOST_PORT)

.DEFAULT_GOAL := help

.PHONY: verify-env
verify-env:
	@if [ ! -f version.txt ]; then \
		echo "Error: version.txt file missing in repository root."; \
		exit 1; \
	fi

.PHONY: build
build: verify-env
	@echo "Building local architecture image $(IMAGE_NAME):$(VERSION_TAG)..."
	docker build \
		--build-arg HOMEPAGE_VERSION=$(HOMEPAGE_VERSION) \
		-t $(IMAGE_NAME):$(VERSION_TAG) \
		$(REPO_ROOT)
	@echo "Local slice build complete."

.PHONY: build-multiarch
build-multiarch: verify-env
	@echo "Initializing Buildx engine multi-arch compilation & push..."
	@echo "Target Registry: $(REGISTRY)"
	@echo "Platforms targeted: $(PLATFORMS)"
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg HOMEPAGE_VERSION=$(HOMEPAGE_VERSION) \
		-t $(FULL_TAG) \
		-t $(LATEST_TAG) \
		--push \
		$(REPO_ROOT)
	@echo "Multi-arch build successfully pushed to GHCR!"

.PHONY: up
up: stop run

.PHONY: run
run: verify-env
	@echo "Launching Homepage using native Docker named volume: $(VOLUME_NAME)..."
	docker run -d \
		--name $(CONTAINER_NAME) \
		--rm \
		-p 127.0.0.1:$(HOST_PORT):3000 \
		-e PUID=$(PUID) \
		-e PGID=$(PGID) \
		-e HOMEPAGE_ALLOWED_HOSTS=$(HOMEPAGE_ALLOWED_HOSTS) \
		-v $(VOLUME_NAME):/app/config \
		$(IMAGE_NAME):$(VERSION_TAG)
	@echo "Homepage launched on http://127.0.0.1:$(HOST_PORT)."

.PHONY: stop
stop:
	@echo "Checking for existing container named '$(CONTAINER_NAME)'..."
	@if [ $$(docker ps -aq -f name=^/$(CONTAINER_NAME)$$ | wc -l) -gt 0 ]; then \
		echo "Found active container name. Shutting it down..."; \
		docker stop $(CONTAINER_NAME); \
	fi
	@echo "Checking for any other container squatting on port $(HOST_PORT)..."
	@CONFLICTING_CONTAINER=$$(docker ps -q -f publish=$(HOST_PORT) | head -n 1); \
	if [ ! -z "$$CONFLICTING_CONTAINER" ]; then \
		echo "Found conflicting container ID $$CONFLICTING_CONTAINER using port. Shutting it down..."; \
		docker stop $$CONFLICTING_CONTAINER; \
	else \
		echo "Port $(HOST_PORT) is clear."; \
	fi

.PHONY: test
test: verify-env
	@echo "Validating Homepage runtime..."
	docker run --rm \
		-e PUID=$(PUID) \
		-e PGID=$(PGID) \
		-e HOMEPAGE_ALLOWED_HOSTS=$(HOMEPAGE_ALLOWED_HOSTS) \
		--entrypoint node \
		$(IMAGE_NAME):$(VERSION_TAG) \
		--version
	@echo "Internal validation passed."

.PHONY: help
help:
	@echo "Homepage Custom Production Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make build            Build local architecture Homepage image"
	@echo "  make build-multiarch  Build and push multi-platform images via Buildx"
	@echo "  make up               Stop existing Homepage container and launch the local image"
	@echo "  make stop             Stop the local Homepage container"
	@echo "  make test             Query the local container Node runtime"
