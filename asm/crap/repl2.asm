section .data
loop_str:	db "loop", 10, 0
str_str:	db "%s", 10, 0
num_str:	db "%ld", 10, 0	;seems it's the C preprocessor or wtvr that makes \n into newline...
big_err:	db "I don't know who I am anymore!", 10, 0

err_str:	db "Oh fuck me there was an error", 10, 0

kk:	dq 4			;B, S, k. T may be... kept in register? Or just quickly loaded into register?
bb:	dq 0			;At any rate, these things must be set up at start of program.
;; ss:	dq 0			;no longer need this because we use a fuckin' stack, bitch
gc_ing:	dq 0

to_bottom:	dq 0		;these are useful for reallocating crap
to_size:	dq 0		;the new to_size could be ... um.
	;; geez, I can actually make guarantees...
	;; If 
	

from_top:	dq 0		;these might really belong in uninitialized stuff, but oh well
from_bottom:	dq 0		;I intend for fromspace to possibly be disjoint from tospace
	;; e.g. when you run out of memory and ask for more, then all of previous memory is fromspace
	;; and if you haven't finished GC-ing by then...
	;; hmm, hey, wait a minute. can I make a separate (or sub-) process ask for more memory?
	;; that might be a good idea. programs probably will need to get more memory in at least a couple
	;; of stages, and it would be nice to not delay that shit.
	;; ... it would also be nice to reduce memory consumption.
	;; seems this can probably be done with "madvise, MADV_FREE". yes, that is perfect.
	;; then "madvise MADV_WILLNEED" when you do want it.
	;; and finally, more mmap if you really want it.
	;; wonder if I could claim a large amount of memory at the start and then just not use most of it?
	;; eh.
	;; for now... just like with stack overflows, for now I'll just let it happen and die with an error.
gc_stack:	dq 0

gc_jump_table:
	dq trace_nothing		;0
	dq trace_string		;1 ;strings must be at least 16 bytes
	dq trace_node		;2
	;; dq move_cons		;3

	
	
	
section .bss
buf:	resb 32
	
section .text

extern _printf
extern _read
extern _write
extern _sleep


global start
start:

	;; OH FUCK ME
	;; r11 belongs to the calling procedure.

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
	jl done

	mov rax, 1
	call read_intarg
	mov r12, rax

	xor rax, rax
	mov rdi, r12
	call _sleep

loop:

	;; read(fd, buf, n)
	xor rax, rax
	mov rdi, 0
	mov rsi, buf
	mov rdx, 32
	call _read

	cmp rax, 0
	je done
	cmp rax, -1		;fuckin' error?
	je doh

	mov r10, rax
	mov rax, buf
	add rax, r10		;ehhhh
	mov byte [rax], 0

	;; write(fd, buf, n)
	xor rax, rax
	mov rdi, 0
	mov rsi, buf
	mov rdx, r10
	call _write

	cmp rax, 0		;don't expect error, but eh
	jl doh

	jmp loop

	jmp done


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

