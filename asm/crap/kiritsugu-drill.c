#include <stdio.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>

#include <dlfcn.h>

void die(char *s) {
  printf("%s\n", s);
  exit(1);
}

int main(int argc, char **argv) {
  int f = open("kid-shirou.code", O_RDONLY);
  if (f == -1) {
    die("Failed to open the file");
  }

  /* oh, right, this is what makes it terrible to do this:
     I need the length of the file.
     well, screw using fstat. time to hard code. */
  void *x = mmap(0, 311, PROT_READ|PROT_WRITE|PROT_EXEC,
                 MAP_FILE|MAP_PRIVATE, f, 0);

  /* hmm. is there a subtle conflict if I open a file RDONLY,
     but mmap it with writability?
     if I use MAP_PRIVATE, it shouldn't be trying to modify the
     file itself, so it seems that *should* be fine... we will
     try, I suppose */

  void *a = dlopen;
  void *b = dlsym;

  void (*meh)(void *, void *) = x;

  printf("Allocated: a %p b %p meh %p\n", a, b, meh);

  meh(a,b);

  return 0;
}
 
/* OH MAN IT ALL WORKS
   ~/asm $ ./kiritsugu-drill 
   Allocated: a 0x7fff871a6e03 b 0x7fff871a70aa meh 0x100049000
   a
   Lelz that character is a or 97 or 61
   Lelz that character is 
   or 10 or a
   b
   Lelz that character is b or 98 or 62
   Lelz that character is 
   or 10 or a
   achtung
   Lelz that character is a or 97 or 61
   Lelz that character is c or 99 or 63
   Lelz that character is h or 104 or 68
   Lelz that character is t or 116 or 74
   Lelz that character is u or 117 or 75
   Lelz that character is n or 110 or 6e 
*/




