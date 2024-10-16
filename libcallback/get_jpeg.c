#include <stdio.h>
#include <dlfcn.h>
#include <string.h>

static int (*real_local_sdk_video_get_jpeg)(int ch, char *path);
static int skipRecordJpeg = 0;

static void __attribute ((constructor)) get_jpeg_init(void) {

  real_local_sdk_video_get_jpeg = dlsym(dlopen("/system/lib/liblocalsdk.so", RTLD_LAZY), "local_sdk_video_get_jpeg");
}

int local_sdk_video_get_jpeg(int ch, char *path) {

  if(skipRecordJpeg && !strncmp(path, "/media/mmc/record", 16)) {
    printf("skip local_sdk_video_get_jpeg : ch%d %s\n", ch, path);
    return 0;
  }

  int ret = real_local_sdk_video_get_jpeg(ch, path);
  fprintf(stderr, "local_sdk_video_get_jpeg %d %d %s\n", ret, ch, path);
  return ret;
}

char *SkipRecordJpeg(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return skipRecordJpeg ? "on" : "off";

  if(!strcasecmp(p, "on")) {
    skipRecordJpeg = 1;
    return "ok";
  } else if(!strcasecmp(p, "off")) {
    skipRecordJpeg = 0;
    return "ok";
  }
  return "error";
}
