section .data
loop_str:	db "loop", 10, 0
str_str:	db "%s", 10, 0
num_str:	db "%ld", 10, 0	;seems it's the C preprocessor or wtvr that makes \n into newline...
big_err:	db "I don't know who I am anymore!", 10, 0

err_str:	db "Oh fuck me there was an error", 10, 0
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
	
	





exit:
	mov rax, 0x2000001
	mov rdi, 0
	syscall



done:
	mov rax, 0x2000001
	mov rdi, 0
	syscall