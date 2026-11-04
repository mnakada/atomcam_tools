#include <stdio.h>
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>
#include <pthread.h>

extern void Dump(const char *str, void *start, int size);
extern char CommandResBuf[];

int SetAlarmConfigInterval(int interval);
static void *(*original_memset)(void *s, int c, size_t n);


// The entry size depends on the firmware: 0x0bc4, or 0x0bc8 on ATOMCam2 4.58.0.180 and ATOMSwing 4.37.1.182.
// The fields below up to alarmInterval are at the same offsets and the mutex is the last member.
// Use atomEntry() and atomMutex() instead of indexing this struct.
struct AlarmConfigAtomSt {  // 0x0bc4
  int valid;                // 0x0000
  int alarmType;            // 0x0004
  time_t lastRecTime;       // 0x0008
  int alarmInterval;        // 0x000c
  char unknown_010[0x58];
  char mp4RecordFile[256];  // 0x0068
  char jpegFile[256];       // 0x0168
  char uploadvideoUrl[512]; // 0x268
  char uploadPicUrl[512];   // 0x468
  time_t recordAliveTimes;  // 0x668
  char unknown_66c[0x1c];
  int unknown_688;          // 0x0688  8000 audioSampleRate ?
  int unknown_68c;          // 0x068c  16    audioBitWidth ?
  int unknown_690;          // 0x0690  1
  int unknown_694;          // 0x0694  2
  int unknown_698;          // 0x0698  25  fps?
  int unknown_69c;          // 0x069c  320 sub width?
  int unknown_6a0;          // 0x06a0
  char unknown_6a4[0x508];
  pthread_mutex_t mutex;    // 0x0bac sizeof(pthread_mutex_t) = 0x18
};

struct AlarmConfigWyzeSt {  // 0x1444
  int valid;                // 0x0000
  int alarmType;            // 0x0004
  char aws_id[0x20];        // 0x0028
  time_t lastRecTime;       // 0x0028
  int alarmInterval;        // 0x002c
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

static char *alarmConfigAtom = NULL; // the table of atomCount entries of atomEntrySize bytes
static size_t atomEntrySize = 0;
static int atomCount = 0; // 15, or 18 on ATOMCam2 4.58.0.180
static struct AlarmConfigWyzeSt *alarmConfigWyze = NULL; // alarmConfigWyze[14]
extern int wyze;
static int alarmInterval = 300;

static struct AlarmConfigAtomSt *atomEntry(int i) {
  return (struct AlarmConfigAtomSt *)(alarmConfigAtom + i * atomEntrySize);
}

static pthread_mutex_t *atomMutex(int i) {
  return (pthread_mutex_t *)(alarmConfigAtom + (i + 1) * atomEntrySize - sizeof(pthread_mutex_t));
}

void *memset(void *s, int c, size_t n) {

  if(wyze) {
    if(!c && (n == 0x1444)) {
      unsigned int s1 = 0;
      asm volatile(
        "ori %0, $17, 0\n"
        : "=r"(s1)
      );
      if(!s1) alarmConfigWyze = s;
      if(s1 == 14) SetAlarmConfigInterval(alarmInterval);
    }
  } else {
    // iCamera_app clears the entries in order at startup and has no other memset of this size
    if(!c && ((n == 0x0bc4) || (n == 0x0bc8))) {
      if(!alarmConfigAtom) {
        alarmConfigAtom = s;
        atomEntrySize = n;
        atomCount = 1;
      } else if((n == atomEntrySize) && ((char *)s == alarmConfigAtom + atomCount * atomEntrySize)) {
        atomCount++;
      }
    }
  }
  // memset is called before the execution of constructor.
  if(!original_memset) original_memset = dlsym(dlopen ("/lib/libc.so.0", RTLD_LAZY), "memset");
  return original_memset(s, c, n);
}

char *AlarmConfig(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  int alarmType = atoi(p);
  if((alarmType < 0) || (alarmType > 14)) return "error";
  if(wyze ? !alarmConfigWyze : (!alarmConfigAtom || (alarmType >= atomCount))) return "error";

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";

  if(!strcasecmp(p, "alarmInterval")) {
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    if(!p) {
      int interval = wyze ? alarmConfigWyze[alarmType].alarmInterval : atomEntry(alarmType)->alarmInterval;
      time_t time = wyze ? alarmConfigWyze[alarmType].lastRecTime : atomEntry(alarmType)->lastRecTime;
      snprintf(CommandResBuf, 255, "%d ", interval);
      strftime(CommandResBuf + strlen(CommandResBuf), 255 - strlen(CommandResBuf), "%Y/%m/%d %T", localtime(&time));
      return CommandResBuf;
    }
    int interval = atoi(p);
    if((interval < 30) || (interval > 300)) return "error";
    if(wyze) {
      pthread_mutex_lock(&alarmConfigWyze[alarmType].mutex);
      alarmConfigWyze[alarmType].alarmInterval = interval;
      pthread_mutex_unlock(&alarmConfigWyze[alarmType].mutex);
    } else {
      pthread_mutex_lock(atomMutex(alarmType));
      atomEntry(alarmType)->alarmInterval = interval;
      pthread_mutex_unlock(atomMutex(alarmType));
    }
    return "ok";
  }

  if(!strcasecmp(p, "dump")) {
    void *addr = wyze ? (void *)(alarmConfigWyze + alarmType) : (void *)atomEntry(alarmType);
    int size = wyze ? sizeof(struct AlarmConfigWyzeSt) : atomEntrySize;
    fprintf(stderr, "AlarmConfig %d : %08x\n",alarmType, addr);
    Dump("AlarmConfig", addr, size);
    return "ok";
  }
  return "error";
}

int SetAlarmConfigInterval(int interval) {

  alarmInterval = interval;
  if(wyze) {
    if(!alarmConfigWyze) return -1;
    for(int i = 0; i < 15; i++) {
      pthread_mutex_lock(&alarmConfigWyze[i].mutex);
      if(alarmConfigWyze[i].alarmInterval >= 30) alarmConfigWyze[i].alarmInterval = interval;
      pthread_mutex_unlock(&alarmConfigWyze[i].mutex);
    }
  } else {
    if(!alarmConfigAtom) return -1;
    for(int i = 0; i < atomCount; i++) {
      // With the 0x0bc8 entries a motion alarm is type 1 or 7 and each checks the time of the other.
      // Changing all the types at startup stopped the alarms ("motion_alarm_tmp_screen!" all the time).
      if((atomEntrySize == 0x0bc8) && (i != 1) && (i != 7)) continue;
      pthread_mutex_lock(atomMutex(i));
      if(atomEntry(i)->alarmInterval >= 30) atomEntry(i)->alarmInterval = interval;
      pthread_mutex_unlock(atomMutex(i));
    }
  }
  return 0;
}
