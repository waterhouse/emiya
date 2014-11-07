#include <stdio.h>

int main(int argc, char **argv) {
  void *f;
  int x = 2;
  f = (void *) printf;
  printf("printf may be found at %p\n",f);
  if (argc > x) {
    printf("hella args\n");
  }
  return 0;
}