free_memory:
	;; rax = addr, rdi = len

	;; screw saving or adjusting the stack.
	;; ... ok, fine, don't screw that.
	;; I suspect that a function call will screw with rsp
	;; when it returns a big struct (and doesn't malloc for it).

	push rbp
	mov rbp, rsp
	and sp, 0xfff0
	
	mov rsi, rdi
	mov rdi, rax
	xor rax, rax
	call _munmap

	mov rsp, rbp
	pop rbp
	ret


str_cmp_bef:
	cmp cl, 0
	cmove rax, 0
	je str_cmp_ret
str_cmp_step:	
	inc rax
	inc rdi
str_cmp:
	;; rax = a, rdi = b
	;; return 1 if less, 0 if eq, -1 if greater.
	mov cl, [rax]
	mov dl, [rdi]
	cmp cl, dl
	cmovb rax, 1
	cmova rax, -1
	je str_cmp_step

str_cmp_ret:
	ret



	;; now for fucking AVL crap...
	;; ;; datum, left, right, depth
	;; in fact, the payload will be a string and a key, and it will not do
	;; to put them in a wrapper struct thing.
	;; string, left, right, depth, key
	;; will need max crap; cmov stuff should do it
	;; depth = 1 for node with null left/right.

make_avl:
	;; datum in rax, left in rdi, right in rsi, key in rdx
	mov rcx, rax		;now left in rcx
	mov rax, 40
	call alloc		;my fucking ass
	mov [rax], rcx
	mov [rax+8], rdi
	mov [rax+16], rsi
	mov [rax+32], rdx
	;; now for the depth
	;; open coded ftw!
	cmp rdi, 0
	cmova rdi, [rdi+24]
	cmp rsi, 0
	cmova rsi, [rsi+24]
	cmp rdi, rsi
	cmova rsi, rdi
	inc rsi
	mov [rax+24], rsi
	ret			;beautiful

avl_add:
	;; insert a value and replace the old one if it exists.
	;; jesus christ, this may be difficult...
	;; it will have to effectively store the path to the bottom in a call stack.
	
	;; string in rax, value in rdi, tree in rsi.
	;; original tree is in rbx, of course.

	;; and now I am encountering a situation in which A repeatedly a) calls B
	;; and b) recursively calls itself. I would like the recursive calls to be
	;; as short as possible--mostly JMPs with some pushing and popping (just of rsi).
	;; however, if B demands incompatible arguments in the same place (register) as A,
	;; then this means a lot of shoving around.

	mov r8, rax
	mov r9, rdi

	;; this is a sub-function that takes:
	;; string in r8, value in r9, tree in rsi.

avl_add_dca:	

	cmp rsi, 0
	je avl_add_make_bottom

	mov rax, r9
	mov rdi, [rsi]
	call str_cmp
	cmp rax, 0
	je avl_add_bottom
	push rsi
	jl insert_right		;funny how "less" actually means 1; jl is "greater".

insert_left:
	mov rsi, [rsi+8]
	call avl_add_dca
	;; now rax = left branch...
	;; [rsp], the old rsi, its right branch is good ass. left is redundant.
	pop rsi
	mov rdi, rax		;left
	mov rax, [rsi]		;string
	mov rdx, [rsi+32]	;value
	mov rsi, [rsi+16]	;right
	jmp make_avl_rebalance
	;; jesus it's hard to think about AVL stuff in the midst of this

insert_right:	
	mov rsi, [rsi+16]
	call avl_add_dca
	pop rdi			;meh
	mov rsi, rax		;right
	mov rax, [rdi]		;string
	mov rdx, [rdi+32]	;value
	mov rdi, [rdi+8]	;left
	jmp make_avl_rebalance

avl_add_make_bottom:
	;; by this time, it's r8/r9 that have datum/value, not rax/rdi.
	mov rax, r8
	mov rdx, r9
	xor rdi, rdi
	xor rsi, rsi
	call make_avl
	ret
	
make_avl_rebalance:
	;; string/left/right/value in rax/rdi/rsi/rdx
	;; now holy crap...
	;; and maybe try not to damage r8/r9? yeah.
	;; but who knows what a) make_avl and b) alloc will damage.
	;; eh.

	;; all right, time to translate this
  ;;(def node/r (d x y) ;like node but rebalances
  ;;  (if (> depth.x inc:depth.y)
  ;;      (if (> depth:x!lf depth:x!rt)
  ;;          (node x!dt x!lf (node d x!rt y))
  ;;          (node x!rt!dt (node x!dt x!lf x!rt!lf)
  ;;                (node d x!rt!rt y)))
  ;;      (> depth.y inc:depth.x)
  ;;      (if (> depth:y!rt depth:y!lf)
  ;;          (node y!dt (node d x y!lf) y!rt)
  ;;          (node y!lf!dt (node d x y!lf!lf)
  ;;                (node y!dt y!lf!rt y!rt)))
  ;;      (node d x y)))
	;; into assembly.
	xor r10, r10
	cmp rdi, 0
	cmova r10, [rdi+24]
	xor r11, r11
	cmp rsi, 0
	cmova r11, [rsi+24]

	;; now those are the depths.

	sub r10, r11

	cmp r10, -1
	jl make_avl_rebalance_sr ;split right
	cmp r10, 1
	jg make_avl_rebalance_sl ;split left

	jmp make_avl		;ahhh

