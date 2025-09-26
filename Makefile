# Makefile
.SILENT:

DOCKER_IMAGE=$(shell sed -ne 's>^.*image:[ \t]*>>p' docker-compose.yml)
DOCKER_ARCH=-$(shell uname -m | sed 's>x86_64>amd64>g; s>aarch64>arm64>g')

define check_container_running
	$(DOCKER_COMPOSE) ls | grep atomcam_tools > /dev/null
endef

DOCKER_COMPOSE=$(shell \
	if command -v docker-compose >/dev/null 2>&1; then \
		echo "docker-compose"; \
	elif docker compose version >/dev/null 2>&1; then \
		echo "docker compose"; \
	else \
		echo "docker compose"; \
	fi)


build:
	-docker pull ${DOCKER_IMAGE} | \
		awk '{ print } /Downloaded newer image/ { system("$(DOCKER_COMPOSE) down"); }'
	
	$(call check_container_running) || $(DOCKER_COMPOSE) up -d
	
	$(DOCKER_COMPOSE) exec builder /src/buildscripts/build_all | \
		tee rebuild_`date +"%Y%m%d_%H%M%S"`.log

build-local:
	$(call check_container_running) || $(DOCKER_COMPOSE) up -d
	
	$(DOCKER_COMPOSE) exec builder /src/buildscripts/build_all | \
		tee rebuild_`date +"%Y%m%d_%H%M%S"`.log

docker-build:
	docker build -t ${DOCKER_IMAGE}${DOCKER_ARCH} . | \
		tee docker-build_`date +"%Y%m%d_%H%M%S"`.log

login:
	$(call check_container_running) || $(DOCKER_COMPOSE) up -d
	$(DOCKER_COMPOSE) exec builder bash

lima:
	[ "`uname -s`" = "Darwin" ] || exit 0
	
	[ -d ~/.lima/lima-docker ] || \
		( limactl start --tty=false lima-docker.yml && exit 0 )
	
	[ "`limactl list | awk '/lima-docker/ { print $2 }'`" = "Running" ] || \
		limactl start lima-docker

clean:
	$(call check_container_running) && \
		$(DOCKER_COMPOSE) exec builder bash -c "cd /atomtools/build/buildroot-2016.02 && make clean"

distclean:
	$(DOCKER_COMPOSE) down --volumes --remove-orphans
	docker image rm ${DOCKER_IMAGE}${DOCKER_ARCH} 2>/dev/null || :