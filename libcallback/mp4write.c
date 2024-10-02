#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

struct Mp4StartConfig {
  int fps;
  int width;
  int height;
  int max_stream_size;
  void(*finish_callback)();
};
static int (*original_mp4write_start_handler)(void *handler, char *file, struct Mp4StartConfig *config);
static int mp4write_periodicSD = 0;
static int mp4write_AlarmSD = 0;

extern char CommandResBuf[];
extern int wyze;
extern int VideoControl_UserFps;
extern int VideoControl_AppFps;

static void __attribute ((constructor)) mp4write_init(void) {

  original_mp4write_start_handler = dlsym(dlopen("/system/lib/libmp4rw.so", RTLD_LAZY), "mp4write_start_handler");
}

char *MP4Write(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    snprintf(CommandResBuf, 255, "periodicRec: %s, alarmRec: %s",
      mp4write_periodicSD ? "sd" : "ram",
      mp4write_AlarmSD ? "sd" : "ram");
    return CommandResBuf;
  }

  char *q = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!q) return "error";
  if(!strcasecmp(p, "sd")) {
    mp4write_periodicSD = 1;
  } else if(!strcasecmp(p, "ram")) {
    mp4write_periodicSD = 0;
  } else {
    return "error";
  }

  if(!strcasecmp(q, "sd")) {
    mp4write_AlarmSD = 1;
  } else if(!strcasecmp(q, "ram")) {
    mp4write_AlarmSD = 0;
  } else {
    return "error";
  }
  return "ok";
}

int mp4write_start_handler(void *handler, char *file, struct Mp4StartConfig *config) {

  if((mp4write_AlarmSD && !strncmp(file, "/tmp/alarm_", 11)) ||
     (mp4write_periodicSD && !strncmp(file, "/tmp/", 5) && (strlen(file) == 11))) {
    char buf[64];
    strncpy(buf, file + 5, 30);
    strcpy(file, "/media/mmc/tmp/");
    strcat(file, buf);
  }
  int fps = VideoControl_AppFps;
  if(VideoControl_UserFps) fps = VideoControl_UserFps;
  config->fps = fps;
  return (original_mp4write_start_handler)(handler, file, config);
}

int snprintf(char *str, size_t size, const char *format, ...) {

  va_list args;
  va_start(args, format);

  const char *fmt = format;
  if(wyze && mp4write_AlarmSD && (size == 0xd7) && !strcmp(format, "/tmp/alarm_record_%d.mp4")) {
    fmt = "/media/mmc/tmp/alarm_record_%d.mp4";
  }
  int ret = vsnprintf(str, size, fmt, args);
  va_end(args);
  return ret;
}
