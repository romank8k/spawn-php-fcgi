#define _XOPEN_SOURCE
#define _POSIX_C_SOURCE 200112L

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/types.h>

#define FCGI_LISTENSOCK_FILENO 0
#define SD_LISTEN_FDS_START 3

// As implemented in systemd (src/libsystemd-daemon/sd-daemon.c)
// Copyright 2010 Lennart Poettering
int sd_listen_fds() {
  int r;
  const char* e;
  char* p = NULL;
  unsigned long l;

  e = getenv("LISTEN_PID");
  if (!e) {
    r = 0;
    goto finish;
  }

  errno = 0;
  l = strtoul(e, &p, 10);
  if (errno > 0) {
    r = -errno;
    goto finish;
  }
  if (!p || p == e || *p || l <= 0) {
    r = -EINVAL;
    goto finish;
  }

  if (getpid() != (pid_t) l) {
    r = 0;
    goto finish;
  }

  e = getenv("LISTEN_FDS");
  if (!e) {
    r = 0;
    goto finish;
  }

  errno = 0;
  l = strtoul(e, &p, 10);
  if (errno > 0) {
    r = -errno;
    goto finish;
  }
  if (!p || p == e || *p) {
    r = -EINVAL;
    goto finish;
  }

  for (int fd = SD_LISTEN_FDS_START; fd < SD_LISTEN_FDS_START + (int) l; fd++) {
    int flags;

    flags = fcntl(fd, F_GETFD);
    if (flags < 0) {
      r = -errno;
      goto finish;
    }

    if (flags & FD_CLOEXEC)
      continue;

    if (fcntl(fd, F_SETFD, flags | FD_CLOEXEC) < 0) {
      r = -errno;
      goto finish;
    }
  }

  r = (int) l;

finish:
  unsetenv("LISTEN_PID");
  unsetenv("LISTEN_FDS");

  return r;
}

int main(int argc, char** argv) {
  // php-cgi will fork these children in addition to the main process.
  int num_children;
  if (argc > 1) {
    char* p = NULL;
    errno = 0;
    num_children = strtoul(argv[1], &p, 10);
    if (!errno) {
      if (!p || p == argv[1] || *p || num_children <= 0) {
        errno = EINVAL;
      }
    }
    if (errno) {
      fprintf(stderr, "spawn-php-fcgi: invalid number of children: %s\n", strerror(errno));
      exit(errno);
    }
  } else {
    num_children = 0;
  }

  int ret = sd_listen_fds();
  if (ret < 0) {
    fprintf(stderr, "spawn-php-fcgi: error receiving file descriptors: %s\n", strerror(-ret));
    return -ret;
  }
  if (ret != 1) {
    fprintf(stderr, "spawn-php-fcgi: no or too many file descriptors received\n");
    return -1;
  }

  if (num_children >= 0) {
    char cgi_childs[32];
    snprintf(cgi_childs, sizeof(cgi_childs), "PHP_FCGI_CHILDREN=%d", num_children);
    putenv(cgi_childs);
  }

  // Number of requests served by a single php-cgi process before it will be restarted.
  putenv("PHP_FCGI_MAX_REQUESTS=1024");

  // FastCGI programs read from and write to fd 'FCGI_LISTENSOCK_FILENO'.
  close(FCGI_LISTENSOCK_FILENO);
  dup2(SD_LISTEN_FDS_START, FCGI_LISTENSOCK_FILENO);
  close(SD_LISTEN_FDS_START);

  execvp("php-cgi", &argv[argc]);

  fprintf(stderr, "spawn-php-fcgi: exec failed: %s\n", strerror(errno));
  exit(errno);
}
