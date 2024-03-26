#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#define JPEG_TASK_SIZE 8
#define JPEG_TASK_MASK (JPEG_TASK_SIZE - 1)

struct channelConfigSt {
  uint dummy[4];
  int state;
  int encoder;
};

struct JpegTaskSt {
  int fd;
  int header;
  int ch;
};

extern struct channelConfigSt *get_enc_chn_config(int ch);
extern int get_video_run_state(int ch);
extern void video_param_set_mutex_lock();
extern int IMP_Encoder_StartRecvPic(int ch);
extern int IMP_Encoder_PollingStream(int ch, int timeoutMSec);
extern int IMP_Encoder_GetStream(int ch, uint *stream, int);
extern int IMP_Encoder_ReleaseStream(int ch, int *stream);
extern int IMP_Encoder_StopRecvPic(int ch);
extern int save_jpeg(int fd, int *stream);
extern void video_param_set_mutex_unlock();
extern void CommandResponse(int fd, const char *res);
extern char CommandResBuf[];

static const char *HttpResHeader = "Cache-Control: no-cache\nContent-Type: image/jpeg\n\n";
static const char *HttpErrorHeader = "Cache-Control: no-cache\nStatus: 503\n\n";
static pthread_mutex_t JpegDataMutex = PTHREAD_MUTEX_INITIALIZER;
static struct JpegTaskSt JpegTask[JPEG_TASK_SIZE];
static int FirstTask = 0;
static int LastTask = 0;

static int DebugSequence = -1;

char *JpegCapture(int fd, char *tokenPtr) {

  if(FirstTask == (LastTask + 1) & JPEG_TASK_MASK) {
    fprintf(stderr, "[command] jpeg capture error %d\n", fd);
    write(fd, HttpErrorHeader, strlen(HttpErrorHeader));
    CommandResponse(fd, "error : jpeg capture error");
    return NULL;
  }

  JpegTask[LastTask].fd = fd;
  JpegTask[LastTask].ch = 0;
  JpegTask[LastTask].header = 1;
  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(p && (!strcmp(p, "0") || !strcmp(p, "1"))) {
    JpegTask[LastTask].ch = atoi(p);
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  }
  if(p && !strcmp(p, "-n")) JpegTask[LastTask].header = 0;
  if(p && !strcmp(p, "clear")) {
    FirstTask = LastTask = 0;
    return "OK";
  }
  if(p && !strcmp(p, "status")) {
    snprintf(CommandResBuf, 255, "FirstTask %d LastTask %d state %d FT %d %d %d mutex %d", FirstTask, LastTask, DebugSequence, JpegTask[FirstTask].fd, JpegTask[FirstTask].ch, JpegTask[FirstTask].header, JpegDataMutex);
    fprintf(stderr, "FirstTask %d LastTask %d state %d FT %d %d %d mutex %d", FirstTask, LastTask, DebugSequence, JpegTask[FirstTask].fd, JpegTask[FirstTask].ch, JpegTask[FirstTask].header, JpegDataMutex);
    return CommandResBuf;
  }
  if(p && !strcmp(p, "unlock")) {
    pthread_mutex_unlock(&JpegDataMutex);
    return "OK";
  }
  LastTask = (LastTask + 1) & JPEG_TASK_MASK;
  pthread_mutex_unlock(&JpegDataMutex);
  return NULL;
}

static int GetJpegData(int fd, int ch, int header) {

  DebugSequence = 11;
  struct channelConfigSt *chConfig = get_enc_chn_config(ch);
  if (!chConfig->state) {
    fprintf(stderr, "[command] jpeg err: ch%d is not enable jpeg!\n", ch);
    return -1;
  }
  DebugSequence = 12;
  int state = get_video_run_state(ch);
  DebugSequence = 13;
  if (state < 5) {
    fprintf(stderr, "[command] jpeg err: U should call 'video_run' before this func\n");
    return -1;
  }
  DebugSequence = 14;

  video_param_set_mutex_lock(1);
  DebugSequence = 15;
  int encoder = chConfig->encoder;
  int ret = 0;

  if(IMP_Encoder_StartRecvPic(encoder) < 0) {
    fprintf(stderr, "[command] jpeg err: IMP_Encoder_StartRecvPic(%d) failed\n", encoder);
    ret = -1;
    goto error1;
  }
  DebugSequence = 16;

  if(IMP_Encoder_PollingStream(encoder, 2000) < 0) {
    fprintf(stderr, "[command] jpeg err: Polling stream(chn%d) timeout\n", encoder);
    ret = -1;
    goto error2;
  }
  DebugSequence = 17;

  uint stream[17];
  memset(stream, 0, 60);
  if(IMP_Encoder_GetStream(encoder, stream, 1) < 0) {
    fprintf(stderr, "[command] jpeg err: IMP_Encoder_GetStream(chn%d) failed\n", encoder);
    ret = -1;
    goto error2;
  }
  DebugSequence = 18;

  if(header) write(fd, HttpResHeader, strlen(HttpResHeader));
  DebugSequence = 19;
  if(save_jpeg(fd, stream) < 0) {
    fprintf(stderr, "[command] jpeg err: save_jpeg(%d) failed\n", fd);
    ret = -2;
  }
  DebugSequence = 20;
  IMP_Encoder_ReleaseStream(encoder, stream);

error2:
  DebugSequence = 21;
  if(IMP_Encoder_StopRecvPic(encoder) < 0) {
    fprintf(stderr, "[command] jpeg err: IMP_Encoder_StopRecvPic(chn%d) failed\n", encoder);
  }

error1:
  DebugSequence = 22;
  video_param_set_mutex_unlock(1);
  DebugSequence = 23;
  if((ret == -1) && header) write(fd, HttpErrorHeader, strlen(HttpErrorHeader));
  DebugSequence = 24;
  return ret;
}

static void *JpegCaptureThread() {

  while(1) {
    DebugSequence = 1;
    pthread_mutex_lock(&JpegDataMutex);
    DebugSequence = 2;
    while(FirstTask != LastTask) {
      DebugSequence = 3;
      int res = GetJpegData(JpegTask[FirstTask].fd, JpegTask[FirstTask].ch, JpegTask[FirstTask].header);
      DebugSequence = 4;
      CommandResponse(JpegTask[FirstTask].fd, res >= 0 ? "" : "error");
      FirstTask = (FirstTask + 1) & JPEG_TASK_MASK;
      DebugSequence = 5;
    }
    DebugSequence = 6;
  }
}

static void __attribute ((constructor)) JpegInit(void) {

  pthread_mutex_lock(&JpegDataMutex);
  pthread_t thread;
  if(pthread_create(&thread, NULL, JpegCaptureThread, NULL)) {
    fprintf(stderr, "pthread_create error\n");
    pthread_mutex_unlock(&JpegDataMutex);
    return;
  }
}
