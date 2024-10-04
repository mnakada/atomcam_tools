################################################################################
#
# wsdd
#
################################################################################

WSDD_VERSION = 54b9e5cea3ebdda9b439d0780c891f56d3e5241a
WSDD_SITE = https://github.com/KoynovStas/wsdd.git
WSDD_SITE_METHOD = git
WSDD_INSTALL_STAGING = YES
WSDD_AUTORECONF = YES
WSDD_LICENSE = GPLv2
WSDD_LICENSE_FILES = LICENSE
WSDD_CONF_OPTS = -DWSSE_ON=1

# define WSDD_BUILD_CMDS
	
# endef

$(eval $(cmake-package))
