
#include <stdio.h>
#include <dlfcn.h>
#include <string.h>

#define SDSCALE_NUM             1
#define SDSCALE_DEN             3
#define SCREEN_WIDTH            1920
#define SCREEN_HEIGHT           1080
#define WATERMARK_LEFT          51
#define WATERMARK_BOTTOM        21
#define WATERMARK_MAX_WIDTH     500
#define WATERMARK_MAX_HEIGHT    100
#define WATERMARK_SD_MAX_WIDTH  ((WATERMARK_MAX_WIDTH + SDSCALE_DEN) * SDSCALE_NUM / SDSCALE_DEN)
#define WATERMARK_SD_MAX_HEIGHT ((WATERMARK_MAX_HEIGHT + SDSCALE_DEN) * SDSCALE_NUM / SDSCALE_DEN)
#define OSD_REG_PIC             5
#define PIX_FMT_BGRA            17

struct bitmapInfo_st {
  int y;
  int x;
  unsigned int *addr;
  int valid;
};
static struct bitmapInfo_st BitmapInfo;
static unsigned int WatermarkBuffer[WATERMARK_MAX_WIDTH * WATERMARK_MAX_HEIGHT];
static unsigned int WatermarkBufferSD[WATERMARK_SD_MAX_WIDTH * WATERMARK_MAX_HEIGHT];

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
static int (*real_IMP_OSD_SetRgnAttr)(int handle, IMPOSDRgnAttr *prAttr);
extern int get_osd_layer_handler(int ch,int regionNo);
extern int local_sdk_video_osd_set_logo_bitmap(struct bitmapInfo_st *info);
extern int sdkosd_update_logo_data(unsigned int *buf, int num, int den);

static void __attribute ((constructor)) watermark_init(void) {

  real_IMP_OSD_SetRgnAttr = dlsym(dlopen("/system/lib/libimp.so", RTLD_LAZY), "IMP_OSD_SetRgnAttr");
}

static void UpdateWatermark() {

  BitmapInfo.valid = 0;
  FILE *fp = fopen("/media/mmc/watermark.bgra", "r");
  if(!fp) return;

  int sz = fread(&BitmapInfo, 4, 2, fp);
  if(sz != 2) {
    fprintf(stderr, "watermark file size error\n");
    goto error;
  }
  if(!BitmapInfo.x || !BitmapInfo.y || (BitmapInfo.x * BitmapInfo.y > sizeof(WatermarkBuffer) / sizeof(unsigned int))) {
    fprintf(stderr, "watermark file format error x:%d y:%d\n", BitmapInfo.x, BitmapInfo.y);
    goto error;
  }
  sz = fread(WatermarkBuffer, sizeof(unsigned int), BitmapInfo.x * BitmapInfo.y, fp);
  if(sz != BitmapInfo.x * BitmapInfo.y) {
    fprintf(stderr, "watermark file format error x:%d y:%d filesize:%d\n", BitmapInfo.x, BitmapInfo.y, sz);
    goto error;
  }
  BitmapInfo.addr = WatermarkBuffer;
  int ret = local_sdk_video_osd_set_logo_bitmap(&BitmapInfo);
  if(ret) {
    fprintf(stderr, "local_sdk_video_osd_set_logo_bitmap error: %d\n", ret);
    goto error;
  }
  ret = sdkosd_update_logo_data(WatermarkBufferSD, SDSCALE_DEN, SDSCALE_NUM);
  if(ret) {
    fprintf(stderr, "sdkosd_update_logo_data error: %d\n", ret);
    goto error;
  }
  BitmapInfo.valid = 1;
error:
  fclose(fp);
}

int IMP_OSD_SetRgnAttr(int handle, IMPOSDRgnAttr *attr) {

  int regionHandle0 = get_osd_layer_handler(0, 1);
  int regionHandle1 = get_osd_layer_handler(1, 1);
  if(handle == regionHandle0) {
    if(!BitmapInfo.valid) UpdateWatermark();
    if(!BitmapInfo.valid) goto error;
    attr->type = OSD_REG_PIC;
    attr->fmt = PIX_FMT_BGRA;
    attr->sx = WATERMARK_LEFT;
    attr->sy = SCREEN_HEIGHT - WATERMARK_BOTTOM - BitmapInfo.y;
    attr->dx = WATERMARK_LEFT + BitmapInfo.x - 1;
    attr->dy = SCREEN_HEIGHT - WATERMARK_BOTTOM - 1;
    attr->data = WatermarkBuffer;
  } else if(handle == regionHandle1) {
    if(!BitmapInfo.valid) goto error;
    attr->type = OSD_REG_PIC;
    attr->fmt = PIX_FMT_BGRA;
    attr->sx = WATERMARK_LEFT * SDSCALE_NUM / SDSCALE_DEN;
    attr->sy = (SCREEN_HEIGHT - WATERMARK_BOTTOM) * SDSCALE_NUM / SDSCALE_DEN - BitmapInfo.y * SDSCALE_NUM / SDSCALE_DEN;
    attr->dx = WATERMARK_LEFT * SDSCALE_NUM / SDSCALE_DEN + BitmapInfo.x * SDSCALE_NUM / SDSCALE_DEN - 1;
    attr->dy = (SCREEN_HEIGHT - WATERMARK_BOTTOM) * SDSCALE_NUM / SDSCALE_DEN - 1;
    attr->data = WatermarkBufferSD;
  }
error:
  return real_IMP_OSD_SetRgnAttr(handle, attr);
}

char *Watermark(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p || strcmp(p, "update")) return "error";

  UpdateWatermark();
  if(!BitmapInfo.valid) return "error";

  IMPOSDRgnAttr attr;
  int regionHandle = get_osd_layer_handler(0, 1);
  if(regionHandle < 0) {
    fprintf(stderr, "regionHandle0 error : %d\n", regionHandle);
    return "error";
  }

  int ret = IMP_OSD_SetRgnAttr(regionHandle, &attr);
  if(ret) {
    fprintf(stderr, "IMP_OSD_SetRgnAttr0 error: %d\n", ret);
    return "error";
  }

  regionHandle = get_osd_layer_handler(1, 1);
  if(regionHandle < 0) {
    fprintf(stderr, "regionHandle1 error : %d\n", regionHandle);
    return "error";
  }

  ret = IMP_OSD_SetRgnAttr(regionHandle, &attr);
  if(ret) {
    fprintf(stderr, "IMP_OSD_SetRgnAttr1 error: %d\n", ret);
    return "error";
  }
  return "ok";
}
