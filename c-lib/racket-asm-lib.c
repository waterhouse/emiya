
/* On OS X, gcc -dynamiclib -o file.dylib file.c works.
   On Linux, gcc -shared -fPIC -o file.so file.c works.
*/


/* I think Linux probably puts the Racket system in non-executable memory, so. */

/* General library here. */

/* We will want read, write, and executive privileges.  RIP-relative addressing for
   modifiable things (e.g. "variables") is useful.

   We shall not provide crap that reads from files.  The responsibility for that
   will be left up to Racket (which is quite capable of that).
*/



#include <sys/mman.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/stat.h>
#include <errno.h>
#include <stdlib.h>
#include <dlfcn.h>

/* Useful thing here. */
void install_handle_and_dlsym(void **x) {
  void *handle = RTLD_DEFAULT;
  void *ds = dlsym(handle, "dlsym");
  x[0] = handle;
  x[1] = ds;
  return;
}

/*
Our terrible plan is this:
- To load a file of asm code: mmap it executably and return an integer (the ptr).
  Racket knows what to do with integers.
- Then we call the "integer" with arguments.
GUUUUUUUUUUUUUUUUUUUUUUUUH
Make no attempt to demalloc.  Well, actually, it wouldn't be hard to do that.
Geez.
Ideal would be a weak pointer thing that would munmap the asm code when it
became inaccessible.  But... oh well.

... And I suppose we might as well also provide a way to copy a Racket byte-buffer
into an executable one.  Fuck.  Oh well.

*/


void *make_mem(long n, long prot) {
  void *x = mmap(0, n, prot, MAP_ANON | MAP_PRIVATE, 0, 0);
  if (x == MAP_FAILED)
    fprintf(stderr, "mmap failed; %ld %ld\n", n, prot);
  return x;
}

void *copy_mem(void *src, long n, long prot) {
  void *dest = make_mem(n, prot);
  memcpy(dest, src, n);
  return dest;
}

void *executable_copy (void *x, long n) {
  return copy_mem(x, n, PROT_READ|PROT_WRITE|PROT_EXEC);
}

/* arc> (pbcopy:tostring:for n 0 6 (pr "long call" n "(void *func") (for i 1 n (pr ", long x" i)) (prn ") {") (prn "  long (*f)(" (string:intersperse ", " (n-of n "long")) ") = func;") (prn "  return f(" (string:intersperse ", " (mapn [symb 'x _] 1 n)) ");") (prn "}")) */

long raw_call0(void *func) {
  long (*f)() = func;
  return f();
}
long raw_call1(void *func, long x1) {
  long (*f)(long) = func;
  return f(x1);
}
long raw_call2(void *func, long x1, long x2) {
  long (*f)(long, long) = func;
  return f(x1, x2);
}
long raw_call3(void *func, long x1, long x2, long x3) {
  long (*f)(long, long, long) = func;
  return f(x1, x2, x3);
}
long raw_call4(void *func, long x1, long x2, long x3, long x4) {
  long (*f)(long, long, long, long) = func;
  return f(x1, x2, x3, x4);
}
long raw_call5(void *func, long x1, long x2, long x3, long x4, long x5) {
  long (*f)(long, long, long, long, long) = func;
  return f(x1, x2, x3, x4, x5);
}
long raw_call6(void *func, long x1, long x2, long x3, long x4, long x5, long x6) {
  long (*f)(long, long, long, long, long, long) = func;
  return f(x1, x2, x3, x4, x5, x6);
}


/* Then, just in case it is useful.  (Might well be.)
   Pretend.
   Racket doesn't let anything happen during C calls, so this is fine...
*/

/* arc> (pbcopy:tostring:for n 0 6 (pr "long call" n "(void *func, long n") (for i 1 n (pr ", long x" i)) (prn ") {") (prn "  long (*f)(" (string:intersperse ", " (n-of n "long")) ") = executable_copy(func, n);") (prn "  if (f == MAP_FAILED)") (prn "    return -1;")  (prn "  long result = f(" (string:intersperse ", " (mapn [symb 'x _] 1 n)) ");") (prn "  memcpy(func, (char *) f, n);") (prn "  munmap((char *) f, n);") (prn "  return result;") (prn "}")) */


long call0(void *func, long n) {
  long (*f)() = executable_copy(func, n);
  if (f == MAP_FAILED)
    return -1;
  long result = f();
  memcpy(func, (char *) f, n);
  munmap((char *) f, n);
  return result;
}
long call1(void *func, long n, long x1) {
  long (*f)(long) = executable_copy(func, n);
  if (f == MAP_FAILED)
    return -1;
  long result = f(x1);
  memcpy(func, (char *) f, n);
  munmap((char *) f, n);
  return result;
}
long call2(void *func, long n, long x1, long x2) {
  long (*f)(long, long) = executable_copy(func, n);
  if (f == MAP_FAILED)
    return -1;
  long result = f(x1, x2);
  memcpy(func, (char *) f, n);
  munmap((char *) f, n);
  return result;
}
long call3(void *func, long n, long x1, long x2, long x3) {
  long (*f)(long, long, long) = executable_copy(func, n);
  if (f == MAP_FAILED)
    return -1;
  long result = f(x1, x2, x3);
  memcpy(func, (char *) f, n);
  munmap((char *) f, n);
  return result;
}
long call4(void *func, long n, long x1, long x2, long x3, long x4) {
  long (*f)(long, long, long, long) = executable_copy(func, n);
  if (f == MAP_FAILED)
    return -1;
  long result = f(x1, x2, x3, x4);
  memcpy(func, (char *) f, n);
  munmap((char *) f, n);
  return result;
}
long call5(void *func, long n, long x1, long x2, long x3, long x4, long x5) {
  long (*f)(long, long, long, long, long) = executable_copy(func, n);
  if (f == MAP_FAILED)
    return -1;
  long result = f(x1, x2, x3, x4, x5);
  memcpy(func, (char *) f, n);
  munmap((char *) f, n);
  return result;
}
long call6(void *func, long n, long x1, long x2, long x3, long x4, long x5, long x6) {
  long (*f)(long, long, long, long, long, long) = executable_copy(func, n);
  if (f == MAP_FAILED)
    return -1;
  long result = f(x1, x2, x3, x4, x5, x6);
  memcpy(func, (char *) f, n);
  munmap((char *) f, n);
  return result;
}




