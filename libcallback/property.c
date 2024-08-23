#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

extern char CommandResBuf[];
extern void CommandResponse(int fd, const char *res);
extern int GetUserConfig(const char *key);

static void (*ProtocolSetProperty)(char * buf1, char *req, char *res);

static char *Raw(char *tokenPtr, const char *config, int item);
static char *NightVision(char *tokenPtr, const char *config, int item);
static char *NightCutThr(char *tokenPtr, const char *config, int item);
static char *Rotate(char *tokenPtr, const char *config, int item);
static char *OnOff(char *tokenPtr, const char *config, int item);
static char *Level3(char *tokenPtr, const char *config, int item);
static char *RecordType(char *tokenPtr, const char *config, int item);

struct CommandTableSt {
  const char *cmd;
  const char *config;
  int item;
  char * (*func)(char *, const char *, int);
};

static struct CommandTableSt PropertyCommandTable[] = {
  { "raw",            "",               0,   &Raw },           // raw item val
  { "nightVision",    "nightVision",    6,   &NightVision },   // nightVision on:1/off:2/auto:3
  { "nightCutThr",    "night_cut_thr",  62,  &NightCutThr },   // nightCutThr dusk:1/dark:2
  { "IrLED",          "pir_alaram",     36,  &OnOff },         // IrLED on:1/off:2
  { "motionDet",      "MASwitch",       9,   &OnOff },         // motionDet on:1/off:2
  { "motionLevel",    "MMALevel",       10,  &Level3 },        // motionLevel low:1/mid:128/high:255
  { "soundDet",       "AASwitch",       11,  &OnOff },         // soundDet on:1/off:2
  { "soundLevel",     "AMALevel",       12,  &Level3 },        // soundLevel low:1/mid:128/high:255
  { "cautionDet",     "CASwitch",       14,  &OnOff },         // cautionDet on:1/off:2
  { "drawBoxSwitch",  "drawBoxSwitch",  8,   &OnOff },         // drawBoxSwitch on:1/off:2
  { "recordType",     "recordType",     29,  &RecordType },    // recordType cont:1/motion:2
  { "indicator",      "indicator",      22,  &OnOff },         // indicator on:1/off:2
  { "horSwitch",      "horSwitch",      24,  &OnOff },         // horSwitch on:1/off:2
  { "verSwitch",      "verSwitch",      25,  &OnOff },         // verSwitch on:1/off:2
  { "rotate",         "horSwitch",      24,  &Rotate },        // rotate on:1/off:2
  { "audioRec",       "AST",            23,  &OnOff },         // audioRec on:1/off:2
  { "timestamp",      "osdSwitch",      37,  &OnOff },         // timestamp on:1/off:2
  { "watermark",      "watermark_flag", 7,   &OnOff },         // watermark on:1/off:2
};

static int setItemProp(int item, int val) {

  if(!ProtocolSetProperty) {
    fprintf(stderr, "setItemProp: not found P2P_ReceiveProtocol_SetProperty function\n");
    return -1;
  }
  const int bufOffset = 0x100;
  const int strSize = 0x2800;
  const int bufSize = bufOffset + strSize + strSize;
  char *buf = (char *)malloc(bufSize);
  char *req = buf + bufOffset;
  char *res = req + bufOffset;
  memset(buf, 0, bufSize);
  snprintf(req, strSize, "{\n  \"PropertyList\" : {\n    \"%d\" : %d\n  }\n}", item, val);
  ProtocolSetProperty(buf, req, res);
  int ret = 0;
  if(!strncmp(res, "{\"Result\":", 10)) sscanf(res, "{\"Result\":%d,", &ret);
  free(buf);
  return !ret;
}

char *Property(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(p) {
    for(int i = 0; i < sizeof(PropertyCommandTable) / sizeof(struct CommandTableSt); i++) {
      if(!strcasecmp(p, PropertyCommandTable[i].cmd)) return (*PropertyCommandTable[i].func)(tokenPtr, PropertyCommandTable[i].config, PropertyCommandTable[i].item);
    }
  } else {
    for(int i = 1; i < sizeof(PropertyCommandTable) / sizeof(struct CommandTableSt); i++) {
      snprintf(CommandResBuf, 255, "%-16s = %s\n", PropertyCommandTable[i].cmd, (*PropertyCommandTable[i].func)(tokenPtr, PropertyCommandTable[i].config, PropertyCommandTable[i].item));
      write(fd, CommandResBuf, strlen(CommandResBuf));
    }
    return "ok";
  }
  return "error";
}

static char *Raw(char *tokenPtr, const char *config, int dummy) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  int item = atoi(p);

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  int val = atoi(p);

  return setItemProp(item, val) ? "error" : "ok";
}

static char *NightVision(char *tokenPtr, const char *config, int item) {

  int val = -1;
  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int ret = GetUserConfig(config);
    if(ret == 1) return "on";
    if(ret == 2) return "off";
    if(ret == 3) return "auto";
    return "error";
  }

  if(!strcmp(p, "on")) {
    val = 1;
  } else if(!strcmp(p, "off")) {
    val = 2;
  } else if(!strcmp(p, "auto")) {
    val  = 3;
  }
  if(val < 0) return "error";

  return setItemProp(item, val) ? "error" : "ok";
}

static char *NightCutThr(char *tokenPtr, const char *config, int item) {

  int val = -1;
  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int ret = GetUserConfig(config);
    if(ret == 1) return "dusk";
    if(ret == 2) return "dark";
    return "error";
  }

  if(!strcmp(p, "dusk")) {
    val = 1;
  } else if(!strcmp(p, "dark")) {
    val = 2;
  }
  if(val < 0) return "error";

  return setItemProp(item, val) ? "error" : "ok";
}

