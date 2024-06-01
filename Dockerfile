FROM ubuntu:16.04

ENV DEBIAN_FRONTEND noninteractive

RUN \
  apt update && apt upgrade -y && \
  apt install -y \
  build-essential \
  qemu-user-static \
  git \
  autoconf \
  cmake \
  python \
  zip \
  unzip \
  cpio \
  wget \
  vim \
  locales \
  lzop \
  bc \
  nano \
  libncurses5-dev \
  nfs-kernel-server \
  curl \
  python3 \
  python-lzma \
  flex \
  texinfo \
  help2man \
  gawk \
  libtool-bin \
  sudo \
  upx \
  bison

ENV PATH="$PATH:/usr/local/node/bin"

RUN mkdir -p /atomtools/build
WORKDIR "/atomtools/build"
RUN curl -o - https://buildroot.org/downloads/buildroot-2016.02.tar.gz | tar zxvf -

# Change to the buildroot directory
WORKDIR "/atomtools/build/buildroot-2016.02"

# Copy the entire source tree. Expect it to be mounted over when developing.
COPY . /src

RUN /src/buildscripts/setup_buildroot.sh
