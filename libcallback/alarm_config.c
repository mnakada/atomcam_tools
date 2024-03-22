#include <stdio.h>
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>
#include <pthread.h>

extern void Dump(const char *str, void *start, int size);
extern char CommandResBuf[];

static void *(*original_memset)(void *s, int c, size_t n);

struct AlarmConfigSt {
  int unknown_000;          // 0x0000
  int alarmType;            // 0x0004
  char aws_id[0x20];        // 0x0028
  time_t lastRecTime;       // 0x0028
  int alarmInteval;         // 0x002c
  int TBStart;              // 0x0030
  int TBDuration;           // 0x0034
  int alrmDate;             // 0x0038
  char pad_003c[0x6a4];
  char mp4RecordFile[256];  // 0x06e0
  char jpegFile[256];       // 0x07e0
  char historyMp4File[257]; // 0x08e0
  char historyJpegFile[256];// 0x09e1
  char aiDetPic3Url[256];   // 0x0ae1
  char awsRegion[0x100];    // 0x0be1
  char aiDetPic2Url[256];   // 0x0ce1
  char pad_de1[0x123];
  int unknown_f04;          // 0x0f04  16000 audioSampleRate ?
  int unknown_f08;          // 0x0f08  16    audioBitWidth ?
  int unknown_f0c;          // 0x0f0c  1
  int unknown_f10;          // 0x0f10  2
  int unknown_f14;          // 0x0f14  25  fps?
  int unknown_f18;          // 0x0f18  640 sub width?
  char pad_f1c[0x510];
  pthread_mutex_t mutex;    // 0x142c sizeof(pthread_mutex_t) = 0x18
};
static struct AlarmConfigSt *alarmConfig = NULL; // alarmConfig[14]
static int wyze = 0;

static void __attribute ((constructor)) memset_hook_init(void) {

  char *p = getenv("PRODUCT_MODEL");
  if(!strcmp(p, "WYZE_CAKP2JFUS")) wyze = 1;
}

void *memset(void *s, int c, size_t n) {

  if(wyze && !c && (n == 0x1444)) {
    unsigned int s1 = 0;
    asm volatile(
      "ori %0, $17, 0\n"
      : "=r"(s1)
    );
    if(!s1) alarmConfig = s;
  }
  // memset is called before the execution of constructor.
  if(!original_memset) original_memset = dlsym(dlopen ("/lib/libc.so.0", RTLD_LAZY), "memset");
  return original_memset(s, c, n);
}

char *AlarmConfig(int fd, char *tokenPtr) {

  if(!wyze) return "error";
  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  int alarmType = atoi(p);
  if((alarmType < 0) || (alarmType > 14)) return "error";

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!strcmp(p, "alarmInterval")) {
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    if(!p) {
      snprintf(CommandResBuf, 255, "%d ", alarmConfig[alarmType].alarmInteval);
      strftime(CommandResBuf + strlen(CommandResBuf), 255 - strlen(CommandResBuf), "%Y/%m/%d %T", localtime(&alarmConfig[alarmType].lastRecTime));
      return CommandResBuf;
    }
    int interval = atoi(p);
    if((interval < 30) || (interval > 300)) return "error";
    pthread_mutex_lock(&alarmConfig[alarmType].mutex);
    alarmConfig[alarmType].alarmInteval = interval;
    pthread_mutex_unlock(&alarmConfig[alarmType].mutex);
    return "ok";
  }

  if(!strcmp(p, "dump")) {
    fprintf(stderr, "AlarmConfig %d : %08x\n",alarmType, alarmConfig + alarmType);
    Dump("AlarmConfig", alarmConfig + alarmType, sizeof(struct AlarmConfigSt));
    return "ok";
  }
  return "error";
}
