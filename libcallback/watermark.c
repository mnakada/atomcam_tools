
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
  if(fp) {
    int sz = fread(&BitmapInfo, 4, 2, fp);
    fprintf(stderr, "bitmmap %d %x %x\n", sz, BitmapInfo.y, BitmapInfo.x);
    if((sz != 2) || !BitmapInfo.x || !BitmapInfo.y || (BitmapInfo.x * BitmapInfo.y > sizeof(WatermarkBuffer) / sizeof(unsigned int))) {
      fprintf(stderr, "watermark file format error sz:%d x:%d y:%d size:%d %d\n", sz, BitmapInfo.x, BitmapInfo.y, BitmapInfo.x * BitmapInfo.y, sizeof(WatermarkBuffer) / sizeof(unsigned int));
      fclose(fp);
      return;
    }
    sz = fread(WatermarkBuffer, sizeof(unsigned int), BitmapInfo.x * BitmapInfo.y, fp);
    fclose(fp);
    if(sz != BitmapInfo.x * BitmapInfo.y) {
      fprintf(stderr, "watermark file format error %d x: %d y: %d %d\n", sz, BitmapInfo.x, BitmapInfo.y,BitmapInfo.x * BitmapInfo.y);
      return;
    }
    BitmapInfo.addr = WatermarkBuffer;
    BitmapInfo.valid = 1;
  }
}

// disable mmc mount
int local_sdk_video_osd_set_logo_bitmap(struct bitmapInfo_st *originalInfo) {

  struct bitmapInfo_st *bitmapInfo = originalInfo;
  if(BitmapInfo.valid) bitmapInfo = &BitmapInfo;
  return real_local_sdk_video_osd_set_logo_bitmap(bitmapInfo);
}
