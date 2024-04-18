#!/bin/bash
set -e

cd /atomtools/build/buildroot-2016.02
for i in `ls /src/custompackages/package`
do
  rm -rf package/$i
  cp -pr /src/custompackages/package/$i package/
done

patch -p1 < /src/patches/add_fp_no_fused_madd.patch
patch -p1 < /src/patches/linux_makefile.patch

cp /src/configs/atomcam_defconfig configs/
make atomcam_defconfig
cp .config /src/configs/atomcam_defconfig

# mipsel-gcc for uLibc
CROSS_TOOLS=crosstool-ng-1.26.0
useradd -m cross
mkdir -p /atomtools/build/cross/mips-uclibc
mkdir -p /atomtools/build/cross/src
mkdir -p /atomtools/build/cross/src/work
chown -R cross:cross /atomtools/build/cross
cd /atomtools/build/cross/src
curl http://crosstool-ng.org/download/crosstool-ng/${CROSS_TOOLS}.tar.xz | tar Jxvf -
cd ${CROSS_TOOLS}
./configure --prefix=/atomtools/build/cross/tools
make
make install

cd /atomtools/build/cross/src/work
cp /src/configs/crosstools_config .config
chown cross:cross .config
sudo -u cross /atomtools/build/cross/tools/bin/ct-ng build

cd /atomtools/build/cross/mips-uclibc/mipsel-ingenic-linux-uclibc/sysroot
patch -p1 < /src/patches/linux_uclibc_hevc.patch

# nodejs
NODEVER=v16.20.2
NODEARCH=`uname -m` # x64 or arm64
[ "$NODEARCH" = "aarch64" ] && NODEARCH="arm64"
[ "$NODEARCH" = "x86_64" ] && NODEARCH="x64"
locale-gen --no-purge en_US.UTF-8
export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_ALL="en_US.UTF-8"
cd /usr/local

curl https://nodejs.org/dist/${NODEVER}/node-${NODEVER}-linux-${NODEARCH}.tar.xz | tar Jxvf -
ln -s /usr/local/node-${NODEVER}-linux-${NODEARCH} /usr/local/node

# Start the build process
cd /atomtools/build/buildroot-2016.02
make clean
for i in `make show-targets`
do
  echo `date '+%H:%M:%S'` "=== $i ==="
  make $i > make_$i.log 2>&1 || {
    cat make_$i.log
    echo "XXXX $i XXXX"
    break;
  }
done
