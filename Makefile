# Makefile
.SILENT:

DOCKER_IMAGE=$(shell sed -ne 's/^.*image:[ \t]*//p' compose.yml)
DOCKER_ARCH=-$(subst x86_64,amd64,$(subst aarch64,arm64,$(shell uname -m)))
DOCKER_COMPOSE=$(shell docker compose version > /dev/null 2>&1 && echo docker compose || echo docker-compose)

build:
	-docker pull ${DOCKER_IMAGE} | awk '{ print } /Downloaded newer image/ { system("$(DOCKER_COMPOSE) down"); }'
	$(DOCKER_COMPOSE) ls | grep atomcam_tools > /dev/null || $(DOCKER_COMPOSE) up -d
	$(DOCKER_COMPOSE) exec builder /src/buildscripts/build_all | tee rebuild_`date +"%Y%m%d_%H%M%S"`.log

build-local:
	$(DOCKER_COMPOSE) ls | grep atomcam_tools > /dev/null || $(DOCKER_COMPOSE) up -d
	$(DOCKER_COMPOSE) exec builder /src/buildscripts/build_all | tee rebuild_`date +"%Y%m%d_%H%M%S"`.log

docker-build:
	# build container
	docker build -t ${DOCKER_IMAGE}${DOCKER_ARCH} . | tee docker-build_`date +"%Y%m%d_%H%M%S"`.log

login:
	$(DOCKER_COMPOSE) ls | grep atomcam_tools > /dev/null || $(DOCKER_COMPOSE) up -d
	$(DOCKER_COMPOSE) exec builder bash

lima:
	[ "`uname -s`" = "Darwin" ] || exit 0
	[ -d ~/.lima/lima-docker ] || ( limactl start --tty=false lima-docker.yml && exit 0 )
	[ "`limactl list | awk '/lima-docker/ { print $2 }'`" = "Running" ] || limactl start lima-docker
