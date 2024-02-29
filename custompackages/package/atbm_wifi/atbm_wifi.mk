################################################################################
#
# atbm_wifi
#
################################################################################

ATBM_WIFI_VERSION = 5243746967626551d29dd17ebdc7c1e4659bfb17
ATBM_WIFI_SITE = https://github.com/OpenIPC/atbm_60xx.git
ATBM_WIFI_SITE_METHOD = git
ATBM_WIFI_LICENSE = GPLv2
ATBM_WIFI_LICENSE_FILES = COPYING

$(eval $(kernel-module))

define ATBM_WIFI_KERNEL_MODULES_INSTALL
	cp $(@D)/hal_apollo/*.ko $(TARGET_DIR)/lib/modules
endef

$(eval $(generic-package))

