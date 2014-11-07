#include <sys/fcntl.h>
int main() {
  char *file = "file.file";
  int fd = open(file, O_RDWR);
  return fd;
}
