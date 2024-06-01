#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <errno.h>

static const unsigned short CommandPort = 4000;
static int SelfPipe[2];

extern char *JpegCapture(int fd, char *tokenPtr);
extern char *VideoCommand(int fd, char *tokenPtr);
extern char *AudioCommand(int fd, char *tokenPtr);
extern char *MotorMove(int fd, char *tokenPtr);
extern char *WaitMotion(int fd, char *tokenPtr);
extern char *NightLight(int fd, char *tokenPtr);
extern char *AudioPlay(int fd, char *tokenPtr);
extern char *CurlConfig(int fd, char *tokenPtr);
extern char *Timelapse(int fd, char *tokenPtr);
extern char *MP4Write(int fd, char *tokenPtr);
extern char *AlarmInterval(int fd, char *tokenPtr);
extern char *UserConfig(int fd, char *tokenPtr);
extern char *AlarmConfig(int fd, char *tokenPtr);
extern char *CenterMark(int fd, char *tokenPtr);

char *CommandResBuf[256];
int wyze = 0;

struct CommandTableSt {
  const char *cmd;
  char * (*func)(int, char *);
};

struct CommandTableSt CommandTable[] = {
  { "video",      &VideoCommand },
  { "audio",      &AudioCommand },
  { "jpeg",       &JpegCapture },
  { "move",       &MotorMove },
  { "waitMotion", &WaitMotion },
  { "night",      &NightLight },
  { "aplay",      &AudioPlay },
  { "curl",       &CurlConfig },
  { "timelapse",  &Timelapse },
  { "mp4write",   &MP4Write },
  { "alarm",      &AlarmInterval },
  { "config",     &UserConfig },
  { "alarmConfig",&AlarmConfig },
  { "center",     &CenterMark },
};

void CommandResponse(int fd, const char *res) {

  if(fd < 0) return;
  unsigned char buf[256];
  buf[0] = strlen(res) + 1;
  buf[1] = fd;
  strncpy((char *)buf + 2, res, 253);
  write(SelfPipe[1], &buf, buf[0] + 2);
}

