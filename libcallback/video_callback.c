#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <pthread.h>

struct frames_st {
  unsigned char *buf;
  size_t length;
};
typedef int (* framecb)(struct frames_st *);

static int (*real_local_sdk_video_set_encode_frame_callback)(int ch, void *callback);
static int video0_encode_capture(struct frames_st *frames);
static int video1_encode_capture(struct frames_st *frames);
static int video2_encode_capture(struct frames_st *frames);

struct video_capture_st {
  framecb capture;
  int width;
  int height;
  const char *device;
  unsigned int format;

  framecb callback;
  int enable;
  int initialized;
  int stream;
  int fd;
};

static struct video_capture_st video_capture_atomcam[] = {
  {
    .capture = video0_encode_capture,
    .width = 1920,
    .height = 1080,
    .device = "/dev/video0",
    .format = V4L2_PIX_FMT_H264,

    .callback = NULL,
    .enable = 0,
    .initialized = 0,
    .stream = 0,
    .fd = -1,
  },
  {
    .capture = video1_encode_capture,
    .width = 640,
    .height = 360,
    .device = "/dev/video1",
    .format = V4L2_PIX_FMT_HEVC,

    .callback = NULL,
    .enable = 0,
    .initialized = 0,
    .stream = 0,
    .fd = -1,
  },
  {
    .capture = video2_encode_capture,
    .width = 1920,
    .height = 1080,
    .device = "/dev/video2",
    .format = V4L2_PIX_FMT_HEVC,

    .callback = NULL,
    .enable = 0,
    .initialized = 0,
    .stream = 0,
    .fd = -1,
  },
};

static struct video_capture_st video_capture_wyzecam[] = {
  {
    .capture = video0_encode_capture,
    .width = 1920,
    .height = 1080,
    .device = "/dev/video0",
    .format = V4L2_PIX_FMT_H264,

    .callback = NULL,
    .enable = 0,
    .initialized = 0,
    .stream = 0,
    .fd = -1,
  },
  {
    .capture = video1_encode_capture,
    .width = 640,
    .height = 320,
    .device = "/dev/video1",
    .format = V4L2_PIX_FMT_H264,

    .callback = NULL,
    .enable = 0,
    .initialized = 0,
    .stream = 0,
    .fd = -1,
  },
};

static struct video_capture_st *video_capture = video_capture_atomcam;
static int VideoChNum = 3;
extern int AudioBitrate;
extern int wyze;

static void __attribute ((constructor)) video_callback_init(void) {

  if(wyze) {
    VideoChNum = 2;
    video_capture = video_capture_wyzecam;
  }

  real_local_sdk_video_set_encode_frame_callback = dlsym(dlopen("/system/lib/liblocalsdk.so", RTLD_LAZY), "local_sdk_video_set_encode_frame_callback");
}

char *VideoCapture(int fd, char *p, char *tokenPtr) {

  int ch = 0;
  if(p && (!strcmp(p, "0") || !strcmp(p, "1") || !strcmp(p, "2"))) {
    ch = atoi(p);
    if(ch >= VideoChNum) return "error";
    p = strtok_r(NULL, " \t\r\n", &tokenPtr);
  }
  if(!p) return video_capture[ch].enable ? "on" : "off";
  if(!strcasecmp(p, "on")) {
    video_capture[ch].enable = 1;
    printf("[command] video %d capute on\n", ch);
    return "ok";
  }
  if(!strcasecmp(p, "off")) {
    video_capture[ch].enable = 0;
    printf("[command] video %d capute off\n", ch);
    return "ok";
  }
  return "error";
}

static int video_encode_capture(int ch, struct frames_st *frames) {

  if((video_capture[ch].fd < 0) && video_capture[ch].enable) {
    int err;
    video_capture[ch].fd = open(video_capture[ch].device, O_WRONLY, 0777);
    if(video_capture[ch].fd < 0) {
      fprintf(stderr, "Failed to open V4L2 device: %s\n", video_capture[ch].device);
    } else {
      struct v4l2_format vid_format;
      int err = ioctl(video_capture[ch].fd, VIDIOC_G_FMT, &vid_format);
      vid_format.type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
      vid_format.fmt.pix.width = video_capture[ch].width;
      vid_format.fmt.pix.height = video_capture[ch].height;
      vid_format.fmt.pix.pixelformat = video_capture[ch].format;
      vid_format.fmt.pix.sizeimage = 0;
      vid_format.fmt.pix.field = V4L2_FIELD_NONE;
      vid_format.fmt.pix.bytesperline = 0;
      vid_format.fmt.pix.colorspace = V4L2_PIX_FMT_YUV420;
      err = ioctl(video_capture[ch].fd, VIDIOC_S_FMT, &vid_format);
      if(err < 0) fprintf(stderr, "Unable to set V4L2 %s format: %d\n", video_capture[ch].device, err);
      int type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
      err = ioctl(video_capture[ch].fd, VIDIOC_STREAMON, &type);
      if(err < 0) fprintf(stderr, "Unable to perform VIDIOC_STREAMON %s: %d\n", video_capture[ch].device, err);
    }
  }
  if((video_capture[ch].fd >= 0) && !video_capture[ch].enable) {
    close(video_capture[ch].fd);
    video_capture[ch].fd = -1;
  }

  if(video_capture[ch].fd >= 0) write(video_capture[ch].fd, frames->buf, frames->length);
  return (video_capture[ch].callback)(frames);
}

static int video0_encode_capture(struct frames_st *frames) {
  return video_encode_capture(0, frames);
}

static int video1_encode_capture(struct frames_st *frames) {
  return video_encode_capture(1, frames);
}

static int video2_encode_capture(struct frames_st *frames) {
  return video_encode_capture(2, frames);
}

int local_sdk_video_set_encode_frame_callback(int sch, void *callback) {

  int ch = sch;
  if((ch == 0) || (ch == 1) || (ch == 3)) {
    if(ch == 3) ch = 2;
    if((ch < VideoChNum) && !video_capture[ch].callback) {
      video_capture[ch].callback = callback;
      callback = video_capture[ch].capture;
    }
  }
  return real_local_sdk_video_set_encode_frame_callback(sch, callback);
}
