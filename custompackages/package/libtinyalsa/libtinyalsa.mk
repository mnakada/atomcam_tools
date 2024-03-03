################################################################################
#
# libtinyalsa
#
################################################################################

LIBTINYALSA_VERSION = 1c5fb68ced57d838f2b7ecd0c00bc1fefc9ab60d
LIBTINYALSA_SITE = https://github.com/tinyalsa/tinyalsa.git
LIBTINYALSA_SITE_METHOD = git
LIBTINYALSA_LICENSE_FILES = COPYING

LIBTINYALSA_CROSS_BASE = /atomtools/build/cross/mips-uclibc
LIBTINYALSA_CROSS_COMPILE = ${LIBTINYALSA_CROSS_BASE}/bin/mipsel-ingenic-linux-uclibc-
LIBTINYALSA_DESTDIR = ${LIBTINYALSA_CROSS_BASE}//mipsel-ingenic-linux-uclibc/sysroot
LIBTINYALSA_PREFIX = /usr
LIBTINYALSA_CFLAGS = -std=gnu99 -msoft-float
LIBTINYALSA_LDFLAGS = -std=gnu99 -msoft-float

define LIBTINYALSA_BUILD_CMDS
	$(MAKE) install CFLAGS="${LIBTINYALSA_CFLAGS}" LDFLAGS="${LIBTINYALSA_LDFLAGS}" CROSS_COMPILE="${LIBTINYALSA_CROSS_COMPILE}" PREFIX="${LIBTINYALSA_PREFIX}" DESTDIR="${LIBTINYALSA_DESTDIR}" -C $(@D)
endef

define LIBTINYALSA_INSTALL_TARGET_CMDS
	cp -dpf ${LIBTINYALSA_DESTDIR}/usr/lib/libtinyalsa.so.* ${TARGET_DIR}/lib/modules
endef

$(eval $(generic-package))

