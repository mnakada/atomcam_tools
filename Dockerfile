FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive

RUN \
  apt update && apt upgrade -y && \
  apt install -y \
  build-essential \
  qemu-user-static \
  git \
  autoconf \
# cmake \
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
  # python-lzma \
  flex \
  texinfo \
  help2man \
  gawk \
  libtool-bin \
  sudo \
  upx \
  bison \
  byacc \
  make \
  m4 \
  openssl \
  libssl-dev \
  zlib1g-dev \
  liblzma-dev \
  rsync \
  python2 \
  python2-dev

RUN \
  apt install -y libcrypto++8

RUN cd $HOME && \
  wget https://github.com/Kitware/CMake/releases/download/v3.30.4/cmake-3.30.4.tar.gz && \
  tar zxvf cmake-3.30.4.tar.gz && \
  cd cmake-3.30.4/ && \
  ./bootstrap && \
  make -j12 && sudo make install -j8
RUN echo 'export PATH=$HOME/cmake-3.30.4/bin/:$PATH' >> ~/.bashrc && \
  . ~/.bashrc

RUN ln -s /usr/bin/python2 /usr/bin/python

ENV PATH="$PATH:/usr/local/node/bin"

RUN mkdir -p /atomtools/build
WORKDIR "/atomtools/build"
RUN curl -o - https://buildroot.org/downloads/buildroot-2016.02.tar.gz | tar zxvf -

# Change to the buildroot directory
WORKDIR "/atomtools/build/buildroot-2016.02"

# Copy the entire source tree. Expect it to be mounted over when developing.
COPY . /src

RUN /src/buildscripts/setup_buildroot.sh
