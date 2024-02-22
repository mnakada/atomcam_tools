################################################################################
#
# dosfstools-init
#
################################################################################

DOSFSTOOLS_INIT_VERSION = 3.0.28
DOSFSTOOLS_INIT_SOURCE = dosfstools-$(DOSFSTOOLS_INIT_VERSION).tar.xz
DOSFSTOOLS_INIT_SITE = https://github.com/dosfstools/dosfstools/releases/download/v$(DOSFSTOOLS_INIT_VERSION)
DOSFSTOOLS_INIT_LICENSE = GPLv3+
DOSFSTOOLS_INIT_LICENSE_FILES = COPYING
DOSFSTOOLS_INIT_INSTALL_TARGET = NO
DOSFSTOOLS_INIT_INSTALL_STAGING = YES

DOSFSTOOLS_INIT_CFLAGS = $(TARGET_CFLAGS) -D_GNU_SOURCE -static
DOSFSTOOLS_INIT_LDFLAGS = -static -s

define DOSFSTOOLS_INIT_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) \
		CFLAGS="$(DOSFSTOOLS_INIT_CFLAGS)" LDFLAGS="$(DOSFSTOOLS_INIT_LDFLAGS)" LDLIBS="$(DOSFSTOOLS_INIT_LDLIBS)" -C $(@D)
endef

define DOSFSTOOLS_INIT_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 755 $(@D)/fsck.fat $(STAGING_DIR)/bin-init/fsck.fat
endef

$(eval $(generic-package))
