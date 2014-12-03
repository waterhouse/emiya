/* gcc -o killer killer.c
   Then:
   ./killer 10 20 487
   will allow process 487 to work for 10 milliseconds, pause it for
   20 milliseconds, and repeat.  An arbitrary number of process ids
   can be specified.
   If something other than control-C kills this process, then it may
   be necessary to kill -CONT any processes that are still stopped. */

#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

/* Details:
   - die when, and only when, there are no procs left
   - when procs disappear, remove them from list
   - cont everything upon SIGINT or SIGTERM */
/* Version 6: In case argv is immutable. */

int *procs;
int num_procs;

void cont_everything_and_quit (int ignored_signal) {
  int i;
  for (i=0; i<num_procs; i++) {
    kill(procs[i], SIGCONT);
  }
  exit(0);
}

int main(int argc, char **argv) {

  if(argc < 3) {
    printf("Args should be milliseconds on and off, followed by pids.\n");
    return 0;
  }

  int on = atoi(argv[1]) * 1000;
  int off = atoi(argv[2]) * 1000;

  int i;
  num_procs = argc - 3;

  int pids[num_procs];
  procs = pids;

  /* procs = (int *) argv; */

  for(i=0;i<num_procs;i++){
    procs[i] = atoi(argv[i+3]);
  }

  signal(SIGINT, cont_everything_and_quit);
  signal(SIGTERM, cont_everything_and_quit);

  int n;

  while (num_procs) {
    for(i=0;i<num_procs;i++){
      n = kill(procs[i], SIGSTOP);
      if (n != 0) { /* assume process died */
        procs[i] = procs[num_procs - 1];
        num_procs--;
      }
    }
    usleep(off);

    for(i=0;i<num_procs;i++){
      n = kill(procs[i], SIGCONT);
      if (n != 0) { /* assume process died */
        procs[i] = procs[num_procs - 1];
        num_procs--;
      }
    }
    usleep(on);
  }

  return 0;
}
