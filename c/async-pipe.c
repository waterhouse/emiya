#include <stdio.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
#include <libkern/OSAtomic.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <errno.h>

#define N 4088 /* oh boy */

char *head, *tail;
pthread_cond_t cond;
pthread_mutex_t m;
volatile int le_lock;

/* ok, so, this time, the problem
   is that "free" isn't giving memory back to the OS.
   does it work to use mmap to grab every piece of 4K?
   .............
   see if the kernel is better or worse at this shit than
   the system-provided malloc/free lib.

   oh wait, you idiot.
   4K is ....... ah.
   just decrease N.  righto.
   this wouldn't work well on a machine with a page size that wasn't
   a divisor of 4K.
   however, it's probably a fairly safe bet...

   There would probably be room for a bit of improvement in the future,
   using the facts that, e.g., the memory use of this is completely
   forward-moving (you free the nth thing only after freeing the n-1th
    thing).  But probably unnecessary.
*/



void *probably_malloc(long n) {
  void *x = mmap(0, n, PROT_READ|PROT_WRITE,
		 MAP_ANON|MAP_SHARED, 0 /* can I do this? */,
		 0);
  if (x == MAP_FAILED) {
    fprintf(stderr, "mmap failed %ld %d %d\n", n, x, errno);
    exit(1);
  }
  return x;
}

/* lolmoney, assume x is always of length N + 8 */
void probably_free(void *x) {
  int ret = munmap(x, N+8);
  if (ret == -1) {
    fprintf(stderr, "munmap failed %p %d\n", x, errno);
    exit(1);
  }
  return;
}
  
   

void *writer(void *ignored) {
  long dick;
  char *next_head;

  /* pthread_cond_wait sez it unlocks the mutex and waits,
     and when it returns it re-acquires the mutex.
     does that mean I have to lock it initially?
     or not?
     Fuck. */
  pthread_mutex_lock(&m);
  while(1) {
    /* note that head is char *, and head[0] is just a byte, not
       a full integer. this isn't a problem.
       wait nvm.
       Ok, length is either full N or is less.
       If less, then this is last.
       Init'd to -1.
       0 is an answer.*/
    /* mmmmmmmmmmmmmmmmmmmmmm...
       now the problem is to wait for dick without certain kinds
       of synchronization problems.
       well.
       ok, I want compare-and-swap or something.
       (actually lock xchg would suffice)
       ... actually, do I need...
       ---------------------------------------------- idiot. */

    /* ok, so, a pointer must be installed at the head.
       it can initially ..........
       ok.
       reader reads up to N bytes, then either allocates the next
       buffer, installs 0 in its head, and installs the pointer in this one,
       or it was less than N bytes and installs ... that - N in this one.
       [# bytes could be 0]
       the head is, as seen, initially 0. */

    while((dick = ((long *) head)[0]) != 0) {
      if (dick < 0) {
	write(STDOUT_FILENO, head + 8, dick + N);
	exit(0);
      }
      write(STDOUT_FILENO, head + 8, N);
      /* head = ((char **) head)[0]; */
      /* oh crap, forgot about freeing */
      next_head = ((char **) head)[0];
      probably_free(head);
      head = next_head;
      
    }
    /* now, as for this shit.
       we wait for this...
       anyway, looks like I need the totally not-platform-independent
       "#include <libkern/OSAtomic.h>".
    */
    /* if OSAtomicXor32(1, &le_lock) { guh, doesn't work like I'd like */
    if (OSAtomicCompareAndSwapInt(0, 1, &le_lock)) {
	pthread_cond_wait(&cond, &m);
	/* oh, should make it 0 again
	 hmm... what happens if the other thread has put it to 1...
	 then this should work fine, you'll find the end. */
	le_lock = 0;
      }
  }

}

int fake_read(int fd, char *buf, long n) {
  long desired = n;
  long dick;
  while(1) {
    dick = read(fd, buf, desired);
    /* fprintf(stderr, "Red %d\n", dick); */
    if (dick == desired)
      return n;
    if (dick < 0)
      return -1;
    if (dick == 0)
      return (n - desired);
    desired -= dick;
    buf += dick;
  }
}
    

int main(int argc, char **argv) {
  int fd_in = STDIN_FILENO;
  if (argc > 1) {
    fd_in = open(argv[1], O_RDONLY);
    if(fd_in == -1) {
      fprintf(stderr, "Oh dear, failed to open file %s %d.\n", argv[1], fd_in);
      exit(1);
    }
  }

  pthread_cond_init(&cond, NULL);
  pthread_mutex_init(&m, NULL);
  le_lock = 0;

  char *x = probably_malloc(N + 8);
  ((void **) x)[0] = 0;
  head = x;
  tail = x;
 
  pthread_t the_writer;
  pthread_create(&the_writer,
		 NULL,
		 writer,
		 NULL);

  /* ok, turns out that, at least in this case, read can return
     something small... */

  int num_read;
  int cock;
  while(1) {    
    num_read = fake_read(fd_in, tail + 8, N);
    /* fprintf(stderr, "Read this: %d\n", num_read); */
    if (num_read < 0) {
      fprintf(stderr, "Oh fuck, a read error %d\n", num_read);
      exit(1);
    }
    if (num_read < N) {
      ((long *) tail)[0] = num_read - N;

      cock = OSAtomicCompareAndSwapInt(0, 1, &le_lock);
      pthread_cond_signal(&cond);
      /* oh god, reclaiming the thing...
	 I think I actually need the mutex. Sigh. */
      if (!cock) {
	/* so this means there's some kind of collision where the writer
	   is going to go to sleep waiting.
	   when it does, it will unlock the dick.
	   however, at the beginning of the program, the dick is also
	   unlocked.
	   so...
	   in that case...
	   in that case, le_lock should still be 0.
	   so no problem. */
	pthread_mutex_lock(&m);
	pthread_mutex_unlock(&m);
	pthread_cond_signal(&cond);
      }
      pthread_join(the_writer, NULL); /* not a pointer passed? ok wtvr */
    }
    /* usual case */
    x = probably_malloc(N + 8);
    ((long *) x)[0] = 0;
    ((char **) tail)[0] = x;
    pthread_cond_signal(&cond);
    tail = x;
  }
}




  
