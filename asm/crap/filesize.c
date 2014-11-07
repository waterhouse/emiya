

/* #include <fcntl.h> */
#include <sys/stat.h>

long int filesize(int fd) {
  struct stat h;
  fstat(fd, &h);
  return h.st_size;
}
