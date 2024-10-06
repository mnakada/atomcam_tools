#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <pthread.h>

extern char CommandResBuf[];

// contrast of image effect.
extern int IMP_ISP_Tuning_SetContrast(unsigned char contrast);
extern int IMP_ISP_Tuning_GetContrast(unsigned char *pcontrast);

// brightness of image effect.
extern int IMP_ISP_Tuning_SetBrightness(unsigned char bright);
extern int IMP_ISP_Tuning_GetBrightness(unsigned char *pbright);

// saturation of image effect.
extern int IMP_ISP_Tuning_SetSaturation(unsigned char sat);
extern int IMP_ISP_Tuning_GetSaturation(unsigned char *psat);

// sharpness of image effect.
extern int IMP_ISP_Tuning_SetSharpness(unsigned char sharpness);
extern int IMP_ISP_Tuning_GetSharpness(unsigned char *psharpness);

// AE compensation.
// AE compensation parameters can adjust the target of the image AE.
extern int IMP_ISP_Tuning_SetAeComp(int comp);
extern int IMP_ISP_Tuning_GetAeComp(int *comp);

// AE Max parameters.
extern int IMP_ISP_Tuning_SetAe_IT_MAX(unsigned int it_max);
extern int IMP_ISP_Tuning_GetAE_IT_MAX(unsigned int *it_max);

// DPC Strength.
extern int IMP_ISP_Tuning_SetDPC_Strength(unsigned int ratio);
extern int IMP_ISP_Tuning_GetDPC_Strength(unsigned int *ratio);

// DRC Strength.
extern int IMP_ISP_Tuning_SetDRC_Strength(unsigned int ratio);
extern int IMP_ISP_Tuning_GetDRC_Strength(unsigned int *ratio);

// highlight intensity controls.
extern int IMP_ISP_Tuning_SetHiLightDepress(uint32_t strength);
extern int IMP_ISP_Tuning_GetHiLightDepress(uint32_t *strength);

// Set 3D noise reduction intensity.
extern int IMP_ISP_Tuning_SetTemperStrength(uint32_t ratio);

// Set 2D noise reduction intensity.
extern int IMP_ISP_Tuning_SetSinterStrength(uint32_t ratio);

// Max value of sensor analog gain.
extern int IMP_ISP_Tuning_SetMaxAgain(uint32_t gain);
extern int IMP_ISP_Tuning_GetMaxAgain(uint32_t *gain);

// Max value of sensor Digital gain.
extern int IMP_ISP_Tuning_SetMaxDgain(uint32_t gain);
extern int IMP_ISP_Tuning_GetMaxDgain(uint32_t *gain);

// ISP image mirror(horizontal) effect function (enable/disable)
extern int IMP_ISP_Tuning_SetISPHflip(int mode);
extern int IMP_ISP_Tuning_GetISPHflip(int *pmode);

// ISP image mirror(vertical) effect function (enable/disable)
extern int IMP_ISP_Tuning_SetISPVflip(int mode);
extern int IMP_ISP_Tuning_GetISPVflip(int *pmode);

// ISP exposure attribute.
typedef union isp_core_expr_attr{
  struct {
    int mode; // 0:auto / 1: manual
    int unit; // 0: line / 1: us
    unsigned short time;
  } s_attr;
  struct {
    int mode; // 0:auto / 1: manual
    unsigned short time;
    unsigned short time_min;
    unsigned short time_max;
    unsigned short one_line_expr_in_us;
  } g_attr;
}IMPISPExpr;
extern int IMP_ISP_Tuning_SetExpr(IMPISPExpr *expr);
extern int IMP_ISP_Tuning_GetExpr(IMPISPExpr *expr);

typedef struct {
  unsigned int min_it;
  unsigned int min_again;
  unsigned int min_it_short;
  unsigned int min_again_short;
} IMPISPAEMin;
int IMP_ISP_Tuning_SetAeMin(IMPISPAEMin *ae_min);
int IMP_ISP_Tuning_GetAeMin(IMPISPAEMin *ae_min);

