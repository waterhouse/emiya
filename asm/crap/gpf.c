#include <stdio.h>

int main(int argc, char **argv) {
  void *f;
  f = (void *) printf;
  printf("%p\n",f);
  return 0;
}