static char *Rotate(char *tokenPtr, const char *config, int item) {

  int val = -1;
  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int ret = GetUserConfig(config);
    if(ret == 1) return "on";
    if(ret == 2) return "off";
    return "error";
  }

  if(!strcmp(p, "on")) {
    val = 1;
  } else if(!strcmp(p, "off")) {
    val = 2;
  }
  if(val < 0) return "error";

  setItemProp(item, val);
  return setItemProp(item + 1, val) ? "error" : "ok";
}

static char *OnOff(char *tokenPtr, const char *config, int item) {

  int val = -1;
  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int ret = GetUserConfig(config);
    if(ret == 1) return "on";
    if(ret == 2) return "off";
    return "error";
  }

  if(!strcmp(p, "on")) {
    val = 1;
  } else if(!strcmp(p, "off")) {
    val = 2;
  }
  if(val < 0) return "error";

  return setItemProp(item, val) ? "error" : "ok";
}

static char *Level3(char *tokenPtr, const char *config, int item) {

  int val = -1;
  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int ret = GetUserConfig(config);
    if(ret == 1) return "low";
    if(ret == 128) return "mid";
    if(ret == 255) return "low";
    return "error";
  }

  if(!strcmp(p, "low")) {
    val = 1;
  } else if(!strcmp(p, "mid")) {
    val = 128;
  } else if(!strcmp(p, "high")) {
    val = 255;
  }
  if(val < 0) return "error";

  return setItemProp(item, val) ? "error" : "ok";
}

static char *RecordType(char *tokenPtr, const char *config, int item) {

  int val = -1;
  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int ret = GetUserConfig(config);
    if(ret == 1) return "cont";
    if(ret == 2) return "motion";
    return "error";
  }

  if(!strcmp(p, "cont")) {
    val = 1;
  } else if(!strcmp(p, "motion")) {
    val = 2;
  }
  if(val < 0) return "error";

  return setItemProp(item, val) ? "error" : "ok";
}

extern unsigned int _init;
extern unsigned int _fini;
static const char *SearchStr = "[%s,%04d]----- p2p recv protocol set property -----\n";

static void __attribute ((constructor)) set_property_init(void) {

  char path[256];
  snprintf(path, 256, "/proc/%d/maps", getpid());
  FILE *fp = fopen(path, "r");
  if(!fp) {
    fprintf(stderr, "set_property_init: file can't open /proc/pid/maps\n");
    return;
  }
  unsigned int start, end;
  int ret = fscanf(fp, "%08x-%08x ", &start, &end);
  fclose(fp);
  fprintf(stderr, "scanf %d\n", ret);
  if(ret != 2) {
    fprintf(stderr, "set_property_init: /proc/pid/maps format error\n");
    return;
  }
  fprintf(stderr, "iCamera_app address: %08x-%08x\n", start, end);

  unsigned int strAddr = 0;
  for(char *p = (char *)&_fini; p < (char *)end; p++) {
    if((*p == '[') && !strcmp(p, SearchStr)) {
      strAddr = (unsigned int)p;
      break;
    }
  }
  if(!strAddr) {
    fprintf(stderr, "set_property_init: p2p recv not string found\n");
    return;
  }

  unsigned int lui = strAddr >> 16;
  unsigned int addiu = strAddr & 0xffff;
  if(addiu & 0x8000) lui++;
  lui |= 0x3c000000;
  unsigned int luiMask = 0xffe0ffff;
  addiu |= 0x24040000;
  unsigned int addiuMask = 0xfc1fffff;
  unsigned int jal = 0x0c000000;
  unsigned int jalMask = 0xfc000000;
  unsigned int addiusp = 0x27bd0000;
  unsigned int addiuspspMask = 0xffff0000;
  unsigned int *pc = 0;
  int ureg = -1;
  unsigned int setSingle = 0;
  for(pc = &_init; pc < &_fini; pc++) {
    if((pc[0] & luiMask) == lui) {
      int ureg = (pc[0] >> 16) & 31;
      for(int i = 1; i < 16; i++) {
        if(pc[i] == (addiu | (ureg << 21))) {
          ureg = -1;
        }
        if((ureg < 0) && ((pc[i] & jalMask) == jal)) {
          ureg--;
          break;
        }
      }
      if(ureg == -2) {
        for(int i = 0; i < 256; i++) {
          pc--;
          if((pc[0] & addiuspspMask) == addiusp) {
            setSingle = (unsigned int)pc;
            fprintf(stderr, "set_property_init: P2P_ReceiveProtocol_SetPropertySingle: %08x\n", (unsigned int)pc);
            break;
          }
        }
        break;
      }
    }
  }
  if(!setSingle) {
    fprintf(stderr, "set_property_init: not found P2P_ReceiveProtocol_SetPropertySingle function\n");
    return;
  }

  unsigned int jalSetProperty = jal | (setSingle >> 2);
  for(pc = &_init; pc < &_fini; pc++) {
    if(pc[0] == jalSetProperty) {
      for(int i = 0; i < 256; i++) {
        pc--;
        if((pc[0] & addiuspspMask) == addiusp) {
          ProtocolSetProperty = (void (*)(char *buf, char *req, char *res))pc;
          fprintf(stderr, "set_property_init: P2P_ReceiveProtocol_SetProperty: %08x\n", (unsigned int)pc);
          break;
        }
      }
      break;
    }
  }
  if(!ProtocolSetProperty) {
    fprintf(stderr, "set_property_init: not found P2P_ReceiveProtocol_SetProperty function\n");
    return;
  }
}