// ISP sensor fps
extern int IMP_ISP_Tuning_GetSensorFPS(unsigned int *num, unsigned int *den);
struct IMPEncoderFrmRate {
  unsigned int frmRateNum;
  unsigned int frmRateDen;
};
extern int IMP_Encoder_GetChnFrmRate(int ch, struct IMPEncoderFrmRate *frm);
extern int IMP_Encoder_SetChnFrmRate(int ch, struct IMPEncoderFrmRate *frm);
struct IMPEncoderGopAttr {
  int uGopCtrlMode;
  unsigned short uGopLength;
  unsigned char uNumB;
  unsigned int uMaxSameSenceCnt;
  int bEnableLT;
  unsigned int uFreqLT;
  int bLTRC;
};
extern int IMP_Encoder_SetChnGopAttr(int ch,struct IMPEncoderGopAttr *gopAttr);
extern int local_sdk_video_set_gop(int ch, int gop);
extern int local_sdk_video_stop(int ch, int p1, int p2);
extern int local_sdk_video_start(int ch);

extern char *VideoCapture(int fd, char *p, char *tokenPtr);

static char *Flip(char *tokenPtr);
static char *Contrast(char *tokenPtr);
static char *Brightness(char *tokenPtr);
static char *Saturation(char *tokenPtr);
static char *Sharpness(char *tokenPtr);
static char *Sinter(char *tokenPtr);
static char *Temper(char *tokenPtr);
static char *AEComp(char *tokenPtr);
static char *AEItMax(char *tokenPtr);
static char *AEMin(char *tokenPtr);
static char *DPC(char *tokenPtr);
static char *DRC(char *tokenPtr);
static char *HiLight(char *tokenPtr);
static char *AGain(char *tokenPtr);
static char *DGain(char *tokenPtr);
static char *Expr(char *tokenPtr);
static char *Bitrate(char *tokenPtr);
static char *Framerate(char *tokenPtr);

struct CommandTableSt {
  const char *cmd;
  char * (*func)(char *);
};
static struct CommandTableSt VideoCommandTable[] = {
  { "flip",      &Flip }, // flip [normal/flip/mirror/flip_mirror]
  { "cont",      &Contrast }, // cont 0 - 255(center:128)
  { "bri",       &Brightness }, // bri 0 - 255(center:128)
  { "sat",       &Saturation }, // sat 0 - 255(center:128)
  { "sharp",     &Sharpness }, // sharp 0 - 255(center:128)
  { "sinter",    &Sinter }, // sinter 0 - 255(center:128)
  { "temper",    &Temper }, // temper 0 - 255(center:128)
  { "aecomp",    &AEComp }, // aecomp 0 - 255
  { "aeitmax",   &AEItMax }, // aeitmax 0-
  { "aemin",     &AEMin }, // it again itshort againshort
  { "dpc",       &DPC }, // dpc 0 - 255
  { "drc",       &DRC }, // drc 0 - 255
  { "hilight",   &HiLight }, // hilight 0 - 10
  { "again",     &AGain }, // again 0 -
  { "dgain",     &DGain }, // dgain 0 -
  { "expr",      &Expr }, // expr manual|auto <time>
  { "bitrate",   &Bitrate }, // bitrate <ch> 10-3000(kbps)|auto
  { "fps",       &Framerate }, // fps <ch> 1-30(fps)|auto
};

static int (*real_local_sdk_video_set_kbps)(int ch, int kbps);
static int (*real_local_sdk_video_set_fps)(int fps);
static int (*real_IMP_Encoder_CreateChn)(int ch, unsigned char *encAttr);

int VideoControl_UserFps = 0;
int VideoControl_AppFps = 25;

static int userBitrate[4] = { 0, 0, 0, 0 };
static int appBitrate[4] = { 960, 180, 0, 800 };

