#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <string.h>

extern char CommandResBuf[];

static int (*original_strncmp)(const char *s1, const char *s2, size_t size);

struct configDataSt {
  int id;
  char key[16];
  int initialValue;
  int value;
};
static struct configDataSt *configData = NULL;
int GetUserConfig(const char *key);
int SetUserConfig(const char *key, int value);

static void __attribute ((constructor)) alarmInterval_init(void) {

  original_strncmp = dlsym(dlopen ("/lib/libc.so.0", RTLD_LAZY), "strncmp");
}

int strncmp(const char *s1, const char *s2, size_t size) {

  if(!configData && !strcmp(s1, "indicator")) configData = (struct configDataSt *)(s1 - 4) - 1;
  return original_strncmp(s1, s2, size);
}

char *UserConfig(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";

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

  if(!configData) return -1;
  for(int i = 1; i < 0x4d; i++) {
    if(configData[i].id != i) break;
    if(!strcmp(key, configData[i].key)) return configData[i].value;
  }
  return -1;
}

int SetUserConfig(const char *key, int value) {

  if(!configData) return -1;
  for(int i = 1; i < 0x4d; i++) {
    if(configData[i].id != i) break;
    if(!strcmp(key, configData[i].key)) {
      configData[i].value = value;
      return 0;
    }
  }
  return -1;
}
