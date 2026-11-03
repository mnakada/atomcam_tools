################################################################################
#
# onvif_simple_server
#
################################################################################

ONVIF_SIMPLE_SERVER_VERSION = 45dbabf40bcd16e9063dff0a52a31f494a439ec1
ONVIF_SIMPLE_SERVER_SITE = https://github.com/roleoroleo/onvif_simple_server.git
ONVIF_SIMPLE_SERVER_SITE_METHOD = git
ONVIF_SIMPLE_SERVER_LICENSE = GPLv3
ONVIF_SIMPLE_SERVER_LICENSE_FILES = LICENSE
ONVIF_SIMPLE_SERVER_DEPENDENCIES = json-c mbedtls zlib

define ONVIF_SIMPLE_SERVER_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) CC="$(TARGET_CC)" STRIP="$(TARGET_STRIP)" HAVE_MBEDTLS=1 -C $(@D) all
endef

define ONVIF_SIMPLE_SERVER_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/var/www/onvif
	$(INSTALL) -D -m 0755 $(@D)/onvif_simple_server $(TARGET_DIR)/var/www/onvif/onvif_simple_server
	ln -sf onvif_simple_server $(TARGET_DIR)/var/www/onvif/device_service
	ln -sf onvif_simple_server $(TARGET_DIR)/var/www/onvif/events_service
	ln -sf onvif_simple_server $(TARGET_DIR)/var/www/onvif/media_service
	ln -sf onvif_simple_server $(TARGET_DIR)/var/www/onvif/media2_service
	ln -sf onvif_simple_server $(TARGET_DIR)/var/www/onvif/ptz_service
	ln -sf onvif_simple_server $(TARGET_DIR)/var/www/onvif/deviceio_service
	cp -dpfr $(@D)/device_service_files $(TARGET_DIR)/var/www/onvif/
	cp -dpfr $(@D)/deviceio_service_files $(TARGET_DIR)/var/www/onvif/
	cp -dpfr $(@D)/events_service_files $(TARGET_DIR)/var/www/onvif/
	cp -dpfr $(@D)/generic_files $(TARGET_DIR)/var/www/onvif/
	cp -dpfr $(@D)/media_service_files $(TARGET_DIR)/var/www/onvif/
	cp -dpfr $(@D)/media2_service_files $(TARGET_DIR)/var/www/onvif/
	cp -dpfr $(@D)/ptz_service_files $(TARGET_DIR)/var/www/onvif/
	$(INSTALL) -D -m 0755 $(@D)/wsd_simple_server $(TARGET_DIR)/usr/bin/wsd_simple_server
	$(INSTALL) -D -m 0755 $(@D)/onvif_notify_server $(TARGET_DIR)/usr/bin/onvif_notify_server
	$(INSTALL) -d $(TARGET_DIR)/etc/wsd_simple_server
	$(INSTALL) -d $(TARGET_DIR)/etc/onvif_notify_server
	cp -dpfr $(@D)/wsd_files/* $(TARGET_DIR)/etc/wsd_simple_server/
	cp -dpfr $(@D)/notify_files/* $(TARGET_DIR)/etc/onvif_notify_server/
endef

$(eval $(generic-package))
