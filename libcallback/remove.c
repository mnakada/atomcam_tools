#include <stdio.h>
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>

static int (*original_remove)(const char *pathname);
static const char *HookPath = "/media/mmc/time_lapse/.setup";
extern char TimeLapsePath[256];

static void __attribute ((constructor)) remove_hook_init(void) {

  original_remove = dlsym(dlopen ("/lib/libc.so.0", RTLD_LAZY), "remove");
}

int remove(const char *pathname) {

  if(!strncmp(pathname, HookPath, strlen(HookPath))) printf("[webhook] time_lapse_finish %s\n", TimeLapsePath); // stdout: for webhook
  if(!strncmp(pathname, "/tmp/alarm_", 11) || !strncmp(pathname, "/media/mmc/tmp/alarm_", 21)) {
    char buf[256];
    snprintf(buf, 255, "/bin/rm %s", pathname);
    return system(buf);
  }
  return original_remove(pathname);
}


