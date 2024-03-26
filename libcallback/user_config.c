#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <string.h>
#include <unistd.h>

extern char CommandResBuf[];
extern void CommandResponse(int fd, const char *res);
extern int wyze;

static int (*original_strncmp)(const char *s1, const char *s2, size_t size);
static const int ConfigMax = 256;

struct configDataSt {
  int id;
  char key[16];
  int initialValue;
  int value;
};
static struct configDataSt *configData = NULL;

struct configDataWyzeSt {
  int id;
  char key[24];
  int initialValue;
  int lastValue;
  int value;
};
static struct configDataWyzeSt *configDataWyze = NULL;

int GetUserConfig(const char *key);
int SetUserConfig(const char *key, int value);

static void __attribute ((constructor)) alarmInterval_init(void) {

  original_strncmp = dlsym(dlopen ("/lib/libc.so.0", RTLD_LAZY), "strncmp");
}

int strncmp(const char *s1, const char *s2, size_t size) {

  if(!configData && !configDataWyze && !strcmp(s1, "indicator")) {
    if(wyze) {
      configDataWyze = (struct configDataWyzeSt *)(s1 - 4) - 1;
      fprintf(stderr, "configDataWyze %08x\n", configDataWyze);
    } else {
      configData = (struct configDataSt *)(s1 - 4) - 1;
      fprintf(stderr, "configData %08x\n", configData);
    }
  }
  return original_strncmp(s1, s2, size);
}

char *UserConfig(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";

  if(!strcmp(p, "list")) {
    if(configData) {
      for(int i = 1; i < ConfigMax; i++) {
        if(configData[i].id != i) break;
        snprintf(CommandResBuf, 255, "%02x %-16s : %d\n", i, configData[i].key, configData[i].value);
        write(fd, CommandResBuf, strlen(CommandResBuf));
      }
    } else if(configDataWyze) {
      for(int i = 1; i < ConfigMax; i++) {
        if(configDataWyze[i].id != i) break;
        snprintf(CommandResBuf, 255, "%02x %-24s : %d\n", i, configDataWyze[i].key, configDataWyze[i].value);
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
      if(configData[i].id != i) break;
      if(!strcmp(key, configData[i].key)) return configData[i].value;
    }
  } else if(configDataWyze) {
    for(int i = 1; i < ConfigMax; i++) {
      if(configDataWyze[i].id != i) break;
      if(!strcmp(key, configDataWyze[i].key)) return configDataWyze[i].value;
    }
  }
  return -1;
}

int SetUserConfig(const char *key, int value) {

  if(configData) {
    for(int i = 1; i < ConfigMax; i++) {
      if(configData[i].id != i) break;
      if(!strcmp(key, configData[i].key)) {
        configData[i].value = value;
        return 0;
      }
    }
  } else if(configDataWyze) {
    for(int i = 1; i < ConfigMax; i++) {
      if(configDataWyze[i].id != i) break;
      if(!strcmp(key, configDataWyze[i].key)) {
        configDataWyze[i].value = value;
        return 0;
      }
    }
  }
  return -1;
}
