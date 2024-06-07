#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

extern char CommandResBuf[];

extern int local_sdk_motor_get_position(float *step,float *angle);
extern int local_sdk_motor_move_abs_angle(float pan, float tilt, int speed, void (*done)(float a, float b), void (*canceled)(void), int mode);
extern int IMP_ISP_Tuning_GetISPHflip(int *pmode);
extern int IMP_ISP_Tuning_GetISPVflip(int *pmode);
extern void CommandResponse(int fd, const char *res);
extern int swing;

int MotorFd = 0;
struct timeval MotorLastMovedTime = { 0, 0 };

static void motor_move_done(float pan, float tilt) {

  if(MotorFd) {
    int vflip, hflip;
    IMP_ISP_Tuning_GetISPHflip(&hflip);
    IMP_ISP_Tuning_GetISPVflip(&vflip);
    if(hflip) pan = 355.0 - pan;
    if(vflip) tilt = 180.0 - tilt;
    sprintf(CommandResBuf, "%f %f %d %d\n", pan, tilt, hflip, vflip);
    CommandResponse(MotorFd, CommandResBuf);
  }
  MotorFd = 0;
  struct timeval tv;
  gettimeofday(&MotorLastMovedTime, NULL);
}

static void motor_move_canceled() {

  if(MotorFd) CommandResponse(MotorFd, "error : canceled");
  MotorFd = 0;
  gettimeofday(&MotorLastMovedTime, NULL);
}

char *MotorMove(int fd, char *tokenPtr) {

  if(!swing) return "error";
  
  int vflip, hflip;
  IMP_ISP_Tuning_GetISPHflip(&hflip);
  IMP_ISP_Tuning_GetISPVflip(&vflip);

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    float pan; // 0-355
    float tilt; // 0-180
    int ret = local_sdk_motor_get_position(&pan, &tilt);
    if(!ret) {
      if(hflip) pan = 355.0 - pan;
      if(vflip) tilt = 180.0 - tilt;
      sprintf(CommandResBuf, "%f %f %d %d\n", pan, tilt, hflip, vflip);
    } else {
      return "error";
    }
    return CommandResBuf;
  }
  float pan = atof(p); // 0-355
  if((pan < 0.0) || (pan > 355.0)) return "error";
  if(hflip) pan = 355.0 - pan;

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  float tilt = atof(p); // 0-180
  if((tilt < 0.0) || (tilt > 180.0)) return "error";
  if(vflip) tilt = 180.0 - tilt;

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  int speed = 9; // 1: low - 9: high speed
  if(p) speed = atoi(p);
  if(speed < 1) speed = 1;
  if(speed > 9) speed = 9;

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  int pri = 2; // 0: high - 3: low
  if(p) pri = atoi(p);
  if(pri < 0) pri = 0;
  if(pri > 3) pri = 3;

  if(MotorFd) {
    CommandResponse(fd, "error : multiple request error");
  } else {
    MotorFd = fd;
    int res = local_sdk_motor_move_abs_angle(pan, tilt, speed, &motor_move_done, &motor_move_canceled, pri);
  }
  return NULL;
}
