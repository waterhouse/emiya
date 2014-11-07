#include <stdio.h>

int main() {
  void *f;

  f = (void *) printf;
  printf("printf is %p\n", f);
  f = (void *) puts;
  printf("puts is %p\n", f);

  puts("Dick");
  puts("Ass");
  puts("Cock");

  return 0;
}
