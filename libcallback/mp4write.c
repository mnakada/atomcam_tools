#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

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
static char ResBuf[256];

extern int VideoControl_UserFps;
extern int VideoControl_AppFps;

static void __attribute ((constructor)) mp4write_init(void) {

  original_mp4write_start_handler = dlsym(dlopen("/system/lib/libmp4rw.so", RTLD_LAZY), "mp4write_start_handler");
}

char *MP4Write(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    snprintf(ResBuf, 255, "periodicRec: %s, alarmRec: %s",
      mp4write_periodicSD ? "sd" : "ram",
      mp4write_AlarmSD ? "sd" : "ram");
    return ResBuf;
  }

  char *q = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!q) return "error";
  if(!strcmp(p, "sd")) {
    mp4write_periodicSD = 1;
  } else if(!strcmp(p, "ram")) {
    mp4write_periodicSD = 0;
  } else {
    return "error";
  }

  if(!strcmp(q, "sd")) {
    mp4write_AlarmSD = 1;
  } else if(!strcmp(q, "ram")) {
    mp4write_AlarmSD = 0;
  } else {
    return "error";
  }
  return "ok";
}

int mp4write_start_handler(void *handler, char *file, struct Mp4StartConfig *config) {

  if((mp4write_AlarmSD && !strcmp(file, "/tmp/alarm_record.mp4")) ||
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
