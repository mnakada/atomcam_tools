#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern int local_sdk_speaker_clean_buf_data();
extern int local_sdk_speaker_set_volume(int volume);
extern int local_sdk_speaker_feed_pcm_data(unsigned char *buf, int size);
extern int local_sdk_speaker_set_ap_mode(int mode);
extern int local_sdk_speaker_set_pa_mode(int mode);
extern int *get_speaker_params();
extern int get_speaker_params_run_state();
extern int IMP_AO_QueryChnStat(unsigned int a, unsigned int b, int *buf);
extern void CommandResponse(int fd, const char *res);

static int (*set_pa_mode)(int mode);
static pthread_mutex_t AudioPlayMutex = PTHREAD_MUTEX_INITIALIZER;
static int AudioPlayFd = -1;
static char waveFile[256];
static int Volume = 0;

int PlayPCM(char *file, int vol) {

  static const int waveHeaderLength = 36;
  static const int bufLength = 640;
  unsigned char buf[bufLength];
  const unsigned char cmpHeader[] = {
    0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45, 0x66, 0x6d, 0x74, 0x20,
    0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x40, 0x1f, 0x00, 0x00, 0x80, 0x3e, 0x00, 0x00,
    0x02, 0x00, 0x10, 0x00
  };
  const unsigned char cmpData[] = { 0x64, 0x61, 0x74, 0x61 };

  printf("[command] aplay: file:%s\n", file);
  FILE *fp = fopen(file, "rb");
  if(fp == NULL) {
    fprintf(stderr, "[command] aplay err: fopen %s failed!\n", file);
    return -1;
  }
  size_t size = fread(buf, 1, sizeof(cmpHeader), fp);
  if(size != sizeof(cmpHeader)) {
    fprintf(stderr, "[command] aplay err: header size error\n");
    fclose(fp);
    return -1;
  }
  buf[4] = buf[5] = buf[6] = buf[7] = 0;
  if(memcmp(buf, cmpHeader, sizeof(cmpHeader))) {
    fprintf(stderr, "[command] aplay err: header error\n");
    fclose(fp);
    return -1;
  }
  local_sdk_speaker_clean_buf_data();
  local_sdk_speaker_set_volume(vol);
  set_pa_mode(3);
  while(!feof(fp)) {
    size = fread(buf, 1, 8, fp);
    if(size <= 0) break;
    if(size != 8) {
      fprintf(stderr, "[command] aplay err: chunk header size error %d %x\n", size, ftell(fp));
      fclose(fp);
      return -1;
    }
    int chunkSize = (buf[7] << 24) | (buf[6] << 16) | (buf[5] << 8) | buf[4];
    if(memcmp(buf, cmpData, sizeof(cmpData))) {
      fseek(fp, chunkSize, SEEK_CUR);
      continue;
    }
    while(!feof(fp) && (chunkSize > 0)) {
      size = fread(buf, 1, bufLength, fp);
      if (size <= 0) break;
      if(size > chunkSize) size = chunkSize;
      chunkSize -= size;
      while(local_sdk_speaker_feed_pcm_data(buf, size)) usleep(100 * 1000);
    }
  }
  fclose(fp);
  int *params = get_speaker_params();
  while(1) {
    int runState = get_speaker_params_run_state();
    if(runState != 3) break;
    int buf[3];
    int stat = IMP_AO_QueryChnStat(params[7], params[8], buf);
    if(stat || !buf[2]) break;
    usleep(100 * 1000);
  }
  usleep(500 * 1000);
  set_pa_mode(0);
  return 0;
}

static void *AudioPlayThread() {

  while(1) {
    pthread_mutex_lock(&AudioPlayMutex);
    if(AudioPlayFd >= 0) {
      int res = PlayPCM(waveFile, Volume);
      CommandResponse(AudioPlayFd, res ? "error" : "ok");
    }
    AudioPlayFd = -1;
  }
}

char *AudioPlay(int fd, char *tokenPtr) {

  if(AudioPlayFd >= 0) {
    fprintf(stderr, "[command] aplay err: Previous file is still playing. %d %d\n", AudioPlayFd, fd);
    return "error";
  }

  if(!set_pa_mode) {
    fprintf(stderr, "[command] aplay err: local_sdk_speaker_set_[ap]_mode not found.\n", AudioPlayFd, fd);
    return "error";
  }

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    fprintf(stderr, "[command] aplay err: usage : aplay <wave file> [<volume>]\n");
    return "error";
  }
  strncpy(waveFile, p, 255);

  p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  Volume = 40;
  if(p) Volume = atoi(p);

  AudioPlayFd = fd;
  pthread_mutex_unlock(&AudioPlayMutex);
  return NULL;
}

static void __attribute ((constructor)) AudioPlayInit(void) {

  set_pa_mode = local_sdk_speaker_set_ap_mode;
  if(!set_pa_mode) set_pa_mode = local_sdk_speaker_set_pa_mode;
  pthread_mutex_lock(&AudioPlayMutex);
  pthread_t thread;
  if(pthread_create(&thread, NULL, AudioPlayThread, NULL)) {
    fprintf(stderr, "pthread_create error\n");
    pthread_mutex_unlock(&AudioPlayMutex);
    return;
  }
}