static void __attribute ((constructor)) video_control_init(void) {

  real_local_sdk_video_set_kbps = dlsym(dlopen ("/system/lib/liblocalsdk.so", RTLD_LAZY), "local_sdk_video_set_kbps");
  real_local_sdk_video_set_fps = dlsym(dlopen ("/system/lib/liblocalsdk.so", RTLD_LAZY), "local_sdk_video_set_fps");
  real_IMP_Encoder_CreateChn = dlsym(dlopen ("/system/lib/libimp.so", RTLD_LAZY), "IMP_Encoder_CreateChn");
}

char *VideoCommand(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(p) {
    for(int i = 0; i < sizeof(VideoCommandTable) / sizeof(struct CommandTableSt); i++) {
      if(!strcasecmp(p, VideoCommandTable[i].cmd)) return (*VideoCommandTable[i].func)(tokenPtr);
    }
  }
  return VideoCapture(fd, p, tokenPtr);
}

int local_sdk_video_set_kbps(int ch, int kbps) {

  if((ch == 0) || (ch == 1) || (ch == 3)) {
    appBitrate[ch] = kbps;
    if(userBitrate[ch]) {
      kbps = userBitrate[ch];
      fprintf(stderr, "video_set_kbps ch%d: %d -> %d\n", ch, appBitrate[ch], kbps);
    } else {
      fprintf(stderr, "video_set_kbps ch%d: %d\n", ch, kbps);
    }
  }
  return real_local_sdk_video_set_kbps(ch, kbps);
}

int local_sdk_video_set_fps(int fps) {

  VideoControl_AppFps = fps;
  if(VideoControl_UserFps) {
    fps = VideoControl_UserFps;
    fprintf(stderr, "video_set_fps : %d -> %d\n", VideoControl_AppFps, fps);
  } else {
    fprintf(stderr, "video_set_fps : %d\n", fps);
  }
  return real_local_sdk_video_set_fps(fps);
}

int IMP_Encoder_CreateChn(int ch, unsigned char *attr) {

  struct IMPEncoderGopAttr *gopAttr = (struct IMPEncoderGopAttr *)(attr + 88);
  struct IMPEncoderFrmRate *frm = (struct IMPEncoderFrmRate *)(attr + 80);
  int fps = frm->frmRateNum;
  frm->frmRateNum = 30;
  gopAttr->uGopLength = 30;
  int ret = real_IMP_Encoder_CreateChn(ch, attr);

  frm->frmRateNum = fps;
  gopAttr->uGopLength = fps;
  VideoControl_AppFps = fps;
  IMP_Encoder_SetChnGopAttr(ch, gopAttr);
  IMP_Encoder_SetChnFrmRate(ch, frm);
  return ret;
}

static char *Flip(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int vflip, hflip;
    IMP_ISP_Tuning_GetISPHflip(&hflip);
    IMP_ISP_Tuning_GetISPVflip(&vflip);
    if(!hflip && !vflip) return "normal";
    if(hflip && !vflip) return "flip";
    if(!hflip && vflip) return "mirror";
    return "flip_mirror";
  }

  if(!strcasecmp(p, "normal")) {
    IMP_ISP_Tuning_SetISPVflip(0);
    IMP_ISP_Tuning_SetISPHflip(0);
  } else if(!strcasecmp(p, "flip")) {
    IMP_ISP_Tuning_SetISPVflip(1);
    IMP_ISP_Tuning_SetISPHflip(0);
  } else if(!strcasecmp(p, "mirror")) {
    IMP_ISP_Tuning_SetISPVflip(0);
    IMP_ISP_Tuning_SetISPHflip(1);
  } else if(!strcasecmp(p, "flip_mirror")) {
    IMP_ISP_Tuning_SetISPVflip(1);
    IMP_ISP_Tuning_SetISPHflip(1);
  } else {
    return "error";
  }
  return "ok";
}

static char *Contrast(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned char cont;
    IMP_ISP_Tuning_GetContrast(&cont);
    sprintf(CommandResBuf, "%d\n", cont);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetContrast(atoi(p));
  return res ? "error": "ok";
}

