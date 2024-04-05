# Makefile
.SILENT:

DOCKER_IMAGE=$(shell sed -ne 's/^.*image:[ \t]*//p' docker-compose.yml)
DOCKER_ARCH=-$(subst x86_64,amd64,$(subst aarch64,arm64,$(shell uname -m)))

build:
	-docker pull ${DOCKER_IMAGE} | awk '{ print } /Downloaded newer image/ { system("docker-compose down"); }'
	docker-compose ls | grep atomcam_tools > /dev/null || docker-compose up -d
	docker-compose exec builder /src/buildscripts/build_all | tee rebuild_`date +"%Y%m%d_%H%M%S"`.log

build-local:
	docker-compose ls | grep atomcam_tools > /dev/null || docker-compose up -d
	docker-compose exec builder /src/buildscripts/build_all | tee rebuild_`date +"%Y%m%d_%H%M%S"`.log

docker-build:
	# build container
	docker build -t ${DOCKER_IMAGE}${DOCKER_ARCH} . | tee docker-build_`date +"%Y%m%d_%H%M%S"`.log

login:
	docker-compose ls | grep atomcam_tools > /dev/null || docker-compose up -d
	docker-compose exec builder bash

lima:
	[ `uname -s` = "Darwin" -a -d ~/.lima/lima-docker ] && limactl start lima-docker && exit 0
	[ `uname -s` = "Darwin" -a ! -d ~/.lima/lima-docker ] && limactl start lima-docker.yml && exit 0
