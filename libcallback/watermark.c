
#include <stdio.h>
#include <dlfcn.h>
#include <string.h>

struct bitmapInfo_st {
  int y;
  int x;
  unsigned int *addr;
  int valid;
};

static int (*real_local_sdk_video_osd_set_logo_bitmap)(struct bitmapInfo_st *info);
static unsigned int WatermarkBuffer[500 * 100];
static struct bitmapInfo_st BitmapInfo;

static void __attribute ((constructor)) watermark_init(void) {

  real_local_sdk_video_osd_set_logo_bitmap = dlsym(dlopen("/system/lib/liblocalsdk.so", RTLD_LAZY), "local_sdk_video_osd_set_logo_bitmap");

  FILE *fp = fopen("/tmp/watermark.bgra", "r");
  if(!fp) return;

  int err = 0;
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
  BitmapInfo.valid = 1;

error:
  fclose(fp);
}

int local_sdk_video_osd_set_logo_bitmap(struct bitmapInfo_st *originalInfo) {

  return real_local_sdk_video_osd_set_logo_bitmap(BitmapInfo.valid ? &BitmapInfo : originalInfo);
}
