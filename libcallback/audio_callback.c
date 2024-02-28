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

static const int AudioDecviceID = 1;
static const int AudioChID = 0;

extern char CommandResBuf[];

typedef struct {
  int samplerate; // Audio sampling rate. 8000 Hz
  int bitwidth; // Audio sampling precision. 16 bit
  int soundmode; // Audio channel mode. 1(mono)
  int frmNum;  // Number of cached frames, range: [2, MAX_AUDIO_FRAME_NUM].
  int numPerFrm; // Number of sample points per frame.
  int chnCnt;  // Number of channels supported.
} IMPAudioIOAttr;

// attribute of the audio input device.
extern int IMP_AI_SetPubAttr(int audioDevId, IMPAudioIOAttr *attr);
extern int IMP_AI_GetPubAttr(int audioDevId, IMPAudioIOAttr *attr);

// AI high pass filtering function.
extern int IMP_AI_DisableHpf();
extern int IMP_AI_EnableHpf(IMPAudioIOAttr *attr);

// AI automatic gain feature.
extern int IMP_AI_DisableAgc();
extern int IMP_AI_EnableAgc(IMPAudioIOAttr *attr, short TargetLevelDbfs, short CompressionGaindB);

// Noise suppression.
extern int IMP_AI_DisableNs();
extern int IMP_AI_EnableNs(IMPAudioIOAttr *attr, int mode);

// Enable audio echo cancellation feature of the specified audio input and audio output.
extern int IMP_AI_DisableAec(int aiDevId, int aiCh);
extern int IMP_AI_EnableAec(int aiDevId, int aiChn, int aoDevId, int aoChn);

// audio input volume. -30 - 120, default: 60
extern int IMP_AI_SetVol(int audioDevId, int aiChn, int aiVol);
extern int IMP_AI_GetVol(int audioDevId, int aiChn, int *vol);

// audio input gain. 0 - 31
extern int IMP_AI_SetGain(int audioDevId, int aiChn, int aiGain);
extern int IMP_AI_GetGain(int audioDevId, int aiChn, int *aiGain);

//alc gain value. 0 - 7
extern int IMP_AI_SetAlcGain(int audioDevId, int aiChn, int aiPgaGain);
extern int IMP_AI_GetAlcGain(int audioDevId, int aiChn, int *aiPgaGain);

struct frames_st {
  void *buf;
  size_t length;
};
typedef int (* framecb)(struct frames_st *);

static uint32_t (*real_local_sdk_audio_set_pcm_frame_callback)(int ch, void *callback);
static void *audio_pcm_cb = NULL;

struct audio_capture_st {
  int card;
  struct pcm *pcm;
  int enable;
};
struct audio_capture_st audio_capture[] = {
  {
    .card = 0,
    .pcm = NULL,
    .enable = 0,
  },
  {
    .card = 2,
    .pcm = NULL,
    .enable = 0,
  },
};

static char *HighPassFilter(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  int ret = -1;
  if(p && !strcmp(p, "off")) {
    ret = IMP_AI_DisableHpf();
  }
  if(p && !strcmp(p, "on")) {
    IMPAudioIOAttr attr;
    ret = IMP_AI_GetPubAttr(AudioDecviceID, &attr);
    if(!ret) ret = IMP_AI_EnableHpf(&attr);
  }
  return ret ? "error" : "ok";
}

static char *AutoGainControl(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";

  int ret = -1;
  if(!strcmp(p, "off")) {
    // ret = IMP_AI_DisableAgc(); // Exception
  } else {
    int targetLevelDbfs = atoi(p);
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    if(p) {
      int compressionGaindB = atoi(p);
      IMPAudioIOAttr attr;
      ret = IMP_AI_GetPubAttr(AudioDecviceID, &attr);
      if(!ret) ret = IMP_AI_EnableAgc(&attr, targetLevelDbfs, compressionGaindB);
    }
  }
  return ret ? "error" : "ok";
}

static char *NoiseSuppression(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";

  int ret = -1;
  if(!strcmp(p, "off")) {
    ret = IMP_AI_DisableNs();
  } else {
    int level = atoi(p);
    IMPAudioIOAttr attr;
    ret = IMP_AI_GetPubAttr(AudioDecviceID, &attr);
    if(!ret) ret = IMP_AI_EnableNs(&attr, level);
  }
  return ret ? "error" : "ok";
}

static char *EchoCancellation(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  int ret = -1;
  if(p && !strcmp(p, "off")) {
    ret = IMP_AI_DisableAec(AudioDecviceID, AudioChID);
  }
  if(p && !strcmp(p, "on")) {
    ret = IMP_AI_EnableAec(AudioDecviceID, AudioChID, AudioDecviceID, AudioChID);
  }
  return ret ? "error" : "ok";
}

