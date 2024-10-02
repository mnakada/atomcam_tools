#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int local_sdk_close_night_light();
extern int local_sdk_open_night_light();
extern int local_sdk_auto_night_light();
extern void CommandResponse(int fd, const char *res);

char *NightLight(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  if(!strcasecmp(p, "on")) {
    local_sdk_open_night_light();
  } else if(!strcasecmp(p, "off")) {
    local_sdk_close_night_light();
  } else if(!strcasecmp(p, "auto")) {
    local_sdk_auto_night_light();
  } else {
    return "error";
  }
  return "ok";
}
