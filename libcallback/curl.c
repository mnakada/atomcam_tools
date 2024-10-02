#include <stdio.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

extern void Dump(const char *str, void *start, int size);
extern char CommandResBuf[];
extern int wyze;

typedef void CURL;
typedef int CURLcode;
typedef long long curl_off_t;
typedef enum {
  HTTPREQ_NONE,
  HTTPREQ_GET,
  HTTPREQ_POST,
  HTTPREQ_POST_FORM,
  HTTPREQ_POST_MIME,
  HTTPREQ_PUT,
  HTTPREQ_HEAD,
  HTTPREQ_OPTIONS,
  HTTPREQ_LAST
} Curl_HttpReq;

static const int CURL_OK = 0;
static const int CURLOPT_URL = 10000 + 2;
const char *methods[] = {
  "NONE", "GET", "POST", "POST_FORM", "POST_MIME", "PUT", "HEAD", "OPTIONS", "LAST", ""
};
static const char *AlarmPathAtom = "/device/v1/alarm/add";
static const char *AlarmPathWyze = "/device/alarm/upload_alarm";
static const char *DummyRes = "{\"ts\":1641390551000,\"code\":\"1\",\"msg\":\"\",\"data\":{\"alarm_file_list\":[{\"file_type\":1,\"file_suffix\":\"jpg\",\"file_url\":\"https://localhost/hoge.jpg\",\"encryption_algorithm\":0,\"encryption_password\":\"\"},{\"file_type\":2,\"file_suffix\":\"mp4\",\"file_url\":\"https://localhost/fuga.mp4\",\"encryption_algorithm\":0,\"encryption_password\":\"\"}]}}";
static const char *DummyHost = "https://localhost/";

typedef int (*curl_write_callback)(char *buffer, int size, int nitems, void *outstream);

struct SessionHandleAtom {
  unsigned char padding5[0x244];
  Curl_HttpReq httpreq; // offset 0x804
  unsigned char padding6[0x298];
  char *url; // offset 0xaa0
  unsigned char padding8[0x3ec];
  int httpcode; // offset 0xe90
};

struct SessionHandleWyze {
  unsigned char padding5[0x254];
  Curl_HttpReq httpreq; // offset 0x814
  unsigned char padding6[0x2f8];
  char *url; // offset 0xb10
  unsigned char padding8[0x484];
  int httpcode; // offset 0xf98
};

struct SessionHandle {
  unsigned char padding0[0x580];
  void *out; // offset 0x580
  unsigned char padding2[0x28];
  void *postfields; // offset 0x5ac
  unsigned char padding3[0x8];
  curl_off_t postfieldsize; // offset offset 0x5b8
  union {
    struct SessionHandleAtom atom;
    struct SessionHandleWyze wyze;
  };
};

static CURLcode (*original_curl_easy_perform)(CURL *curl);
int curl_minimum_alarm_cycle = 0;
static int disable = 0;
static int debug = 0;

static void __attribute ((constructor)) curl_hook_init(void) {

  original_curl_easy_perform = dlsym(dlopen("/thirdlib/libcurl.so", RTLD_LAZY), "curl_easy_perform");
}

char *CurlConfig(int fd, char *tokenPtr) {

  char *p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  if(!p) return "error";
  if(!strcasecmp(p, "debug")) {
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    if(!p) {
      snprintf(CommandResBuf, 255, "%d", debug);
      return CommandResBuf;
    }
    debug = atoi(p);
    return "ok";
  }

  if(!strcasecmp(p, "upload")) {
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
    if(!p) return disable ? "disable" : "enable";

    if(!strcasecmp(p, "disable")) {
      disable = 1;
      printf("[curl] curl upload disable\n");
      return "ok";
    }
    if(!strcasecmp(p, "enable")) {
      disable = 0;
      printf("[curl] curl upload enable\n");
      return "ok";
    }
    return "error";
  }
  return "error";
}

CURLcode curl_easy_perform(struct SessionHandle *data) {

  unsigned int ra = 0;
  asm volatile(
    "ori %0, $31, 0\n"
    : "=r"(ra)
  );

  int method = wyze ? data->wyze.httpreq : data->atom.httpreq;
  if(method > HTTPREQ_LAST) method = HTTPREQ_LAST;
  char *url = wyze ? data->wyze.url : data->atom.url;

  printf("[curl] %s %s\n", methods[method], url);
  if(debug) fprintf(stderr, "[curl] %s %s ra=0x%08x\n", methods[method], url, ra);
  if(data->postfields) {
    if(data->postfieldsize > 0) {
      if(debug > 2) Dump("[curl] post", data->postfields, data->postfieldsize);
    } else {
      if(debug) fprintf(stderr, "[curl] post : %s\n", (char *)data->postfields);
      if(debug > 2) Dump("[curl] data", data, sizeof(struct SessionHandle));
    }
  }

  const char *alarmPath = wyze ? AlarmPathWyze : AlarmPathAtom;
  if(url && !strcmp(url + strlen(url) - strlen(alarmPath), alarmPath)) {
    static time_t lastAccess = 0;
    struct timeval now;
    gettimeofday(&now, NULL);
    if(disable || (now.tv_sec - lastAccess < curl_minimum_alarm_cycle)) {
      if(disable) {
        printf("[curl] Discard by disable upload.\n");
        if(debug) fprintf(stderr, "[curl] Discard by disable upload.\n");
      } else {
        printf("[curl] Discard by short cycle alarms.\n");
        if(debug) fprintf(stderr, "[curl] Discard by short cycle alarms.\n");
      }
      memcpy(data->out, DummyRes, strlen(DummyRes));
      goto curl_ok;
    }
    CURLcode res = original_curl_easy_perform(data);
    if(!res) lastAccess = now.tv_sec;
    return res;
  }

  if(url && !strncmp(url, DummyHost, strlen(DummyHost))) {
    printf("[curl] skip http-post.\n");
    if(debug) fprintf(stderr, "[curl] skip http-post.\n");
    goto curl_ok;
  }

  CURLcode res = original_curl_easy_perform(data);
  if(data->out) printf("[curl] res : %s\n", (char *)data->out);
  if(debug) fprintf(stderr, "[curl] ret: %d\n", res);
  return res;

curl_ok:
  if(wyze) {
    data->wyze.httpcode = 200;
  } else {
    data->atom.httpcode = 200;
  }
  return CURL_OK;
}