static void *CommandThread(void *arg) {

  static const int MaxConnect = 255;
  int maxFd = 0;
  fd_set targetFd;

  int listenSocket = socket(AF_INET, SOCK_STREAM, 0);
  if(listenSocket < 0) {
    fprintf(stderr, "socket : %s\n", strerror(errno));
    return NULL;
  }
  int sock_optval = 1;
  if(setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR,
                &sock_optval, sizeof(sock_optval)) == -1) {
    fprintf(stderr, "setsockopt : %s\n", strerror(errno));
    close(listenSocket);
    return NULL;
  }

  struct sockaddr_in saddr;
  saddr.sin_family = AF_INET;
  saddr.sin_port = htons(CommandPort);
  saddr.sin_addr.s_addr = htonl(INADDR_ANY);
  if(bind(listenSocket, (struct sockaddr *)&saddr, sizeof(saddr)) < 0) {
    fprintf(stderr, "bind : %s\n", strerror(errno));
    close(listenSocket);
    return NULL;
  }

  if(listen(listenSocket, MaxConnect) == -1) {
    fprintf(stderr, "listen : %s\n", strerror(errno));
    close(listenSocket);
    return NULL;
  }

  FD_ZERO(&targetFd);
  FD_SET(listenSocket, &targetFd);
  maxFd = listenSocket;
  FD_SET(SelfPipe[0], &targetFd);
  maxFd = (SelfPipe[0] > maxFd) ? SelfPipe[0] : maxFd;
  if(maxFd >= MaxConnect) maxFd = MaxConnect - 1;

  while(1) {
    fd_set checkFDs;
    memcpy(&checkFDs, &targetFd, sizeof(targetFd));
    if(select(maxFd + 1, &checkFDs, NULL, NULL, NULL) == -1) {
      fprintf(stderr, "select error : %s\n", strerror(errno));
    } else {
      for(int fd = maxFd; fd >= 0; fd--) {
        if(FD_ISSET(fd, &checkFDs)) {
          if(fd == SelfPipe[0]) {
            while(1) {
              unsigned char buf[256];
              int length = read(SelfPipe[0], buf, 2);
              if(length <= 1) break;
              int resSize = buf[0];
              int resFd = buf[1];
              length = read(SelfPipe[0], buf, resSize);
              if(length < resSize) break;
              char *res = (char *)buf;
              if(strlen(res)) {
                strcat(res, "\n");
                send(resFd, res, strlen(res) + 1, 0);
              }
              close(resFd);
              FD_CLR(resFd, &targetFd);
            }
          } else if(fd == listenSocket) {
            struct sockaddr_in dstAddr;
            int len = sizeof(dstAddr);
            int newSocket = accept(fd, (struct sockaddr *)&dstAddr, (socklen_t *)&len);
            if(newSocket < 0) {
              fprintf(stderr, "Socket::Accept Error\n");
              continue;
            }
            if(strcmp(inet_ntoa(dstAddr.sin_addr), "127.0.0.1")) {
              fprintf(stderr, "Rejected request from %s\n", inet_ntoa(dstAddr.sin_addr));
              close(newSocket);
              continue;
            }
            int flag = fcntl(newSocket, F_GETFL, 0);
            fcntl(newSocket, F_SETFL, O_NONBLOCK|flag);
            FD_SET(newSocket, &targetFd);
            maxFd = (newSocket > maxFd) ? newSocket : maxFd;
            if(maxFd >= MaxConnect) maxFd = MaxConnect - 1;
          } else {
            char buf[256];
            int size = recv(fd, buf, 255, 0);
            if(!size) {
              FD_CLR(fd, &targetFd);
              break;
            }
            if(size < 0) {
              close(fd);
              FD_CLR(fd, &targetFd);
              break;
            }
            buf[size] = 0;
            char *tokenPtr;
            char *p = strtok_r(buf, " \t\r\n", &tokenPtr);
            if(!p) continue;
            int executed = 0;
            for(int i = 0; i < sizeof(CommandTable) / sizeof(struct CommandTableSt); i++) {
              if(!strcasecmp(p, CommandTable[i].cmd)) {
                char *res = (*CommandTable[i].func)(fd, tokenPtr);
                if(res) {
                  send(fd, res, strlen(res) + 1, 0);
                  char cr = '\n';
                  send(fd, &cr, 1, 0);
                  close(fd);
                  FD_CLR(fd, &targetFd);
                }
                executed = 1;
                break;
              }
            }
            if(!executed) {
              char *res = "error";
              send(fd, res, strlen(res) + 1, 0);
              close(fd);
              FD_CLR(fd, &targetFd);
              fprintf(stderr, "command error : %s\n", p);
            }
          }
         }
      }
    }
  }
}

void Dump(const char *str, void *start, int size) {
  fprintf(stderr, "Dump %08x %s\n", (unsigned int)start, str);
  for(int i = 0; i < size; i+= 16) {
    char buf1[256];
    char buf2[256];
    sprintf(buf1, "%08x : ", (unsigned int)i);
    for(int j = 0; j < 16; j++) {
      if(i + j >= size) break;
      unsigned char d = ((unsigned char *)start)[i + j];
      sprintf(buf1 + strlen(buf1), "%02x ", d);
      if((d < 0x20) || (d > 0x7f)) d = '.';
      sprintf(buf2 + j, "%c", d);
    }
    fprintf(stderr, "%s %s\n", buf1, buf2);
  }
}

static void __attribute ((constructor)) command_init(void) {

  unsetenv("LD_PRELOAD");
  char *p = getenv("PRODUCT_MODEL");
  if(!strcmp(p, "WYZE_CAKP2JFUS")) wyze = 1;

  if(pipe(SelfPipe)) {
    fprintf(stderr, "pipe error\n");
    return;
  }
  int flag = fcntl(SelfPipe[0], F_GETFL, 0);
  fcntl(SelfPipe[0], F_SETFL, O_NONBLOCK|flag);
  flag = fcntl(SelfPipe[1], F_GETFL, 0);
  fcntl(SelfPipe[1], F_SETFL, O_NONBLOCK|flag);

  pthread_t thread;
  pthread_create(&thread, NULL, CommandThread, NULL);
}
