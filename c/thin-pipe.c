#include <stdio.h>
#include <pthread.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <errno.h>
/* I'll bite the bullet and use mutexes for locks. */
/* And it turns out to be not that bad. */

#define N (4096*16 - 8)
/* Somewhat increased performance with larger pages.
   ... This one, you actually expect the writer to lag a lot, so there
   is probably no latency benefit to smaller pages. */

/* these are bytes allocated and freed, not read and written */
volatile long read_count;
volatile long write_count;

pthread_mutex_t sleep_lock;
pthread_cond_t sleep_cv;
/* I hope that by "Wait for a condition and lock the specified mutex",
   it means "Lock the specified mutex and wait for a condition". */

volatile int writer_sleeping;
volatile int reader_sleeping;

/* long chunk_size_plus; */
long buf_size;

char * the_head;

void *probably_malloc(long n) {
  void *x = mmap(0, n, PROT_READ|PROT_WRITE,
		 MAP_ANON|MAP_SHARED, 0 /* can I do this? */,
		 0);
  if (x == MAP_FAILED) {
    fprintf(stderr, "mmap failed %ld %p %d\n", n, x, errno);
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
  char *head = the_head;
  char *next_head;

  while(1) {
    /* Ok, length is either full N or is less.
       If less, then this is last.
       Init'd to -1.
       0 is an answer.*/

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

      write_count += N;

      
      /* Idiot, it makes more sense to have the sleeping/not-sleeping thread
         change its own status.
         Only problem is what happens if you find twice in a row that it's sleeping,
         or something.  And that isn't problematic; extra cond_signaling is fine.
      */

      /* we may need to wake up the reader */
      if (reader_sleeping) {
        /* /\* then the reader either is cond_waiting or is holding the lock *\/ */
        /* pthread_mutex_lock(&sleep_lock); */
        /* pthread_mutex_unlock(&sleep_lock); /\* is cond_waiting by now *\/ */
        /* reader_sleeping = 0; */
        pthread_cond_signal(&sleep_cv);
        /* Only problem is if the reader had set its flag but not slept yet,
           but in that case, unless buf_size is miniscule and has only one buffer,
           we'll probably wake it up next time around,
           and if something *bizarre* is happening we'll be sure to wake it up
           before going to sleep ourselves. */
        
      }
    }

    /* out of work, we go to sleep */

    pthread_mutex_lock(&sleep_lock);
    /* if it happens that the reader is sleeping, we must wake it up */
    if (reader_sleeping) {
      /* reader_sleeping = 0; */
      pthread_cond_signal(&sleep_cv); /* then the reader will block on the lock until we release by sleeping */
      /* or conceivably it's already awake but hasn't updated its flag yet; that isn't a problem */
    }
    writer_sleeping = 1;
    pthread_cond_wait(&sleep_cv, &sleep_lock);
    writer_sleeping = 0;
    pthread_mutex_unlock(&sleep_lock);
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


/* Accept the size as an argument, defaulting to 10 MB. */
/* Accept also the size of the "how long to wait before waking up */
/*  the writer"... eh... neh, never mind. */
  
int main(int argc, char **argv) {

  pthread_cond_init(&sleep_cv, NULL);
  pthread_mutex_init(&sleep_lock, NULL);
  
  buf_size = (argc > 1) ? atol(argv[1]) : (40 * 1 << 20);

  char *x = probably_malloc(N + 8);
  ((void **) x)[0] = 0;
  the_head = x;
  char *tail = x;

  writer_sleeping = 0;
  reader_sleeping = 0;
  pthread_t the_writer;
  pthread_create(&the_writer, NULL, writer, NULL);
  /* don't bother with error checking in the above */

  int num_read;
  int cock;
  while(1) {    
    num_read = fake_read(STDIN_FILENO, tail + 8, N);
    if (num_read < 0) {
      fprintf(stderr, "Oh fuck, a read error %d\n", num_read);
      exit(1);
    }
    
    if (num_read < N) { /* then we're done reading */
      ((long *) tail)[0] = num_read - N;

      /* must be really careful here, so we lock before reading */
      /* actually, I think it's not a problem if we just lock and signal */
      /* regardless of what's happening... */
      pthread_mutex_lock(&sleep_lock);
      pthread_cond_signal(&sleep_cv);
      /* I assume that means the other thread will be blocking until we unlock it */
      pthread_mutex_unlock(&sleep_lock);
      /* cock = writer_sleeping; */
      /* if (writer_sleeping) { */
      /*   pthread_mutex_unlock(&sleep_lock); */
      /*   writer_sleeping = 0; */
      /*   pthroad_cond_signal(&sleep_cv); */
      /* } */
      
      pthread_join(the_writer, NULL); /* not a pointer passed? ok wtvr */
    }
    /* usual case */
    
    x = probably_malloc(N + 8);
    ((long *) x)[0] = 0;
    ((char **) tail)[0] = x;
    /* I guess I had just done a cond_signal regardless of anything... */
    /* Well, let's do this dickery. */
    if (writer_sleeping)
      pthread_cond_signal(&sleep_cv);
    /* And that turns out to make no or almost no performance difference. */
    tail = x;

    read_count += N;
    
    /* if we want to sleep, we check carefully for whether the writer sleeps */
    if ((read_count - write_count) > buf_size) {
      pthread_mutex_lock(&sleep_lock);
      if (writer_sleeping) {
        /* writer_sleeping = 0; */
        pthread_cond_signal(&sleep_cv); /* writer hangs on lock until we release */
      }
      reader_sleeping = 1;
      pthread_cond_wait(&sleep_cv, &sleep_lock);
      reader_sleeping = 0;
      pthread_mutex_unlock(&sleep_lock);
    }
    
  }

}




