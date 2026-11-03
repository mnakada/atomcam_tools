# Makefile
.SILENT:

BUILDER_IMAGE=$(shell sed -ne 's/^.*image:[ \t]*//p' docker-compose.yml)
DOCKER_ARCH=-$(subst x86_64,amd64,$(subst aarch64,arm64,$(shell uname -m)))

ifeq ($(shell uname -s),Darwin)
CONTAINER_CLI ?= container
CONTAINER_NAME=atomcam_tools-builder

.PHONY: build build-local container-up container-build docker-build test-device login _container-system-start _container-ensure

build: _container-system-start
	$(CONTAINER_CLI) image pull $(BUILDER_IMAGE)
	$(MAKE) --no-print-directory _container-ensure
	$(CONTAINER_CLI) exec $(CONTAINER_NAME) /src/buildscripts/build_all | tee rebuild_`date +"%Y%m%d_%H%M%S"`.log

build-local: container-up
	$(CONTAINER_CLI) exec $(CONTAINER_NAME) /src/buildscripts/build_all | tee rebuild_`date +"%Y%m%d_%H%M%S"`.log

container-up: _container-system-start
	$(MAKE) --no-print-directory _container-ensure

_container-system-start:
	@if status=$$($(CONTAINER_CLI) system status --format json); then \
		printf '%s\n' "$$status" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"running"' && exit 0; \
	fi; \
	$(CONTAINER_CLI) system start

_container-ensure:
	@set -e; \
	running=$$($(CONTAINER_CLI) list --quiet); \
	if printf '%s\n' "$$running" | grep -Fxq "$(CONTAINER_NAME)"; then \
		:; \
	else \
		all=$$($(CONTAINER_CLI) list --all --quiet); \
		if printf '%s\n' "$$all" | grep -Fxq "$(CONTAINER_NAME)"; then \
			$(CONTAINER_CLI) start $(CONTAINER_NAME); \
		else \
			$(CONTAINER_CLI) run --detach --name $(CONTAINER_NAME) --cap-add ALL \
				--mount "type=bind,source=$(CURDIR),target=/src" \
				$(BUILDER_IMAGE) tail -f /dev/null; \
		fi; \
	fi

container-build: _container-system-start
	$(CONTAINER_CLI) build -t $(BUILDER_IMAGE)$(DOCKER_ARCH) . | tee container-build_`date +"%Y%m%d_%H%M%S"`.log

docker-build: container-build

test-device:
	tests/device/run.sh $(ARGS)

login: container-up
	$(CONTAINER_CLI) exec --interactive --tty $(CONTAINER_NAME) bash
else
# Use Docker Compose v2 when available, otherwise fall back to docker-compose v1.
DOCKER_COMPOSE=$(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

.PHONY: build build-local container-build docker-build test-device login

build:
	-docker pull ${BUILDER_IMAGE} | awk '{ print } /Downloaded newer image/ { system("${DOCKER_COMPOSE} down"); }'
	${DOCKER_COMPOSE} ls | grep atomcam_tools > /dev/null || ${DOCKER_COMPOSE} up -d
	${DOCKER_COMPOSE} exec builder /src/buildscripts/build_all | tee rebuild_`date +"%Y%m%d_%H%M%S"`.log

build-local:
	${DOCKER_COMPOSE} ls | grep atomcam_tools > /dev/null || ${DOCKER_COMPOSE} up -d
	${DOCKER_COMPOSE} exec builder /src/buildscripts/build_all | tee rebuild_`date +"%Y%m%d_%H%M%S"`.log

docker-build:
	docker build -t ${BUILDER_IMAGE}${DOCKER_ARCH} . | tee docker-build_`date +"%Y%m%d_%H%M%S"`.log

container-build: docker-build

test-device:
	tests/device/run.sh $(ARGS)

login:
	${DOCKER_COMPOSE} ls | grep atomcam_tools > /dev/null || ${DOCKER_COMPOSE} up -d
	${DOCKER_COMPOSE} exec builder bash
endif
