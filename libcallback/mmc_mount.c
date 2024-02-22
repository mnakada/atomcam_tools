#include <stdio.h>
#include <dlfcn.h>
#include <string.h>

static int (*real_local_sdk_device_open)(int id, char *buf);

static void __attribute ((constructor)) mmc_mount_init(void) {

  real_local_sdk_device_open = dlsym(dlopen("/system/lib/liblocalsdk.so", RTLD_LAZY), "local_sdk_device_open");
}

// disable mmc mount
int local_sdk_device_open(int id, char *buf) {

  if(!id) {
    printf("skip local_sdk_device_open %d\n", id);
    strcpy(buf, "/media/mmc");
    return 0;
  }

  int ret = real_local_sdk_device_open(id, buf);
  fprintf(stderr, "local_sdk_device_open %d %d %s\n", ret, id, buf);
  return ret;
}
