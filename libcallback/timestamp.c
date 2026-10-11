#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <string.h>

#define HACK_INI          "/tmp/hack.ini"
#define TIMESTAMP_CHARS   20
#define OSD_TIMESTAMP     1

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

static const struct {
  int size;
  int den;
  int num;
} ScaleTable[] = {
  { 75, 4, 3 },
  { 67, 3, 2 },
  { 50, 2, 1 },
};

static int (*real_local_sdk_video_osd_set_parameters)(int ch, struct osdParams_st *params);
extern int sdkosd_get_font_bitmap(struct fontBitmap_st **font);

static void __attribute ((constructor)) timestamp_init(void) {

  real_local_sdk_video_osd_set_parameters = dlsym(dlopen("/system/lib/liblocalsdk.so", RTLD_LAZY), "local_sdk_video_osd_set_parameters");
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

int local_sdk_video_osd_set_parameters(int ch, struct osdParams_st *params) {

  if(!ch && params && (params->enable & OSD_TIMESTAMP) && (params->scaleDen == params->scaleNum)) {
    int size = GetTimestampSize();
    struct fontBitmap_st *font = NULL;
    for(int i = 0; i < sizeof(ScaleTable) / sizeof(ScaleTable[0]); i++) {
      if(size != ScaleTable[i].size) continue;
      if(sdkosd_get_font_bitmap(&font) || !font) {
        fprintf(stderr, "[timestamp] font bitmap error\n");
        break;
      }
      // Keep the bottom-right corner. Same integer arithmetic as sample_osd_init.
      int den = ScaleTable[i].den;
      int num = ScaleTable[i].num;
      int width = TIMESTAMP_CHARS * font->width;
      params->x += width - width / den * num;
      params->y += font->height - font->height / den * num;
      params->scaleDen = den;
      params->scaleNum = num;
      fprintf(stderr, "[timestamp] size %d%% (%d/%d) x:%d y:%d\n", size, num, den, params->x, params->y);
      break;
    }
  }
  return real_local_sdk_video_osd_set_parameters(ch, params);
}
