# logconv for atomcam

CC = ${TARGET_CROSS}gcc
STRIP = $(TARGET_CROSS)strip
CC_SRCS = logconv.c
TARGET = logconv

CFLAGS = $(INCLUDES) -O2 -Wall -march=mips32r2

all: ${TARGET}

${TARGET}: ${CC_SRCS}
	${CC} ${CFLAGS} -o $@ $^
	${STRIP} $@

clean:
	rm -f *.o *~

distclean: clean
