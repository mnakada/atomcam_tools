#include <stdio.h>
#include <string.h>
#include <dlfcn.h>
#include <netdb.h>

// iCamera_app judges the network by resolving these names (test_conn_cloud_by_url in netServ.c).
// When both fail it goes offline, and then alarm_event_handle drops every alarm, so nothing is
// recorded to alarm_record while the router has no internet (#142).
// If the name cannot be resolved, answer 127.0.0.1: the check passes, and a connection to the cloud
// fails at once, so curl.c answers the alarm post locally.
static const char *CloudHosts[] = {
  "www.google.com",
  "device-api.atomtech.co.jp",
  NULL
};

static int (*real_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);

int getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {

  // as the other hooks: RTLD_NEXT is not available without _GNU_SOURCE in this toolchain
  if(!real_getaddrinfo) real_getaddrinfo = dlsym(dlopen("/lib/libc.so.0", RTLD_LAZY), "getaddrinfo");
  if(!real_getaddrinfo) return EAI_FAIL;
  int ret = real_getaddrinfo(node, service, hints, res);
  if(!node) return ret;

  for(int i = 0; CloudHosts[i]; i++) {
    if(!strcmp(node, CloudHosts[i])) {
      // log each change, so that tools.log shows when the internet went away and came back
      static int faked[sizeof(CloudHosts) / sizeof(CloudHosts[0])];
      if(!ret) {
        if(faked[i]) fprintf(stderr, "[getaddrinfo] %s resolved again\n", node);
        faked[i] = 0;
        return ret;
      }
      struct addrinfo local;
      memset(&local, 0, sizeof(local));
      local.ai_family = AF_INET;
      local.ai_socktype = hints ? hints->ai_socktype : 0;
      local.ai_protocol = hints ? hints->ai_protocol : 0;
      local.ai_flags = AI_NUMERICHOST;
      int ret2 = real_getaddrinfo("127.0.0.1", service, &local, res);
      if(!ret2) {
        if(!faked[i]) fprintf(stderr, "[getaddrinfo] %s cannot be resolved (%d), use 127.0.0.1\n", node, ret);
        faked[i] = 1;
        return 0;
      }
      break;
    }
  }
  return ret;
}
