section .data
loop_str:	db "loop", 10, 0
str_str:	db "%s", 10, 0
num_str:	db "%ld", 10, 0	;seems it's the C preprocessor or wtvr that makes \n into newline...
big_err:	db "I don't know who I am anymore!", 10, 0
not_found_str:	db "Didn't find %s", 10, 0
err_str:	db "Oh fuck me there was an error", 10, 0
bad_str:	db "Bad input: %s", 10, 0
die_str:	db "Out of memory. This should be fixed in the future.", 10, 0

	;; All right, design time.
	;; r15 will store tagging information on registers. 4 bits per register.
	;; also, the gc_stack thing will tag some stuff. that thing, I can use up to 16 bits (as long as AMD64
	;; only supports 48-bit addresses); the basic types will be the same.
	;; 0000 = 0 = not a pointer (note that the tag reg itself is such)
	;; 0001 = 1 = AVL node
	;; 0010 = 2 = string
	;; 1110 = e = tagged Lisp pointer (some programs will shove them around but not care for type)
	;; 1111 = f = buddy pointer
	;; Pairs: rax with rbx, rcx with rdx, rdi with rsi, r8 with r9, r10 with r11, r12 with r13.
	;; no pairings for rsp rbp r14 r15. the ordering is important at the moment.
	;; Bit-order: 0-15 hex: rax rbx rcx rdx rdi rsi rsp rbp r8 r9 r10 r11 r12 r13 r14 r15.
	;; By convention, rax and rdx will be expected to be non-pointers.
	;; A function or set of functions that knows what it's doing may install non-zero tag info for rax/rdx,
	;; but general functions should expect to be able to put non-pointers in those registers without
	;; asking permission.

	;; On the stack, for now, return addresses will be left alone. This implies I won't be able to
	;; create new functions in places that will need to be moved (I and my program are not yet
	;; strong enough with the force to do that anyway; no assembling at the moment). In the future, I could
	;; ensure that return addresses have any desired type tag by adding nops and using "push; jmp" instead
	;; of call.
	;; Things that are put on the stack with the expectation that the GC will ensure they remain
	;; in the right place... will have their high bits tagged. The tags must be there (not low bits) as long
	;; as return addresses are arbitrary and untagged and I'm not willing or able to store the knowledge
	;; elsewhere (in memory, or in the structure of the program, or whatever).
	;; Variables used by GC: B(ottom of free area), gc_stack, T(op of free area), k(onstant factor),
	;; SS(tack scanner)... for this implementation, I know the stack will be small and I won't use SS.
	;; k will probably be... a ratio of [bytes to trace]/[bytes to alloc now]. kept in memory.

	;; To determine whether something is in fromspace, need to CMP with... old fromspace. fromspace_(top|bottom)
	;; are kept in memory. It would be good to be able to handle fromspace testing with a single TEST
	;; instruction or something... fuck. that is DOABLE but hard, because of the way TEST works.  See [1].
	;; For now, I'll probably tolerate just comparing top with bottom.

	;; Now, because it's bad to access crap across 8-byte boundaries, all allocations shall be 8-byte aligned.
	;; Probably. Maybe. (I can imagine something wanting, like, a byte-size field...)
	;; Well, for now, I'll round up all allocations to the next multiple of 8. This will also guarantee
	;; that pointers will in fact end with 000, which I can use for tagging. This makes low-bit tagging
	;; a good idea. The only problem is return addresses, whose low bits can't be controlled without
	;; some effort. However, it is doable in two instructions:
	;; push [rel addr] ;cause you're not allowed 64-bit operands for most functions, including push
	;; jmp dest
	;; <possible nops, so that addr is 8-byte aligned--this is for speed, not tagging>
	;; addr: [8 bytes, with a tag]
	;; <nops to make the tag>
	;; actual return address: (proceed with execution)

	;; So that's doable, and probably ideal. But it requires an assembler with more intelligence than
	;; I'm willing to rely on right now. So for now, things will be tagged on the stack by high bits.
	

tospace_top:	dq 0		;these are only occasionally used
tospace_bottom:	dq 0		
fromspace_top:	dq 0
fromspace_bottom:	dq 0
	
