#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <tinyalsa/pcm.h>

extern int wyze;

struct frames_st {
  void *buf;
  size_t length;
};
typedef int (* framecb)(struct frames_st *);

static int (*real_local_sdk_audio_set_pcm_frame_callback)(int ch, void *callback);
static int audio_pcm_capture0(struct frames_st *frames);
static int audio_pcm_capture1(struct frames_st *frames);

struct audio_capture_st {
  int card;
  struct pcm *pcm;
  int enable;
  framecb capture;
  framecb callback;
};
struct audio_capture_st audio_capture[] = {
  {
    .card = 0,
    .pcm = NULL,
    .enable = 0,
    .capture = audio_pcm_capture0,
  },
  {
    .card = 2,
    .pcm = NULL,
    .enable = 0,
    .capture = audio_pcm_capture1,
  },
};

static const struct pcm_config AudioConfig_atomcam[] = {
  {
    .channels = 1,
    .rate = 8000,
    .format = PCM_FORMAT_S16_LE,
    .period_size = 320,
    .period_count = 16,
    .start_threshold = 320,
    .silence_threshold = 0,
    .silence_size = 0,
    .stop_threshold = 320 * 4,
  },
  {
    .channels = 1,
    .rate = 8000,
    .format = PCM_FORMAT_S16_LE,
    .period_size = 320,
    .period_count = 16,
    .start_threshold = 320,
    .silence_threshold = 0,
    .silence_size = 0,
    .stop_threshold = 320 * 4,
  },
};

static const struct pcm_config AudioConfig_wyzecam[] = {
  {
    .channels = 1,
    .rate = 24000,
    .format = PCM_FORMAT_S16_LE,
    .period_size = 640,
    .period_count = 16,
    .start_threshold = 640,
    .silence_threshold = 0,
    .silence_size = 0,
    .stop_threshold = 640 * 4,
  },
  {
    .channels = 1,
    .rate = 8000,
    .format = PCM_FORMAT_S16_LE,
    .period_size = 320,
    .period_count = 16,
    .start_threshold = 320,
    .silence_threshold = 0,
    .silence_size = 0,
    .stop_threshold = 320 * 4,
  },
};

static const struct pcm_config *AudioConfig = AudioConfig_atomcam;

char *AudioCapture(int fd, char *p, char *tokenPtr) {

  int ch = 0;
  if(p && (!strcmp(p, "0") || !strcmp(p, "1"))) {
    ch = atoi(p);
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  }
  if(!p) {
    if(!audio_capture[ch].pcm) return "disabled";
    return audio_capture[ch].enable ? "on" : "off";
  }
  if(!strcmp(p, "on")) {
    audio_capture[ch].enable = 1;
    if(audio_capture[ch].pcm) pcm_start(audio_capture[ch].pcm);
    printf("[command] audio %d capute on\n", ch);
    return "ok";
  }
  if(!strcmp(p, "off")) {
    audio_capture[ch].enable = 0;
    if(audio_capture[ch].pcm) pcm_stop(audio_capture[ch].pcm);
    printf("[command] audio %d capute off\n", ch);
    return "ok";
  }
  return "error";
}

static int audio_pcm_capture(int ch, struct frames_st *frames) {

  if(!audio_capture[ch].pcm) {
    audio_capture[ch].pcm = pcm_open(audio_capture[ch].card, 1, PCM_OUT | PCM_MMAP, &AudioConfig[ch]);
    if(audio_capture[ch].pcm == NULL) {
        fprintf(stderr, "failed to allocate memory for PCM%d\n", ch);
    } else if(!pcm_is_ready(audio_capture[ch].pcm)) {
      fprintf(stderr, "failed to open PCM%d : %s\n", ch, pcm_get_error(audio_capture[ch].pcm));
      pcm_close(audio_capture[ch].pcm);
      audio_capture[ch].pcm = NULL;
    }
  }

  if(audio_capture[ch].pcm && audio_capture[ch].enable) {
    int availLength = pcm_mmap_avail(audio_capture[ch].pcm);
    if(availLength >= frames->length) {
      int err = pcm_writei(audio_capture[ch].pcm, frames->buf, pcm_bytes_to_frames(audio_capture[ch].pcm, frames->length));
      if(err < 0) fprintf(stderr, "pcm_writei ch%d err=%d\n", ch, err);
    } else {
      fprintf(stderr, "[audio] drop packet: ch%d %d,%d\n", ch, availLength, frames->length);
      pcm_prepare(audio_capture[ch].pcm);
    }
  }
  return (audio_capture[ch].callback)(frames);
}

static int audio_pcm_capture0(struct frames_st *frames) {
  return audio_pcm_capture(0, frames);
}

static int audio_pcm_capture1(struct frames_st *frames) {
  return audio_pcm_capture(1, frames);
}

int local_sdk_audio_set_pcm_frame_callback(int ch, void *callback) {

  if((ch == 0) || (ch == 1)) {
    if(!audio_capture[ch].callback) {
      audio_capture[ch].callback = callback;
      callback = audio_capture[ch].capture;
    }
  }
  return real_local_sdk_audio_set_pcm_frame_callback(ch, callback);
}

static void __attribute ((constructor)) audio_callback_init(void) {

  if(wyze) AudioConfig = AudioConfig_wyzecam;

  real_local_sdk_audio_set_pcm_frame_callback = dlsym(dlopen("/system/lib/liblocalsdk.so", RTLD_LAZY), "local_sdk_audio_set_pcm_frame_callback");
}
