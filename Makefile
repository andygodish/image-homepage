# ==============================================================================
# Homepage Custom Production Build System
# ==============================================================================

HOMEPAGE_VERSION ?= $(shell sed -n 's/^ARG HOMEPAGE_VERSION="//p' Dockerfile | cut -d'"' -f1 | head -n 1 | tr -d '\n\r ')
VERSION_TAG      ?= $(shell [ -s version.txt ] && printf 'v%s\n' $$(cat version.txt | tr -d '[:space:]' | sed 's/^v*//') || echo 'latest')

REGISTRY        := ghcr.io/andygodish
IMAGE_NAME      := homepage
FULL_TAG        := $(REGISTRY)/$(IMAGE_NAME):$(VERSION_TAG)
LATEST_TAG      := $(REGISTRY)/$(IMAGE_NAME):latest
REPO_ROOT       := $(shell pwd)

PLATFORMS       ?= linux/amd64,linux/arm64

COMPOSE_FILE    := $(shell test -f docker-compose.yaml && echo docker-compose.yaml || echo docker-compose.yml)
CONTAINER_NAME  := homepage
HOST_PORT       ?= 3000
VOLUME_NAME     := image-homepage_homepage_config_dir
PUID            ?= 10004
PGID            ?= 10004
HOMEPAGE_ALLOWED_HOSTS ?= localhost:$(HOST_PORT),127.0.0.1:$(HOST_PORT)

.DEFAULT_GOAL := help

.PHONY: verify-env build build-multiarch up run stop down restart logs status ps verify-ports fix-permissions test help

verify-env:
	@if [ ! -f version.txt ]; then \
		echo "Error: version.txt file missing in repository root."; \
		exit 1; \
	fi

build: verify-env
	@echo "Building local architecture image $(IMAGE_NAME):$(VERSION_TAG)..."
	docker build \
		--build-arg HOMEPAGE_VERSION=$(HOMEPAGE_VERSION) \
		-t $(IMAGE_NAME):$(VERSION_TAG) \
		-t $(FULL_TAG) \
		$(REPO_ROOT)
	@echo "Local slice build complete."

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

up: verify-ports fix-permissions
	@echo "Running standalone Homepage stack..."
	docker compose -f $(COMPOSE_FILE) up -d --remove-orphans
	@echo "Homepage is running at http://127.0.0.1:$(HOST_PORT). Run 'make status' to verify health."

run: up

stop down:
	@echo "Safely bringing down Homepage stack..."
	docker compose -f $(COMPOSE_FILE) down

restart:
	@echo "Gracefully restarting Homepage stack..."
	docker compose -f $(COMPOSE_FILE) restart

logs:
	docker compose -f $(COMPOSE_FILE) logs -f --tail=100

status ps:
	docker compose -f $(COMPOSE_FILE) ps

verify-ports:
	@echo "Running preflight network checks..."
	@if lsof -Pi :$(HOST_PORT) -sTCP:LISTEN -t >/dev/null 2>&1; then \
		echo "ERROR: Port $(HOST_PORT) is already occupied on the host system."; \
		echo "Please stop the conflicting service before running Homepage."; \
		exit 1; \
	fi
	@echo "Target network port $(HOST_PORT) is clear."

fix-permissions:
	@echo "Checking and setting volume directory ownership for non-root Homepage..."
	@docker volume create $(VOLUME_NAME) >/dev/null 2>&1 || true
	@docker run --rm -v $(VOLUME_NAME):/data alpine sh -c "chown -R $(PUID):$(PGID) /data && chmod 755 /data" >/dev/null 2>&1 || true

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

help:
	@echo "Homepage Custom Production Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make build            Build local architecture Homepage image"
	@echo "  make build-multiarch  Build and push multi-platform images via Buildx"
	@echo "  make up               Run the standalone Homepage compose stack"
	@echo "  make down             Safely stop and remove containers (keeps volumes intact)"
	@echo "  make restart          Gracefully restart the Homepage service"
	@echo "  make logs             Stream live Homepage logs"
	@echo "  make status           View operational health and port bindings"
	@echo "  make test             Query the local container Node runtime"