kk:	dq 4			;work factor
bb:	dq 0			;allocation from bottom, mainly reading
tt:	dq 0			;allocation from top, normal allocation [2]
	
gc_stack:	dq 0		;initially 0; will be a big-tagged pointer most of the time
	;; semantics of gc_stack: it will point either to 0 or to the carcass of a moved object.
	;; [obj] will be a forwarding pointer to the live object, which we need to trace.
	;; [obj+8] will contain the "previous" value of gc_stack.

	;; in the future, I'll probably want to handle a) asking for more memory when I run out of space;
	;; b) asking for more memory preemptively, so the user needn't wait for a big alloc;
	;; and c) freeing up memory, at least for the OS. It seems this might be handled with "madvise".
	;; say, how does that interoperate with the GC stack? ...
	;; to handle it completely gracefully, I think you'll need to recompile everything that uses
	;; "move", for a second indirection. meh.

;; gc_jump_table: dq gc_jump
;; gc_jump:	
;; 	dq trace_nothing		;0
;; 	dq trace_string		;1 ;strings must be at least 16 bytes
;; 	dq trace_avl_node	;2
;; 	;; dq move_cons		;3

;; checked_move_table: dq checked_move
;; checked_move:	
;; 	dq checked_move_nothing		;0
;; 	dq checked_move_string		;1
;; 	dq checked_move_avl_node	;2
;; move_table: dq the_move_table
;; the_move_table:	
;; 	dq move_nothing		;0
;; 	dq move_string		;1
;; 	dq move_avl_node	;2


tree:	dq 0
stack_top:	dq 0

avl_node_hightag:	dq 0x2000000000000000
highmask:		dq 0x0fffffffffffffff
hightag:		dq 0xf000000000000000
r10_avl_tag:		dq 0x0000020000000000
r11_avl_tag:		dq 0x0000200000000000
rcx_r10_avl:		dq 0x0000020000000200
r10_r11_mask:		dq 0xffff00ffffffffff


	;; finally let's use some macros.
	;; it's not like they're hard to expand.
%macro MOVE_STRING_CHECKED 1	;mem; reg = rax, dest is generated
	mov rax, %1
	cmp rax, [rel fromspace_bottom]
	jl %%ok
	cmp rax, [rel fromspace_top]
	jnl %%ok
	;; xchg rax, %1		;this part is unnec. if reg = rax
	call move_string
	;; xchg rax, %1
	mov %1, rax
%%ok:	
%endmacro

%macro MOVE_AVL_NODE_CHECKED 2	;reg, mem; dest is generated
	mov %1, %2
	cmp %1, [rel fromspace_bottom]
	jl %%ok
	cmp %1, [rel fromspace_top]
	jnl %%ok
	xchg rax, %1		;this part is unnec. if reg = rax
	call move_avl_node
	xchg rax, %1
	mov %2, %1
%%ok:	
%endmacro

%macro MOVE_AVL_NODE 1		;mem; reg = rax; same as above but no xchging
	mov rax, %1
	cmp rax, [rel fromspace_bottom]
	jl %%ok
	cmp rax, [rel fromspace_top]
	jnl %%ok
	call move_avl_node
	mov %1, rax
%%ok:
%endmacro

%macro ALLOC 2			;reg, num/reg (can be the same)
	call print_rax
	mov rax, qword [rel gc_stack]
	call print_rax
	mov rax, 69
	call print_rax
	mov rax, 0
	;; mov rax, 0xdeadbeef
	cmp qword [rel gc_stack], rax
	;; mov rax, 0xdeadbeef
	ja %%do_work
%%get_ass:
	mov rax, 32
	call print_rax
	sub qword [rel tt], %2
	mov %1, [rel tt]
	cmp %1, [rel bb]
	jg %%done
%%begin_gc:
	xor %1, %1		;ensure no problems
	call exit
	jmp %%get_ass		;try again; infinite loop if memory too small
%%do_work:
	call print_rax
	push %1			;say, it'll be fixnum-tagged; that is noice.
	mov %1, rax
	mov rax, %2
	call print_rax
	mov rax, %1
	pop %1
	mov rax, 69
	call print_rax
	jmp %%get_ass
%%done:	
%endmacro
	
	
	

	
	
section .bss
buf:	resb 32

	
section .text

