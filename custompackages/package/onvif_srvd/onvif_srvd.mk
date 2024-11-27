################################################################################
#
# onvif_srvd
#
################################################################################

ONVIF_SRVD_VERSION = 2cf9008a3afeaa0f0aff11be85cc4e6c7684f90c
ONVIF_SRVD_SITE = https://github.com/KoynovStas/onvif_srvd.git
ONVIF_SRVD_SITE_METHOD = git
ONVIF_SRVD_INSTALL_STAGING = YES
ONVIF_SRVD_AUTORECONF = YES
ONVIF_SRVD_LICENSE = GPLv2
ONVIF_SRVD_LICENSE_FILES = LICENSE

# define ONVIF_SRVD_BUILD_CMDS

# endef

$(eval $(cmake-package))