static char *Brightness(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned char bri;
    IMP_ISP_Tuning_GetBrightness(&bri);
    sprintf(CommandResBuf, "%d\n", bri);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetBrightness(atoi(p));
  return res ? "error": "ok";
}

static char *Saturation(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned char sat;
    IMP_ISP_Tuning_GetSaturation(&sat);
    sprintf(CommandResBuf, "%d\n", sat);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetSaturation(atoi(p));
  return res ? "error": "ok";
}

static char *Sharpness(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned char sharpness;
    IMP_ISP_Tuning_GetSharpness(&sharpness);
    sprintf(CommandResBuf, "%d\n", sharpness);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetSharpness(atoi(p));
  return res ? "error": "ok";
}

static char *AEComp(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int comp;
    IMP_ISP_Tuning_GetAeComp(&comp);
    sprintf(CommandResBuf, "%d\n", comp);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetAeComp(atoi(p));
  return res ? "error": "ok";
}

static char *AEItMax(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned int itMax;
    IMP_ISP_Tuning_GetAE_IT_MAX(&itMax);
    sprintf(CommandResBuf, "%d\n", itMax);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetAe_IT_MAX(atoi(p));
  return res ? "error": "ok";
}

static char *AEMin(char *tokenPtr) {

  IMPISPAEMin aemin;
  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    IMP_ISP_Tuning_GetAeMin(&aemin);
    sprintf(CommandResBuf, "%d %d %d %d\n", aemin.min_it, aemin.min_again, aemin.min_it_short, aemin.min_again_short);
    return CommandResBuf;
  }
  aemin.min_it = atoi(p);

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  aemin.min_again = atoi(p);

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  aemin.min_it_short = atoi(p);

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  aemin.min_again_short = atoi(p);

  int res = IMP_ISP_Tuning_SetAeMin(&aemin);
  return res ? "error": "ok";
}

static char *Sinter(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  int res = IMP_ISP_Tuning_SetSinterStrength(atoi(p));
  return res ? "error": "ok";
}

static char *Temper(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  int res = IMP_ISP_Tuning_SetTemperStrength(atoi(p));
  return res ? "error": "ok";
}

static char *DPC(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned int dpc;
    IMP_ISP_Tuning_GetDPC_Strength(&dpc);
    sprintf(CommandResBuf, "%d\n", dpc);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetDPC_Strength(atoi(p));
  return res ? "error": "ok";
}

static char *DRC(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned int drc;
    IMP_ISP_Tuning_GetDRC_Strength(&drc);
    sprintf(CommandResBuf, "%d\n", drc);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetDRC_Strength(atoi(p));
  return res ? "error": "ok";
}

static char *HiLight(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned int strength;
    IMP_ISP_Tuning_GetHiLightDepress(&strength);
    sprintf(CommandResBuf, "%d\n", strength);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetHiLightDepress(atoi(p));
  return res ? "error": "ok";
}

static char *AGain(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned int gain;
    IMP_ISP_Tuning_GetMaxAgain(&gain);
    sprintf(CommandResBuf, "%d\n", gain);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetMaxAgain(atoi(p));
  return res ? "error": "ok";
}

static char *DGain(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned int gain;
    IMP_ISP_Tuning_GetMaxDgain(&gain);
    sprintf(CommandResBuf, "%d\n", gain);
    return CommandResBuf;
  }
  int res = IMP_ISP_Tuning_SetMaxDgain(atoi(p));
  return res ? "error": "ok";
}

