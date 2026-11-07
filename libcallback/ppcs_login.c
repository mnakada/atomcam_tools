#include <stdio.h>
#include <dlfcn.h>

// iCamera_app (shangyun.c) polls PPCS_LoginStatus_Check and keeps the result. alarm_event_handle drops
// every alarm while the camera is not logged in to the P2P server, so nothing is recorded to
// alarm_record while the router has no internet (#142). Report
// "logged in" when the server cannot be reached. Remote viewing from the app needs the server anyway, so it is not affected.
static int (*real_PPCS_LoginStatus_Check)(char *bLoginStatus);

int PPCS_LoginStatus_Check(char *bLoginStatus) {

  if(!real_PPCS_LoginStatus_Check) real_PPCS_LoginStatus_Check = dlsym(dlopen("libPPCS_API.so", RTLD_LAZY), "PPCS_LoginStatus_Check");
  if(!real_PPCS_LoginStatus_Check) return -1;
  int ret = real_PPCS_LoginStatus_Check(bLoginStatus);
  if(ret || !bLoginStatus) return ret;
  // log each change, so that tools.log shows when the P2P login was lost and came back
  static int faked = 0;
  if(*bLoginStatus != 1) {
    if(!faked) fprintf(stderr, "[PPCS] not logged in to the P2P server (%d), report logged in\n", *bLoginStatus);
    faked = 1;
    *bLoginStatus = 1;
  } else {
    if(faked) fprintf(stderr, "[PPCS] logged in to the P2P server again\n");
    faked = 0;
  }
  return ret;
}
