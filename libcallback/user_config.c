#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <string.h>
#include <unistd.h>

extern char CommandResBuf[];
extern void CommandResponse(int fd, const char *res);

static int (*original_strncmp)(const char *s1, const char *s2, size_t size);
static const int ConfigMax = 256;
static int *configData = NULL;
static int configSize = 0;

int GetUserConfig(const char *key);
int SetUserConfig(const char *key, int value);

static void __attribute ((constructor)) alarmInterval_init(void) {

  original_strncmp = dlsym(dlopen ("/lib/libc.so.0", RTLD_LAZY), "strncmp");
}

int strncmp(const char *s1, const char *s2, size_t size) {

  if(!configData && !strcmp(s1, "indicator")) {
    configData = (unsigned int *)(s1 - 4);
    for(int i = 6; i < 16; i++) {
      if((configData[i] == 2) && ((configData[i + 1] | 0x40404040) == configData[i + 1])) {
        configSize = i;
        configData -= configSize;
        break;
      }
    }
    fprintf(stderr, "confgiData %08x size %d\n", configData, configSize);
  }
  return original_strncmp(s1, s2, size);
}

char *UserConfig(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";

  if(!strcmp(p, "list")) {
    if(configData) {
      for(int i = 1; i < ConfigMax; i++) {
        if(configData[i * configSize + 0] != i) break;
        snprintf(CommandResBuf, 255, "%02x %-24s : %d\n", i, (char *)&configData[i * configSize + 1], configData[i * configSize + configSize - 1]);
        write(fd, CommandResBuf, strlen(CommandResBuf));
      }
    }
    return "ok";
  }

  char *q = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!q) {
    int res = GetUserConfig(p);
    if(res < 0) return "error";
    snprintf(CommandResBuf, 255, "%d", res);
    return CommandResBuf;
  }

  int d = atoi(q);
  if(d <= 0) return "error";
  if(SetUserConfig(p, d) < 0) return "error";
  return "ok";
}

int GetUserConfig(const char *key) {

  if(configData) {
    for(int i = 1; i < ConfigMax; i++) {
      if(configData[i * configSize + 0] != i) break;
      if(!strcmp(key, (char *)&configData[i * configSize + 1])) return configData[i * configSize + configSize - 1];
    }
  }
  return -1;
}

int SetUserConfig(const char *key, int value) {

  if(configData) {
    for(int i = 1; i < ConfigMax; i++) {
      if(configData[i * configSize + 0] != i) break;
      if(!strcmp(key, (char *)&configData[i * configSize + 1])) {
        configData[i * configSize + configSize - 1] = value;
        return 0;
      }
    }
  }
  return -1;
}
