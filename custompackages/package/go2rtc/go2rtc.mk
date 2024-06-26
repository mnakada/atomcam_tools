################################################################################
#
# go2rtc
#
################################################################################

# 2024/07/20 v1.9.4
# GO2RTC_VERSION = a4885c2c3abce58074d04878bba0d72105642a9b
# 2024/05/17 v1.9.2
GO2RTC_VERSION = b2399f3bb35fe4f5642b9d98eca756ab448fc850
GO2RTC_SITE = https://github.com/AlexxIT/go2rtc.git
GO2RTC_SITE_METHOD = git
GO2RTC_LICENSE = MIT
GO2RTC_LICENSE_FILES = LICENSE
GO2RTC_INSTALL_TARGET = YES
GO2RTC_GO = /usr/local/bin/go

GO2RTC_GO_ENV = GOARCH=mipsle GOOS=linux
GO2RTC_LDFLAGS = -s -w
GO2RTC_FILENAME = go2rtc
GO2RTC_INSTALL_STAGING = YES
GO2RTC_INSTALL_TARGET = YES

define GO2RTC_BUILD_CMDS
  cd $(@D); $(GO2RTC_GO_ENV) $(GO2RTC_GO) build -ldflags "$(GO2RTC_LDFLAGS)" -trimpath -o $(GO2RTC_FILENAME) && upx --lzma $(GO2RTC_FILENAME)
endef

define GO2RTC_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/$(GO2RTC_FILENAME) $(TARGET_DIR)/usr/bin/$(GO2RTC_FILENAME)
endef

$(eval $(generic-package))