static char *Expr(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  IMPISPExpr attr;
  if(!p) {
    IMP_ISP_Tuning_GetExpr(&attr);
    sprintf(CommandResBuf, "%s %d %d %d %d\n", attr.g_attr.mode ? "manual" : "auto", attr.g_attr.time, attr.g_attr.time_min, attr.g_attr.time_max, attr.g_attr.one_line_expr_in_us);
    return CommandResBuf;
  }

  int res = 0;
  if(!strcasecmp(p, "auto")) {
    attr.s_attr.mode = 0;
    attr.s_attr.unit = 0;
    attr.s_attr.time = 0;
    IMPISPAEMin aemin;
    IMP_ISP_Tuning_GetAeMin(&aemin);
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    if(!p) return "error";
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    if(!p) return "error";
    aemin.min_it = atoi(p);
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    if(!p) return "error";
    int itmax = atoi(p);
    res |= IMP_ISP_Tuning_SetAeMin(&aemin);
    res |= IMP_ISP_Tuning_SetAe_IT_MAX(itmax);
    res |= IMP_ISP_Tuning_SetExpr(&attr);
  } else if(!strcasecmp(p, "manual")) {
    attr.s_attr.mode = 1;
    attr.s_attr.unit = 0;
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    if(!p) return "error";
    attr.s_attr.time = atoi(p);
    IMPISPAEMin aemin;
    IMP_ISP_Tuning_GetAeMin(&aemin);
    aemin.min_it = 1;
    res |= IMP_ISP_Tuning_SetAeMin(&aemin);
    res |= IMP_ISP_Tuning_SetAe_IT_MAX(1683);
    res |= IMP_ISP_Tuning_SetExpr(&attr);
  } else {
    res = -1;
  }
  return res ? "error": "ok";
}

static char *Bitrate(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  int ch = atoi(p);
  if((ch != 0) && (ch != 1) && (ch != 3)) return "error";
  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    if(userBitrate[ch]) {
      sprintf(CommandResBuf, "%d\n", userBitrate[ch]);
    } else {
      sprintf(CommandResBuf, "auto %d\n", appBitrate[ch]);
    }
    return CommandResBuf;
  }
  if(!strcasecmp(p, "auto")) {
    userBitrate[ch] = 0;
    fprintf(stderr, "video_set_kbps ch%d: %d\n", ch, appBitrate[ch]);
    real_local_sdk_video_set_kbps(ch, appBitrate[ch]);
  } else {
    int kbps = atoi(p);
    if((kbps < 10) || (kbps > 3000)) return "error";
    userBitrate[ch] = kbps;
    fprintf(stderr, "video_set_kbps ch%d: %d\n", ch, userBitrate[ch]);
    real_local_sdk_video_set_kbps(ch, userBitrate[ch]);
  }
  return "ok";
}

static char *Framerate(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    unsigned int num, den;
    IMP_ISP_Tuning_GetSensorFPS(&num, &den);
    struct IMPEncoderFrmRate encFps;
    IMP_Encoder_GetChnFrmRate(0, &encFps);
    if(VideoControl_UserFps) {
      sprintf(CommandResBuf, "%d isp:%d/%d enc:%d/%d\n", VideoControl_UserFps, num, den, encFps.frmRateNum, encFps.frmRateDen);
    } else {
      sprintf(CommandResBuf, "auto %d isp:%d/%d enc:%d/%d\n", VideoControl_AppFps, num, den, encFps.frmRateNum, encFps.frmRateDen);
    }
    return CommandResBuf;
  }

  int fps = VideoControl_AppFps;
  if(!strcasecmp(p, "auto")) {
    VideoControl_UserFps = 0;
    fprintf(stderr, "video framerate : auto %d\n", VideoControl_AppFps);
  } else {
    fps = atoi(p);
    if((fps < 1) || (fps > 30)) return "error";
    VideoControl_UserFps = fps;
    fprintf(stderr, "video framerate: %d\n", VideoControl_UserFps);
  }

  local_sdk_video_stop(0, 0, 0);
  local_sdk_video_stop(1, 0, 0);
  local_sdk_video_stop(3, 0, 0);
  local_sdk_video_set_gop(0, fps);
  local_sdk_video_set_gop(1, fps);
  local_sdk_video_set_gop(3, fps);
  real_local_sdk_video_set_fps(fps);
  local_sdk_video_start(0);
  local_sdk_video_start(1);
  local_sdk_video_start(3);
  return "ok";
}