static char *Volume(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int vol;
    int ret = IMP_AI_GetVol(AudioDecviceID, AudioChID, &vol);
    if(ret) return "error";
    sprintf(CommandResBuf, "%d\n", vol);
    return CommandResBuf;
  }
  int ret = IMP_AI_SetVol(AudioDecviceID, AudioChID, atoi(p));
  return ret ? "error" : "ok";
}

static char *Gain(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int gain;
    int ret = IMP_AI_GetGain(AudioDecviceID, AudioChID, &gain);
    if(ret) return "error";
    sprintf(CommandResBuf, "%d\n", gain);
    return CommandResBuf;
  }
  int ret = IMP_AI_SetGain(AudioDecviceID, AudioChID, atoi(p));
  return ret ? "error" : "ok";
}

static char *AlcGain(char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) {
    int gain;
    int ret = IMP_AI_GetAlcGain(AudioDecviceID, AudioChID, &gain);
    if(ret) return "error";
    sprintf(CommandResBuf, "%d\n", gain);
    return CommandResBuf;
  }
  int ret = IMP_AI_SetAlcGain(AudioDecviceID, AudioChID, atoi(p));
  return ret ? "error" : "ok";
}

struct CommandTableSt {
  const char *cmd;
  char * (*func)(char *);
};

static struct CommandTableSt AudioCommandTable[] = {
  { "hpf",      &HighPassFilter }, // hpf on/off
  { "agc",      &AutoGainControl }, // agc gainLevel:0-31(dB) maxGain:0-90(dB)
  { "ns",       &NoiseSuppression }, // ns off/0-3
  { "aec",      &EchoCancellation }, // aec on/off
  { "vol",      &Volume }, // vol -30 - 120
  { "gain",     &Gain }, // gain 0 - 31
  { "alc",      &AlcGain }, // alc 0-7
};

char *AudioCapture(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(p) {
    for(int i = 0; i < sizeof(AudioCommandTable) / sizeof(struct CommandTableSt); i++) {
      if(!strcmp(p, AudioCommandTable[i].cmd)) return (*AudioCommandTable[i].func)(tokenPtr);
    }
  }

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

static uint32_t audio_pcm_capture(struct frames_st *frames) {

  const struct pcm_config config = {
    .channels = 1,
    .rate = 8000,
    .format = PCM_FORMAT_S16_LE,
    .period_size = 320,
    .period_count = 16,
    .start_threshold = 0,
    .silence_threshold = 0,
    .silence_size = 0,
    .stop_threshold = 0,
  };

  for(int ch = 0; ch < 2; ch++) {
    if(!audio_capture[ch].pcm) {
      audio_capture[ch].pcm = pcm_open(audio_capture[ch].card, 1, PCM_OUT | PCM_MMAP, &config);
      if(audio_capture[ch].pcm == NULL) {
          fprintf(stderr, "failed to allocate memory for PCM%d\n", ch);
      } else if(!pcm_is_ready(audio_capture[ch].pcm)) {
        fprintf(stderr, "failed to open PCM%d : %s\n", ch, pcm_get_error(audio_capture[ch].pcm));
        pcm_close(audio_capture[ch].pcm);
        audio_capture[ch].pcm = NULL;
      }
    }

    if(audio_capture[ch].pcm && audio_capture[ch].enable) {
      if(pcm_mmap_avail(audio_capture[ch].pcm) >= config.period_size * config.period_count / 4) {
        int err = pcm_writei(audio_capture[ch].pcm, frames->buf, pcm_bytes_to_frames(audio_capture[ch].pcm, frames->length));
        if(err < 0) fprintf(stderr, "pcm_writei ch%d err=%d\n", ch, err);
      } else {
        fprintf(stderr, "[audio] drop packet: ch%d %d\n", ch, frames->length);
        pcm_prepare(audio_capture[ch].pcm);
      }
    }
  }
  return ((framecb)audio_pcm_cb)(frames);
}

uint32_t local_sdk_audio_set_pcm_frame_callback(int ch, void *callback) {

  if(ch == 0) {
    audio_pcm_cb = callback;
    callback = audio_pcm_capture;
  }
  return real_local_sdk_audio_set_pcm_frame_callback(ch, callback);
}

static void __attribute ((constructor)) audio_callback_init(void) {

  real_local_sdk_audio_set_pcm_frame_callback = dlsym(dlopen("/system/lib/liblocalsdk.so", RTLD_LAZY), "local_sdk_audio_set_pcm_frame_callback");
}