make_avl_rebalance_sl:
	;; (> depth:x!lf depth:x!rt)
	mov rcx, [rdi+16]	;x!rt
	cmp rcx, 0
	je make_avl_rebalance_sl_a
	mov r10, [rdi+8]	;x!lf
	xor r11, r11
	cmp r10, 0
	cmovne r11, [r10+24]
	cmp r11, [rcx+24]
	jg make_avl_rebalance_sl_b
	

make_avl_rebalance_sl_a:
	;; (node x!dt x!lf (node d x!rt y))
	push rdi
	mov rdi, rcx
	call make_avl
	mov rsi, rax
	pop rdi
	mov rax, [rdi]
	mov rdx, [rdi+32]
	mov rdi, [rdi+8]
	jmp make_avl

make_avl_rebalance_sl_b:
	;;          (node x!rt!dt (node x!dt x!lf x!rt!lf)
	;;                (node d x!rt!rt y)))
	push rdi
	mov rdi, [rcx+16]
	call make_avl
	mov r11, rax
	pop rdi
	mov rax, [rdi]
	mov rdx, [rdi+32]
	mov rdi, r10
	mov rsi, [rcx+8]
	call make_avl
	mov rdi, rax
	mov rsi, r11
	mov rax, [rcx]
	mov rdx, [rcx+32]
	jmp make_avl


