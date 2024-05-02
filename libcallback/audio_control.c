#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const int AudioDecviceID = 1;
static const int AudioChID = 0;

extern char CommandResBuf[];

typedef struct {
  int samplerate; // Audio sampling rate.
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

extern char *AudioCapture(int fd, char *p, char *tokenPtr);

static char *HighPassFilter(char *tokenPtr);
static char *AutoGainControl(char *tokenPtr);
static char *NoiseSuppression(char *tokenPtr);
static char *EchoCancellation(char *tokenPtr);
static char *Volume(char *tokenPtr);
static char *Gain(char *tokenPtr);
static char *AlcGain(char *tokenPtr);

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

char *AudioCommand(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(p) {
    for(int i = 0; i < sizeof(AudioCommandTable) / sizeof(struct CommandTableSt); i++) {
      if(!strcmp(p, AudioCommandTable[i].cmd)) return (*AudioCommandTable[i].func)(tokenPtr);
    }
  }
  return AudioCapture(fd, p, tokenPtr);
}

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