extern _printf
extern _read
extern _write
extern _sleep
extern _exit
extern _mmap
extern _munmap

global start
start:

	;; ALL RIGHT, REGARDING I/O.
	;; If input is from, say, a terminal, it may
	;; choose to flush output after, say, every newline or something.
	;; However, I suspect it is the case that output will never be
	;; flushed after 0 characters; in that case, if 0 characters are read,
	;; then that means EOF.
	;; It seems that, when typing into a terminal, ^D (i.e. EOF) makes a difference
	;; only when no characters were typed before it, because the terminal only
	;; does crap based on newlines. However, ^D^D is probably taken to mean "flush
	;; input, then EOF".
	;; ACTUALLY NO ^D DOES FLUSH INPUT AND FOR LISPS THAT DOESN'T TERMINATE A TOKEN (DUH)

	;; So. If you want to read a single line that's less than the buffer length,
	;; and if the source happens to submit it all at once, then a single "read"
	;; may suffice. Else, you will have to just keep re-reading.

	;; YES THIS SUCCESSFULLY ECHOES INPUT
	;; so now we'll do some funky business...
	mov rbp, rsp
	and sp, 0xfff0

	cmp qword [rbp], 2
	jl exit

	mov rax, 1
	call read_intarg	;amount of initial memory per semispace
	add rax, 15		;round that shit up
	and ax, 0xfff8
	mov r12, rax		;size of each semispace
	call claim_memory
	mov [rel tospace_bottom], rax
	mov [rel bb], rax
	add rax, r12
	mov [rel tospace_top], rax
	mov [rel tt], rax

	mov rax, r12
	call claim_memory
	mov [rel fromspace_bottom], rax
	add rax, r12
	mov [rel fromspace_top], rax
	;; call print_rax

	;; now what the fuck do we do? we run a loop, reading crap in.

loop:
	;; oh man fiendishly clever: prealloc space at the start for the length of the string
	;; instant canonicalized string!
	;; mov rax, 40		;hella not a pointer
	;; call alloc		;do this for now, would ideally alloc from bottom and double if too small
	ALLOC rax, 40
	mov r12, rax		;is a ptr

	;; read(fd, buf, n)
	mov rsi, rax
	add rsi, 8		;leave room for len
	xor rax, rax
	mov rdi, 0
	mov rdx, 32
	call _read		;for now all lines are length 32, maybe?





parse_int:
	;; arg, result in rax
	;; destroys... rbx, rcx
	xor rcx, rcx
	xor rbx, rbx
pi_loop:	
	mov cl, [rax]
	cmp cl, 0
	je pi_ret
	
	sub cl, 48
	imul rbx, rbx, 10
	jc big_err
	add rbx, rcx
	jc big_err
	inc rax
	jmp pi_loop
pi_ret:
	mov rax, rbx
	ret

read_intarg:
	;; n in rax
	;; rsp in... rbp? yeah.
	;; [argc] [&arg0] [&arg1] ...
	shl rax, 3
	add rax, rbp
	mov rax, [rax+8]

	;; call parse_int
	;; ret
	jmp parse_int

doh:	xor rax, rax
	mov rdi, err_str
	call _printf
	jmp done




	;; use anonymous mmap to get n bytes of memory
	;; n in rax; return address in rax
claim_memory:
	push rbp
	mov rbp, rsp
	and sp, 0xfff0		;all this crap needed? dunno

	;; mmap(addr, len, prot, flags, fd, offset)
	mov rsi, rax
	xor rax, rax
	mov rdi, 0
	mov rdx, 7
	mov rcx, 0x1001
	mov r8, 0
	mov r9, 0
	call _mmap

	mov rsp, rbp
	pop rbp
	ret
done:	
exit:
	;; oh man, time to finally stop using the Mac OS X syscall version
	mov rdi, 0
	xor rax, rax
	call _exit

print_rax:
	push rbp
	push rax
	push rdi
	push rsi
	push rdx
	push rcx
	push r8
	push r9
	mov rbp, rsp
	and sp, 0xfff0
	mov rdi, num_str
	mov rsi, rax
	xor rax, rax
	call _printf
	mov rsp, rbp
	pop r9
	pop r8
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	pop rax
	pop rbp
	ret