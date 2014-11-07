/* Orion Lawlor's Short UNIX Examples, olawlor@acm.org 2003/8/18

Shows how to use the basic "mmap" syscall to gain access to 
some private memory.  The same technique can be used to 
map a file into memory.

WARNING: This uses MAP_ANONYMOUS, which works in Linux and OS X,
but not on some other weirder UNIXes.  mmap doesn't exist on Windows.
On some machines, you have to open("/dev/zero") to map in some zeros.
*/
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/fcntl.h>

int main() {
	int len=1024*1024;
	char *file = "file.file";
	int fd = open(file, O_RDWR);
	printf("open(%s,%d)\n",file,O_RDWR);
	void *addr=mmap((void *)0,len,PROT_READ+PROT_WRITE,MAP_SHARED,fd,0);
	printf("mmap(%p, %d, %d, %d, %d, %d)\n", (void *)0, len, PROT_READ+PROT_WRITE, MAP_SHARED,fd,0);
	int *buf=(int *)addr;
	printf("%p, %p\n", addr, buf);
	if (addr==MAP_FAILED) {perror("mmap"); exit(1);}
	buf[3]=8;
	buf[2]=buf[3];
	printf("mmap returned %p, which seems readable and writable\n",addr);
	munmap(addr,len);
	
	return 0;
}
/*<@>
<@> ******** Program output: ********
<@> mmap returned 0x2aff8c0f1000, which seems readable and writable
<@> */
