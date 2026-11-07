#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>

// Size of the Main HD timestamp (TIMESTAMP_SIZE in hack.ini, "timestamp <size>" command).
//
// liblocalsdk keeps the OSD settings of each group (get_osd_params) and redraws the timestamp
// every second under g_osdTimestampMutex: when scaleDen != scaleNum it draws the original size
// into a work buffer and scales it into the region buffer, packed with the scaled width.
// sample_osd_init allocates the region buffer and sets the region size from the scale at boot.
// So iCamera_app sets the original size at boot as before (the region buffer is then the largest),
// and the scale and the region rectangle are changed afterwards, at boot and from the web UI,
// without a reboot. ch3 (Main HEVC) shares the OSD group with ch0.

#define HACK_INI            "/tmp/hack.ini"
#define TIMESTAMP_CHARS     20
#define OSD_TIMESTAMP       1
#define OSD_LAYER_TIMESTAMP 0
#define OSD_REG_PIC         5
#define PARAMS_SEARCH_WORDS 48
#define APPLY_RETRY_SEC     120

// local_sdk_video_osd_set_parameters() param
// The timestamp is scaled by scaleNum / scaleDen (valid only if scaleDen > scaleNum).
struct osdParams_st {
  int enable;     // bit0: timestamp bit1: logo
  int x;          // timestamp left
  int y;          // timestamp top
  int scaleDen;
  int scaleNum;
};

struct fontBitmap_st {
  int height;
  int width;
};

typedef struct {
  int type;
  int sx;
  int sy;
  int dx;
  int dy;
  int fmt;
  void *data;
  int dummy;
} IMPOSDRgnAttr;

static const struct {
  int size;
  int den;
  int num;
} ScaleTable[] = {
  { 100, 1, 1 },
  { 75, 4, 3 },
  { 67, 3, 2 },
  { 50, 2, 1 },
};

static int (*real_local_sdk_video_osd_set_parameters)(int ch, struct osdParams_st *params);
static int (*real_sdkosd_get_font_bitmap)(struct fontBitmap_st **font);
static int *(*real_get_osd_params)(int ch);
static int (*real_get_osd_layer_handler)(int ch, int layer);
static pthread_mutex_t *real_g_osdTimestampMutex;
static int (*real_IMP_OSD_GetRgnAttr)(int handle, IMPOSDRgnAttr *attr);
extern int IMP_OSD_SetRgnAttr(int handle, IMPOSDRgnAttr *attr); // watermark.c

// the group 0 settings in liblocalsdk: data, x, y, scaleDen, scaleNum. The offset differs by model
// (x is word 21 on ATOM Cam2 and word 24 on ATOM Cam Swing), so it is found from the values iCamera_app set.
static int *OsdParams = NULL;
static int OsdParamsOffset = 0; // word index of x
static int OriginalX;
static int OriginalY;
static int TimestampSize = 100;
static int AppliedSize = 100;
static pthread_mutex_t ApplyMutex = PTHREAD_MUTEX_INITIALIZER;
static int RetryRunning = 0;

static void __attribute ((constructor)) timestamp_init(void) {

  void *handle = dlopen("/system/lib/liblocalsdk.so", RTLD_LAZY);
  real_local_sdk_video_osd_set_parameters = dlsym(handle, "local_sdk_video_osd_set_parameters");
  // looked up here, not linked: a firmware without them keeps the original size
  real_sdkosd_get_font_bitmap = dlsym(handle, "sdkosd_get_font_bitmap");
  real_get_osd_params = dlsym(handle, "get_osd_params");
  real_get_osd_layer_handler = dlsym(handle, "get_osd_layer_handler");
  real_g_osdTimestampMutex = dlsym(handle, "g_osdTimestampMutex");
  real_IMP_OSD_GetRgnAttr = dlsym(dlopen("/system/lib/libimp.so", RTLD_LAZY), "IMP_OSD_GetRgnAttr");
}

static int GetTimestampSize() {

  FILE *fp = fopen(HACK_INI, "r");
  if(!fp) return 100;
  char buf[256];
  int size = 100;
  while(fgets(buf, sizeof(buf), fp)) {
    if(!strncmp(buf, "TIMESTAMP_SIZE=", 15)) {
      size = atoi(buf + 15);
      break;
    }
  }
  fclose(fp);
  return size;
}

