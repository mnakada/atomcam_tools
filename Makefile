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
	[ "`uname -s`" = "Darwin" ] || exit 0
	[ -d ~/.lima/lima-docker ] || ( limactl start --tty=false lima-docker.yml && exit 0 )
	[ "`limactl list | awk '/lima-docker/ { print $2 }'`" = "Running" ] || limactl start lima-docker
