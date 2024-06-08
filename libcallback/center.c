#include <stdio.h>
#include <string.h>
#include <stdlib.h>

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

extern int IMP_OSD_ShowRgn(int handle, int params, int display);
extern int IMP_OSD_CreateRgn(struct RgnInfoSt *info);
extern int IMP_OSD_RegisterRgn(int handle, int grp, struct RgnGrpInfoSt *grpInfo);
int display = 0;

char *CenterMark(int fd, char *tokenPtr) {

  static const int Grp = 0;
  static const int ViewWidth = 640;
  static const int ViewHeight = 360;
  int x = ViewWidth / 2;
  int y = ViewHeight / 2;
  unsigned int color = 0xffffa060;
  int width = 2;
  static int handle[16] = {[0 ... 15] = -1};
  static int handleNum = 0;

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    return display ? "on" : "off";
  }
  if(!strcmp(p, "on")) {
    display = 1;
  } else if(!strcmp(p, "off")) {
    display = 0;
  }

  if(display) {
    if(handleNum > 0) {
      for(int i = 0; i < handleNum; i++) {
        IMP_OSD_ShowRgn(handle[i], Grp, display);
      }
    } else {
      struct RgnGrpInfoSt grpInfo;
      grpInfo.show = display;
      grpInfo.x = 0;
      grpInfo.y = 0;
      grpInfo.scalex = 3.0; // 1920 / 640 = 3
      grpInfo.scaley = 3.0; // 1080 / 360 = 3
      grpInfo.galphaEn = 0;
      grpInfo.fgAlpha = 0;
      grpInfo.bgAlpha = 0;
      grpInfo.layer = 3;

      struct RgnInfoSt info;
      info.type = 1; // line
      info.pixfmt = 8;
      info.color = color; // red
      info.width = width;

      // vertical / horizontal line
      info.x1 = 0;
      info.y1 = y;
      info.x2 = x - 3;
      info.y2 = y;
      IMP_OSD_RegisterRgn(handle[handleNum++] = IMP_OSD_CreateRgn(&info), Grp, &grpInfo);

      info.x1 = x + 3;
      info.x2 = ViewWidth - 1;
      IMP_OSD_RegisterRgn(handle[handleNum++] = IMP_OSD_CreateRgn(&info), Grp, &grpInfo);

      info.x1 = x;
      info.y1 = 0;
      info.x2 = x;
      info.y2 = y - 3;
      IMP_OSD_RegisterRgn(handle[handleNum++] = IMP_OSD_CreateRgn(&info), Grp, &grpInfo);

      info.y1 = y + 3;
      info.y2 = ViewHeight - 1;
      IMP_OSD_RegisterRgn(handle[handleNum++] = IMP_OSD_CreateRgn(&info), Grp, &grpInfo);

      // daiamond1
      info.x1 = x;
      info.y1 = y + 10;
      info.x2 = x + 10;
      info.y2 = y;
      IMP_OSD_RegisterRgn(handle[handleNum++] = IMP_OSD_CreateRgn(&info), Grp, &grpInfo);

      info.y1 = y - 10;
      IMP_OSD_RegisterRgn(handle[handleNum++] = IMP_OSD_CreateRgn(&info), Grp, &grpInfo);

      info.x2 = x - 10;
      IMP_OSD_RegisterRgn(handle[handleNum++] = IMP_OSD_CreateRgn(&info), Grp, &grpInfo);

      info.y1 = y + 10;
      IMP_OSD_RegisterRgn(handle[handleNum++] = IMP_OSD_CreateRgn(&info), Grp, &grpInfo);
    }
  } else {
    for(int i = 0; i < handleNum; i++) {
      if(handle[i]) IMP_OSD_ShowRgn(handle[i], Grp, display);
    }
  }
  return "ok";
}
