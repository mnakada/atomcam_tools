#include <stdio.h>
#include <string.h>

struct RgnInfoSt {
  int type;
  int x1;
  int y1;
  int x2;
  int y2;
  int pixfmt;
  int color; // 0: black 1:white 2: red 3:green 4:blue
  int width;
};

struct RgnGrpInfoSt {
  int show;
  int x;
  int y;
  float scalex;
  float scaley;
  int galphaEn;
  int fgAlpha;
  int bgAlpha;
  int layer;
};

extern int IMP_OSD_ShowRgn(int handler, int params, int display);
extern int IMP_OSD_CreateRgn(struct RgnInfoSt *info);
extern int IMP_OSD_RegisterRgn(int handler, int grp, struct RgnGrpInfoSt *grpInfo);

char *CenterMark(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  int display = 0;
  if(!strcmp(p, "on")) display = 1;

  int x = 320;
  int y = 180;
  int ch = 0;
  int grp = 0;
  static int handler[16] = {[0 ... 15] = -1};
  static int hn = 0;

  if(display) {
    if(handler[0] >= 0) {
      for(int i = 0; i < hn; i++) {
        IMP_OSD_ShowRgn(handler[i], grp, 1);
      }
    } else {
      struct RgnGrpInfoSt grpInfo;
      grpInfo.show = 1;
      grpInfo.x = 0;
      grpInfo.y = 0;
      grpInfo.scalex = 3.0;
      grpInfo.scaley = 3.0;
      grpInfo.galphaEn = 1;
      grpInfo.fgAlpha = 255;
      grpInfo.bgAlpha = 0;
      grpInfo.layer = 3;

      // vertical / horizontal line
      struct RgnInfoSt info;
      info.type = 1; // line
      info.x1 = 0;
      info.y1 = y;
      info.x2 = x - 3;
      info.y2 = y;
      info.pixfmt = 8;
      info.color = 0xffff0000;
      info.width = 2;
      handler[hn] = IMP_OSD_CreateRgn(&info);
      IMP_OSD_RegisterRgn(handler[hn++], grp, &grpInfo);
      fprintf(stderr, "handler %x\n", handler[0]);

      info.x1 = x + 3;
      info.x2 = x * 2 - 1;
      handler[hn] = IMP_OSD_CreateRgn(&info);
      IMP_OSD_RegisterRgn(handler[hn++], grp, &grpInfo);

      info.x1 = x;
      info.y1 = 0;
      info.x2 = x;
      info.y2 = y - 3;
      handler[hn] = IMP_OSD_CreateRgn(&info);
      IMP_OSD_RegisterRgn(handler[hn++], grp, &grpInfo);

      info.y1 = y + 3;
      info.y2 = y * 2 - 1;
      handler[hn] = IMP_OSD_CreateRgn(&info);
      IMP_OSD_RegisterRgn(handler[hn++], grp, &grpInfo);

      // daiamond1
      info.x1 = x;
      info.y1 = y + 10;
      info.x2 = x + 10;
      info.y2 = y;
      handler[hn] = IMP_OSD_CreateRgn(&info);
      IMP_OSD_RegisterRgn(handler[hn++], grp, &grpInfo);

      info.y1 = y - 10;
      handler[hn] = IMP_OSD_CreateRgn(&info);
      IMP_OSD_RegisterRgn(handler[hn++], grp, &grpInfo);

      info.x2 = x - 10;
      handler[hn] = IMP_OSD_CreateRgn(&info);
      IMP_OSD_RegisterRgn(handler[hn++], grp, &grpInfo);

      info.y1 = y + 10;
      handler[hn] = IMP_OSD_CreateRgn(&info);
      IMP_OSD_RegisterRgn(handler[hn++], grp, &grpInfo);
    }
  } else {
    for(int i = 0; i < hn; i++) {
      if(handler[i]) IMP_OSD_ShowRgn(handler[i], grp, 0);
    }
  }
  return "ok";
}
