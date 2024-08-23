#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <string.h>

extern void Dump(const char *str, void *start, int size);

char *MemoryAccess(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";

  if(!strcmp(p, "read")) {
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    if(!p) return "error";
    unsigned int addr = strtoul(p, NULL, 16);

    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    unsigned int size = 1;
    if(p) size = strtoul(p, NULL, 16);
    Dump("MemoryAccess", (void *)addr, size);
    return "ok";
  }
  if(strcmp(p, "write")) return "error";

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  unsigned int addr = strtoul(p, NULL, 16);

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  unsigned int data = strtoul(p, NULL, 16);

  ((unsigned int *)addr)[0] = data;
  return "ok";
}
