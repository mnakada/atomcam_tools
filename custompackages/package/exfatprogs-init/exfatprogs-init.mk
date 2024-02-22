################################################################################
#
# exfatprogs
#
################################################################################

EXFATPROGS_INIT_VERSION = 1.2.2
EXFATPROGS_INIT_SOURCE = exfatprogs-$(EXFATPROGS_INIT_VERSION).tar.xz
EXFATPROGS_INIT_SITE = https://github.com/exfatprogs/exfatprogs/releases/download/$(EXFATPROGS_INIT_VERSION)
EXFATPROGS_INIT_LICENSE = GPL-2.0+
EXFATPROGS_INIT_LICENSE_FILES = COPYING
EXFATPROGS_INIT_CPE_ID_VENDOR = namjaejeon
EXFATPROGS_INIT_INSTALL_STAGING = YES
EXFATPROGS_INIT_INSTALL_TARGET = NO

EXFATPROGS_INIT_CONF_OPTS = --with-sysroot=$(STAGING) --bindir=/bin-init --sbindir=/bin-init
EXFATPROGS_INIT_CONF_ENV = CFLAGS=-static LDFLAGS=-s

$(eval $(autotools-package))