make_avl_rebalance_sr:
	;; (> depth:y!rt depth:y!lf)
	mov rcx, [rsi+8]	;y!lf
	cmp rcx, 0
	je make_avl_rebalance_sr_a
	mov r10, [rsi+16]	;y!rt
	xor r11, r11
	cmp r10, 0
	cmovne r11, [r1[+24]
	cmp r11, [rcx+24]
	jg make_avl_rebalance_sr_b

make_avl_rebalance_sr_a:
	;; (node y!dt (node d x y!lf) y!rt)
	push rsi
	mov rsi, rcx
	call make_avl
	mov rdi, rax
	pop rsi
	mov rax, [rsi]
	mov rdx, [rsi+32]
	mov rsi, [rsi+16]
	jmp make_avl

make_avl_rebalance_sr_b:
	;; (node y!lf!dt (node d x y!lf!lf)
	;;       (node y!dt y!lf!rt y!rt))
	push rsi
	mov rsi, [rcx+8]
	call make_avl
	mov r11, rax
	pop rsi
	mov rax, [rsi]
	mov rdx, [rsi+32]
	mov rsi, r10
	mov rdi, [rcx+16]
	call make_avl
	mov rsi, rax
	mov rdi, r11
	mov rax, [rcx]
	mov rdx, [rcx+32]
	jmp make_avl



alloc:
	;; argument in rax
	;; need B, S, T, k, and tag register. which to put in registers, and which in memory?
	;; incidentally: jeez, being able to use [rel sym] gives me power. I could use it instead
	;; of the stack to store extra crap. the only problem is that that doesn't work with multi-
	;; threaded code... or, duh, with several instances of the function on the stack at once.
	;; (F calls G calls F; second F better not clobber stuff used by first F.) however, it *does*
	;; work with "leaf" functions that can be guaranteed to return before being called again.
	;; hmm, I see how one might use XCHG with "lock" and a chosen memory location to synchronize
	;; stuff between processes.
	;; anyway. B, S, T, k.
	;; Each allocation will check whether gc'ing needs to be done. This could be handled by seeing
	;; whether S < B. However, you can't compare two memory operands in one instruction.
	;; I'd put S and B in memory, the current k in memory, a backup k in memory, and keep T in a register.
	;; Will need to compare T with B to see if we've consumed all memory.
	;; Now the current k will be used as a proxy for [whether we need to run ass; set k=0 when done GCing]
	;; ... nah, screw that. just cmp T, [bb]. ... no, that's a different issue.
	;; neh, will just store a boolean: gc_ing. works fine.

	;; round up alloc amount to 8 bytes:
	test rax, 0b111
	jne alloc_noround
	and al, 0xf8
	add rax, 8

alloc_noround:

	;; note that this might be inlined... probably will, in fact, don't need to round crap up.
	;; though, actually, can just jump to here.
	
	cmp [rel gc_ing], 0
	je just_alloc
	call gc_steps

just_alloc:
	mov r14, [rel tt]	;T
	sub r14, rax
	cmp r14, [rel bb]
	jng begin_gc
	mov [rel tt], r14
	mov rax, r14
	ret

gc_steps:
	;; argument in rax
	mov r14, [rel bb]	;B
	mov r13, [rel ss]	;S
	imul rax, [rel kk]	;number of bytes to move
	push rdx
	push rcx
	push rbx
	xor rcx, rcx

gc_steps_loop:
	;; so we... take each... FUCK. the thing that S points to isn't necessarily a cons, or is it.
	;; some things get moved by the read barrier.
	;; how do I handle this. well, either each object in memory must contain a field tagging it as
	;; a struct with X layout, or the GC might have a kind of stack.
	;; I kind of prefer the latter, because then we also get depth-first traversal.
	;; ... a third option is to make everything in memory be a Lisp object. a string will be an array
	;; of tagged Lisp characters. this makes a foreign function interface difficult, as you'll have
	;; to either segregate foreign objects off somewhere, or just add tags in memory anyway. suck.
	;; so... do want depth-first traversal. can probably be done by clobbering old data on moved objects.
	;; in which case... might need to make boxes twice as big as necessary to ensure the collector
	;; stack can be threaded through them. that's fine.
	;; all right, we will have a collector stack.

	mov rdx, [rel gc_stack]
	shrd rcx, rdx, 8
	shr rcx, 53   ;so good, don't even need to zero rcx beforehand ;OR NOT, need a multiple of 8
	;; now rdx = pointer, rcx = tag
	;; now we want to dispatch based on tag. normally you'd use a jump table.
	;; eh, maybe I can do that.
	;; don't feel like using LEA.
	add rcx, gc_jump_table
	jmp [rcx]

	
	


	;; ...
	

	
	;; So moving something is actually really simple. You just need the address and the length
	;; of the thing. You *don't* need to know what's inside it.
	;; On the other hand, *tracing* something, you do need to know how the inside is laid out.

	;; Example: move rax, which is a cons.
	;; first check if rax is indeed in fromspace
	cmp rax, [rel fromspace_top]
	jnle done
	cmp rax, [rel fromspace_bottom]
	jnge done		;geez, this takes 2-4 instructions and a branch in the non-moving case
	;; next check if rax has already been moved; if so, just return the forwarding pointer.
	cmp [rax], 0		;the car must be a Lisp object, so that a garbage number isn't confused
	;; with a forwarding pointer
	jl just_move		;we'll negate pointers to indicate forwardedness (a fast opcode)
	
	mov rdx, rax
	sub [tospace_top], 16
	mov rax, [tospace_top]
	cmp rax, [tospace_bottom] ;in inlined cases, this check might be unnecessary
	jl out_of_memory
	;; call alloc
	;; ;; I was going to say "actually this is allocating to the bottom, so we increment B instead", but
	;; ;; in fact we have no need for that. not using it as a queue or anything. we've got a fuckin' stack...
	;; still it needs to be done, because you can't have "alloc" call "gc" call "move" call "alloc".
	
	;; now we can't say "mov [a] [b]". now there are some fucking "move string" instructions...
	;; these require args to be in r[ds]i, do something I don't understand involving DS and ES.
	mov rcx, [rdx]
	mov [rax], rcx
	mov rcx, [rdx+8]
	mov [rax+8], rcx
	;; so rax is the new thing. now we need to install a forwarding pointer and to handle stack stuff.
	;; the forwarding pointer might want to be tagged somehow...
	;; so things that point to the old location will know it's fromspace with some comparison method.
	;; the things that want to know whether this is a forwarding pointer... are those who move other
	;; pointers.
	mov [rdx], rax
	neg [rdx]		;negate to indicate forwardedness
	;; now we'll want to install into [rdx+8] a pointer to the previous thing on the stack
	;; we'll need to store a type tag somewhere.
	;; so before, [rel gc_stack] is a (possibly tagged) pointer to the previous thing on the stack.
	;; after, we'll want [rel gc_stack] to point to this thing. aha, here we go. use an 8-bit tag
	;; just because I can.
	mov rcx, [rel gc_stack]
	mov [rdx+8], rcx
	shl rdx, 8
	or rdx, 3		;cons tag
	mov [rel gc_stack], rdx

done:
	;; ass is in rax
	ret



just_move:
	mov rax, [rax]
	neg rax
	jmp done



move_size:
	;; arg in rax, size in rdx, fucks with rcx
	sub [tospace_top], rdx
	mov rdx, [tospace_top
	cmp rdx, [tospace_bottom]
	jl out_of_memory
	
	


begin_gc:
	;; 

	


	
	;; hoo boy
	;; I'll use r12-15 for global things. declared safe in x64 calling convention.
	;; argument in rax.

	;; so now we are having existential problems.
	;; at the GC flip, we will want to move the tree, and either immediately or later
	;; we will want to move everything in the stack and in registers.
	;; in the general case, registers might contain pointers to objects (which should be moved),
	;; integers (which, untagged, might look like objects, and which shouldn't be moved),
	;; pointers to the middle of objects (which might need to be moved, and if so, need to be
	;;  associated with the object and the offset maintained),
	;; pointers to different kinds of objects (which must be identified somehow),
	;; and possibly just random crap.

	;; I think I like the idea of using a register to store information about the types of things
	;; in other registers.
	
	;; hey, perspective. potentially there could be arbitrarily many registers. potentially
	;; they could be used basically like memory. it makes sense to use "large-scale" approaches
	;; to them.

	;; All right, design time.
	;; r15 will store tagging information on registers. 4 bits per register.
	;; 0000 = 0 = not a pointer
	;; 0001 = 1 = AVL node
	;; 0010 = 2 = string
	;; 1111 = f = buddy pointer
	;; Pairs: rax with rdx, rbx with rcx, rdi with rsi, r8 with r9, r10 with r11, r12 with r13,
	;; r14 with rbp.  (Don't expect to use the last one.)
	;; By convention, rax and rdx will be expected to be non-pointers.
	;; A function or set of functions that knows what it's doing may install non-zero tag info for rax/rdx,
	;; but general functions should expect to be able to put non-pointers in those registers without
	;; asking permission.

	;; On the stack, for now, return addresses will be left alone. This implies I won't be able to
	;; create new functions in places that will need to be moved (I and my program are not yet
	;; strong enough with the force to do that anyway; no assembling at the moment).
	;; Things that are put on the stack with the expectation that the GC will ensure they remain
	;; in the right place... will have their high bits tagged.
	;; Variables used by GC: B(ottom of free area), S(can pointer, starts below bottom), T(op of free area),
	;; k(onstant factor), SS(tack scanner)... for this implementation, I know the stack will be small
	;; and I won't use such stuff.
	;; Any or all of these variables could be preferentially kept in memory instead of (or in addition to)
	;; registers.
	;; k will probably be... a ratio of [bytes to trace]/[bytes to alloc now]. prob'ly put in memory.
	;; (Or code.)

	;; To determine whether something is in fromspace, need to CMP with... old fromspace.
	;; Which means need to store that fuckin' crap somewhere.
	;; Now it would be ideal to store the address of "fromspace" in code. Unfortunately, that would
	;; basically require RIP-relative addressing an
	;; Actually it's possible to do this, with the [rel <sym>] directive... And at least one
	;; of (RIP-relative, absolute) addressing
	;; is presumably legal on all architectures; otherwise you can't call functions or anything.
	;; Now... this requires that either the "fromspace" box never move, or that code get updated when it
	;; does move. Either shall be fine.

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
	
	
	





exit:
	mov rax, 0x2000001
	mov rdi, 0
	syscall



done:
	mov rax, 0x2000001
	mov rdi, 0
	syscall