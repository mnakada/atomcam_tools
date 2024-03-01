################################################################################
#
# logconv
#
################################################################################

LOGCONV_VERSION = v0.1.0
LOGCONV_SITE = /src/custompackages/package/logconv
LOGCONV_DEPENDENCIES =
LOGCONV_CONF_OPTS =
LOGCONV_SITE_METHOD = local

define LOGCONV_BUILD_CMDS
        $(MAKE) -C $(@D)/src TARGET_CROSS="$(TARGET_CROSS)" all
endef

define LOGCONV_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/src/logconv $(TARGET_DIR)/usr/bin
endef

$(eval $(generic-package))
