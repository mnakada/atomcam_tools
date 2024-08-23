#include <stdio.h>
#include <string.h>
#include <stdarg.h>

/*
extern void Dump(const char *str, void *start, int size);

int printf(const char *fmt, ...) {

  unsigned int ra = 0;
  asm volatile(
    "ori %0, $31, 0\n"
    : "=r"(ra)
  );

  unsigned int sp = 0;
  asm volatile(
    "ori %0, $29, 0\n"
    : "=r"(sp)
  );

  if(!strcmp(fmt, "[%s,%04d]----- p2p recv protocol set property -----\n")) {
    fprintf(stderr, "=== printf ra=%08x sp=%08x\n", ra, sp);
    unsigned int *pc = (unsigned int *)&printf;
    for(int i = 0; i < 16; i++) {
      if((pc[i] & 0xffff0000) == 0x27bd0000) {
        int ss = -(short)(pc[i] & 0xffff);
        fprintf(stderr, "printf stack %08x\n", ss);
        char *p = (char *)(sp + ss + 0x40 + 0x40 + 0x20);
        fprintf(stderr, "%s\n", p);
        break;
      }
    }
  }

  va_list args;
  va_start(args, fmt);
  vprintf(fmt, args);
  va_end(args);
}
*/
