#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define KEY 0x09

int main(int argc, char **argv) {

  if(argc != 2) {
    fprintf(stderr, "usage : %s <log file>\n", argv[0]);
    exit(-1);
  }
  FILE *fp = fopen(argv[1], "r");
  fseek(fp, 32, SEEK_SET);

  int tc = 0;
  unsigned long time;
  while(!feof(fp)) {
    int d = fgetc(fp);
    if(d == EOF) break;
    d ^= KEY;
    if(!d) continue;
    if(!tc && (d == '$')) {
      tc = 1;
      continue;
    }
    if((tc == 1) && (d == '@')) {
      tc = 2;
      time = 0;
      continue;
    }
    if((tc >= 2) && (tc < 18)) {
      tc++;
      time <<= 4;
      if((d >= '0') && (d <= '9')) {
        d -= '0';
      } else if((d >= 'A') && (d <= 'F')) {
        d -= '7';
      } else {
        tc = 0;
        putchar(d);
        continue;
      }
      time |= d;
      if(tc == 18) {
        char buf[32];
        time_t t = (time_t)time;
        strftime(buf, 32, "[%Y/%m/%d-%T]", localtime(&t));
        printf("%s", buf);
      }
      continue;
    }
    tc = 0;
    putchar(d);
  }
  fclose(fp);
  return 0;
}