// return 0: done, 1: the OSD is not running yet, -1: error
static int ApplyTimestampSize(int size) {

  int i;
  for(i = 0; i < sizeof(ScaleTable) / sizeof(ScaleTable[0]); i++) {
    if(size == ScaleTable[i].size) break;
  }
  if(i >= sizeof(ScaleTable) / sizeof(ScaleTable[0])) return -1;
  if(!real_sdkosd_get_font_bitmap || !real_get_osd_params || !real_get_osd_layer_handler ||
     !real_g_osdTimestampMutex || !real_IMP_OSD_GetRgnAttr) {
    fprintf(stderr, "[timestamp] not supported on this firmware\n");
    return -1;
  }

  if(!OsdParams) return 1; // iCamera_app has not set the OSD yet
  unsigned int *data = (unsigned int *)(long)OsdParams[OsdParamsOffset - 1];
  int handle = real_get_osd_layer_handler(0, OSD_LAYER_TIMESTAMP);
  if(!data || (handle < 0)) return 1;

  struct fontBitmap_st *font = NULL;
  if(real_sdkosd_get_font_bitmap(&font) || !font) {
    fprintf(stderr, "[timestamp] font bitmap error\n");
    return -1;
  }
  IMPOSDRgnAttr attr;
  memset(&attr, 0, sizeof(attr));
  if(real_IMP_OSD_GetRgnAttr(handle, &attr)) {
    fprintf(stderr, "[timestamp] IMP_OSD_GetRgnAttr error\n");
    return -1;
  }
  // the region must be where the settings say: this checks the settings offset found from the
  // values iCamera_app set. attr.data is not checked: IMP returns its own copy of the bitmap,
  // and the redraw passes the settings buffer with IMP_OSD_UpdateRgnAttrData every second.
  if((attr.type != OSD_REG_PIC) || (attr.sx != OsdParams[OsdParamsOffset]) || (attr.sy != OsdParams[OsdParamsOffset + 1])) {
    fprintf(stderr, "[timestamp] region mismatch type:%d (%d,%d)-(%d,%d) settings:(%d,%d)\n",
            attr.type, attr.sx, attr.sy, attr.dx, attr.dy, OsdParams[OsdParamsOffset], OsdParams[OsdParamsOffset + 1]);
    return -1;
  }
  attr.data = data;

  // Keep the bottom-right corner. Same integer arithmetic as sample_osd_init.
  int den = ScaleTable[i].den;
  int num = ScaleTable[i].num;
  int width = TIMESTAMP_CHARS * font->width;
  int height = font->height;
  int w = width / den * num;
  int h = height / den * num;
  int x = OriginalX + width - w;
  int y = OriginalY + height - h;

  pthread_mutex_lock(real_g_osdTimestampMutex);
  // the buffer holds the original size (allocated at boot); clear it so that nothing of the
  // old size shows until the next redraw (within a second)
  memset(data, 0, width * height * sizeof(unsigned int));
  OsdParams[OsdParamsOffset] = x;
  OsdParams[OsdParamsOffset + 1] = y;
  OsdParams[OsdParamsOffset + 2] = den;
  OsdParams[OsdParamsOffset + 3] = num;
  attr.sx = x;
  attr.sy = y;
  attr.dx = x + w - 1;
  attr.dy = y + h - 1;
  int ret = IMP_OSD_SetRgnAttr(handle, &attr);
  pthread_mutex_unlock(real_g_osdTimestampMutex);
  if(ret) {
    fprintf(stderr, "[timestamp] IMP_OSD_SetRgnAttr error %d\n", ret);
    return -1;
  }
  AppliedSize = size;
  fprintf(stderr, "[timestamp] size %d%% (%d/%d) x:%d y:%d\n", size, num, den, x, y);
  return 0;
}

// at boot the command and the hook come before sample_osd_init: wait for the OSD
static void *RetryThread(void *arg) {

  for(int i = 0; i < APPLY_RETRY_SEC; i++) {
    sleep(1);
    pthread_mutex_lock(&ApplyMutex);
    int ret = ApplyTimestampSize(TimestampSize);
    if(ret <= 0) RetryRunning = 0;
    pthread_mutex_unlock(&ApplyMutex);
    if(ret <= 0) return NULL;
  }
  fprintf(stderr, "[timestamp] the OSD did not start\n");
  pthread_mutex_lock(&ApplyMutex);
  RetryRunning = 0;
  pthread_mutex_unlock(&ApplyMutex);
  return NULL;
}

// call with ApplyMutex locked
static int SetTimestampSize(int size) {

  TimestampSize = size;
  int ret = ApplyTimestampSize(size);
  if((ret > 0) && !RetryRunning) {
    pthread_t thread;
    if(!pthread_create(&thread, NULL, RetryThread, NULL)) {
      pthread_detach(thread);
      RetryRunning = 1;
    }
  }
  return ret;
}

int local_sdk_video_osd_set_parameters(int ch, struct osdParams_st *params) {

  int ret = real_local_sdk_video_osd_set_parameters(ch, params);
  if(ret || ch || !params || !(params->enable & OSD_TIMESTAMP) || (params->scaleDen != params->scaleNum)) return ret;
  if(OsdParams || !real_get_osd_params) return ret;

  int *p = real_get_osd_params(0);
  if(!p) return ret;
  for(int i = 1; i < PARAMS_SEARCH_WORDS; i++) {
    if((p[i] == params->x) && (p[i + 1] == params->y) && (p[i + 2] == params->scaleDen) && (p[i + 3] == params->scaleNum)) {
      pthread_mutex_lock(&ApplyMutex);
      OsdParams = p;
      OsdParamsOffset = i;
      OriginalX = params->x;
      OriginalY = params->y;
      int size = GetTimestampSize();
      if(size != 100) SetTimestampSize(size);
      pthread_mutex_unlock(&ApplyMutex);
      return ret;
    }
  }
  fprintf(stderr, "[timestamp] OSD settings not found\n");
  return ret;
}

char *Timestamp(int fd, char *tokenPtr) {

  static char res[16];
  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    snprintf(res, sizeof(res), "%d", AppliedSize);
    return res;
  }
  pthread_mutex_lock(&ApplyMutex);
  int ret = SetTimestampSize(atoi(p));
  pthread_mutex_unlock(&ApplyMutex);
  return (ret < 0) ? "error" : "ok";
}
