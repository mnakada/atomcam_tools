# libcallback.so

CC = ${CROSS_COMPILE}gcc
CFLAGS = -fPIC -std=gnu99 -shared -ldl -ltinyalsa -lm
CC_SRCS = command.c video_control.c video_callback.c audio_callback.c jpeg.c setlinebuf.c mmc_format.c curl.c freopen.c opendir.c remove.c motor.c gmtime_r.c wait_motion.c irled.c audio_play.c usb_power.c timelapse.c mp4write.c
TARGET = libcallback.so

all: ${TARGET}

${TARGET}: ${CC_SRCS}
	${CC} ${CFLAGS} -o ${TARGET} ${CC_SRCS}
