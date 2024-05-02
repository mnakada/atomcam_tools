#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <string.h>

extern char CommandResBuf[];
extern int curl_minimum_alarm_cycle;
extern int SetUserConfig(const char *key, int value);
extern int GetUserConfig(const char *key);
extern int SetAlarmConfigInterval(int interval);

char *AlarmInterval(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    snprintf(CommandResBuf, 255, "%d", GetUserConfig("alarmInterval"));
    return CommandResBuf;
  }

  int interval = atoi(p);
  if((interval < 30) || (interval > 300)) return "error";
  int ret = SetUserConfig("alarmInterval", interval);
  if(ret < 0) return "error";
  SetAlarmConfigInterval(interval);
  curl_minimum_alarm_cycle = (interval < 300) ? 300 : 0;
  return "ok";
}
