section .data
loop_str:	db "loop", 10, 0
str_str:	db "%s", 10, 0
num_str:	db "%ld", 10, 0	;seems it's the C preprocessor or wtvr that makes \n into newline...
big_err:	db "I don't know who I am anymore!", 10, 0
not_found_str:	db "Didn't find %s", 10, 0
err_str:	db "Oh fuck me there was an error", 10, 0
bad_str:	db "Bad input: %s", 10, 0

	;; All right, design time.
	;; r15 will store tagging information on registers. 4 bits per register.
	;; also, the gc_stack thing will tag some stuff. that thing, I can use up to 16 bits (as long as AMD64
	;; only supports 48-bit addresses); the basic types will be the same.
	;; 0000 = 0 = not a pointer (note that the tag reg itself is such)
	;; 0001 = 1 = AVL node
	;; 0010 = 2 = string
	;; 1110 = e = tagged Lisp pointer (some programs will shove them around but not care for type)
	;; 1111 = f = buddy pointer
	;; Pairs: rax with rbx, rcx with rdx, rdi with rsi, r8 with r9, r10 with r11, r12 with r13,
	;; r14 with rbp.  (Don't expect to use the last one.)
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

gc_jump_table:
	dq trace_nothing		;0
	dq trace_string		;1 ;strings must be at least 16 bytes
	dq trace_node		;2
	;; dq move_cons		;3


tree:	dq 0
stack_top:	dq 0

avl_node_hightag:	dq 0x2000000000000000
highmask:		dq 0x0fffffffffffffff
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
	jg %%ok
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
	jg %%ok
	xchg rax, %1		;this part is unnec. if reg = rax
	call move_avl_node
	xchg rax, %1
	mov %2, %1
%%ok:	
%endmacro
	
	
	

	
	
section .bss
buf:	resb 32

	
section .text

extern _printf
extern _read
extern _write
extern _sleep


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
	jl done

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

	;; now what the fuck do we do? we run a loop, reading crap in.

loop:
	;; oh man fiendishly clever: prealloc space at the start for the length of the string
	;; instant canonicalized string!
	mov rax, 40		;hella not a pointer
	call alloc		;do this for now, would ideally alloc from bottom and double if too small
	mov r12, rax		;is a ptr

	;; read(fd, buf, n)
	mov rsi, rax
	add rsi, 8		;leave room for len
	xor rax, rax
	mov rdi, 0
	mov rdx, 32
	call _read		;for now all lines are length 32, maybe?

	cmp rax, 0		;EOF
	je done
	cmp rax, -1		;fuckin' error?
	je doh

	;; now rax is the length of a string with starting address r12.
	;; we want to parse it.
	;; first, for precaution, we'll nul-terminate it. 32-byte input is a problem.

	mov r13, rax		;length; not ptr
	mov rcx, r12		;rcx? internal ptr
	add rcx, r13
	mov byte [rcx], 0

	;; now we will tokenize it roughly, by spaces.
	;; first let's just handle the two cases "sym" and "sym num".
	;; if I can do this without mallocing, I can put off setting flags in r15.
	mov rcx, r12		;atm r12 = buf
find_space:
	inc rcx			;at least one char should've been read
	cmp byte [rcx], 10	;newline
	je found_newline
	cmp byte [rcx], 32	;space
	je found_space
	cmp byte [rcx], 0	;nul, shouldn't happen
	je bad_input
	jmp find_space		;all this could be handled with some jump table

found_newline:			;now we print value
	mov byte [rcx], 0	;nub, clobbering ass; also don't need to segregate symbol, will throw it away.
	mov rax, r12
	;; now we want to look up this value in the AVL tree and print it.
	;; this will involve memory accesses and possibly moving. I can probably guarantee that the moving
	;; will not cause a memory death, so don't need to worry about GC flip.
	mov rdx, [rel tree]
	call lookup		;now I'll have this STC (set carry) if it doesn't find crap.
	jc not_found

	mov rdi, num_str
	mov rsi, rax
	xor rax, rax
	call _printf
	jmp loop

not_found:			;expects ass still in r12; must be saved by either moving or self
	mov rdi, not_found_str
	mov rsi, r12
	xor rax, rax
	call _printf
	jmp loop

found_space:			;rcx = end of str, and we will read a number.
	;; we'll need to insert str into tree, and will need to canonicalize string for this.
	;; perhaps we could just allocate extra at the start--yes, am doing that shit.
	sub rcx, r12
	mov [r12], rcx		;store len
	add rcx, r12
	inc rcx
	mov rax, rcx
	;; mov rdx, rcx		;save
	call parse_int		;kills rcx
	;; now rax = n, r12 = str. want to insert this into tree.
	;; this will involve calling stuff and maybe GC crap...
	mov r8, r12		;str
	mov r9, rax		;val
	mov rsi, [rel tree]
	;; now this function will use rax/rdi for stuff, so be neighborly and set that up too.
	mov r15, 0x0000000200100002
	call avl_add_dca	;it'll put crap in rax/rdi before any allocing so it's fine
	xor r15, r15
	jmp loop		;wow, I'm actually done there

bad_input:
	mov rdi, bad_str
	mov rsi, r12
	xor rax, rax
	call _printf
	jmp loop
	

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

	;; and time to deal with moving.
	;; I'll inline stuff as much as possible.

make_avl:
	;; datum in rax, left in rdi, right in rsi, key in rdx
	;; probably assume all has been moved
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
	cmova rdi, [rdi+24]	;thank god this fucking crap doesn't need to be fucking moved
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
	mov rdi, [rsi]		;oh snap we need to move it move it

	cmp rdi, [rel fromspace_bottom]
	jl fa
	cmp rdi, [rel fromspace_top]
	jg fa
	xchg rax, rdi
	;; valuable registers: r8 r9 rsi rdi rax. eh, also rbx, used for scratch.
	call move_string	;jesus christ, this is an irritating cost
	xchg rax, rdi
	mov [rsi], rdi
fa:	
	call str_cmp
	cmp rax, 0
	je avl_add_make_bottom
	;; now when we push, we must tag.
	mov rbx, rsi
	or rbx, [rel avl_node_hightag]
	push rbx
	cmp rax, 0		;narm
	jl insert_right		;funny how "less" actually means 1; jl is "greater".

insert_left:
	
	;; mov rbx, [rsi+8]	;now we must move that...
	;; cmp rbx, [rel fromspace_bottom]
	;; jl fb
	;; cmp rbx, [rel fromspace_top]
	;; jg fb
	;; xchg rax, rbx
	;; call move_avl_node
	;; xchg rax, rbx
	;; mov [rsi+8], rbx
	MOVE_AVL_NODE_CHECKED rbx, [rsi+8]
	mov rsi, rbx		;narm
	call avl_add_dca
	;; now rax = left branch...
	;; [rsp], the old rsi, its right branch is good ass. left is redundant.
	;; only r8/r9 are precious here
	pop rsi
	and rsi, [rel highmask]	;good god...
	
	mov rdi, rax		;left
	MOVE_STRING_CHECKED [rsi] ;string to rax
	MOVE_AVL_NODE_CHECKED rbx, [rsi+16] ;right
	mov rdx, [rsi+32]	;value, no need to check
	mov rsi, rbx
	jmp make_avl_rebalance
	;; jesus it's hard to think about AVL stuff in the midst of this

insert_right:
	MOVE_AVL_NODE_CHECKED rbx, [rsi+16]
	mov rsi, rbx
	call avl_add_dca
	pop rdi			;meh
	and rdi, [rel highmask]
	mov rsi, rax		;right
	MOVE_STRING_CHECKED [rdi]	;string
	mov rdx, [rdi+32]	;value
	MOVE_AVL_NODE_CHECKED rbx, [rdi+8]
	mov rdi, rbx	;left
	jmp make_avl_rebalance

avl_add_make_bottom:
	;; by this time, it's r8/r9 that have datum/value, not rax/rdi.
	;; only one instance will reach here, ideal time to set up r15.
	mov rax, r8
	mov rdx, r9
	xor rdi, rdi
	xor rsi, rsi
	;; need rcx = avl
	mov r15, 0x0000000000220201 ;rcx. no r10/r11? no.
	jmp make_avl		    ;str/avl/avl/int/(avl) rax/rdi/rsi/rdx/(rcx)
	
make_avl_rebalance:
	;; string/left/right/value in rax/rdi/rsi/rdx
	;; now holy crap...
	;; and maybe try not to damage r8/r9? yeah.
	;; but who knows what a) make_avl and b) alloc will damage.
	;; eh.
	;; we use r10, r11, rcx at various places.
	;; hmm, am I basically gonna have one of those for every point in my program?
	;; commonalities, being-able-to-do-stuff-without-excessive-information is good.

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
	cmova r10, [rdi+24]	;fortunately THESE don't need moving
	xor r11, r11
	cmp rsi, 0
	cmova r11, [rsi+24]
	;; now those are the depths.
	sub r10, r11
	cmp r10, -1
	jl make_avl_rebalance_sr ;split right
	cmp r10, 1
	jg make_avl_rebalance_sl ;split left
	;; and r15, [rel r10_r11_mask]
	jmp make_avl		;ahhh

	;; incidentally, much of this stuff wouldn't normally need to be re-stored
	;; because stuff gets thrown away immediately.
	;; nevertheless, let's pretend a program might make a ptr to an old copy of the tree.
make_avl_rebalance_sl:
	;; (> depth:x!lf depth:x!rt)
	MOVE_AVL_NODE_CHECKED rcx, [rdi+16]	;x!rt
	or r15, 0x200				;rcx = avl node
	cmp rcx, 0
	je make_avl_rebalance_sl_a
	MOVE_AVL_NODE_CHECKED r10, [rdi+8]	;x!lf
	xor r11, r11
	cmp r10, 0
	cmovne r11, [r10+24]
	cmp r11, [rcx+24]
	jg make_avl_rebalance_sl_b
	

make_avl_rebalance_sl_a:
	;; (node x!dt x!lf (node d x!rt y))
	or rdi, [rel avl_node_hightag]
	push rdi
	mov rdi, rcx
	call make_avl
	mov rsi, rax
	pop rdi
	and rdi, [rel highmask]
	MOVE_STRING_CHECKED [rdi]
	mov rdx, [rdi+32]
	MOVE_AVL_NODE_CHECKED rbx, [rdi+8]
	mov rdi, rbx
	jmp make_avl

make_avl_rebalance_sl_b:
	;;          (node x!rt!dt (node x!dt x!lf x!rt!lf)
	;;                (node d x!rt!rt y)))
	or rdi, [rel avl_node_hightag]
	push rdi
	MOVE_AVL_NODE_CHECKED rdi, [rcx+16]
	call make_avl
	mov r11, rax
	pop rdi
	and rdi, [rel highmask]
	MOVE_STRING_CHECKED [rdi] ;rax
	mov rdx, [rdi+32]
	mov rdi, r10
	MOVE_AVL_NODE_CHECKED rsi, [rcx+8]
	call make_avl
	mov rdi, rax
	mov rsi, r11
	MOVE_STRING_CHECKED [rcx] ;rax
	mov rdx, [rcx+32]
	jmp make_avl


make_avl_rebalance_sr:
	;; (> depth:y!rt depth:y!lf)
	MOVE_AVL_NODE_CHECKED rcx, [rsi+8]	;y!lf
	cmp rcx, 0
	je make_avl_rebalance_sr_a
	MOVE_AVL_NODE_CHECKED r10, [rsi+16]	;y!rt
	xor r11, r11
	cmp r10, 0
	cmovne r11, [r10+24]
	cmp r11, [rcx+24]
	jg make_avl_rebalance_sr_b

make_avl_rebalance_sr_a:
	;; (node y!dt (node d x y!lf) y!rt)
	or rsi, [rel avl_node_hightag] ;what am I doing with global variables? oh right, 64-bit arg.
	push rsi
	mov rsi, rcx
	call make_avl
	mov rdi, rax
	pop rsi
	and rsi, [rel highmask]
	MOVE_STRING_CHECKED [rsi] ;rax
	mov rdx, [rsi+32]
	MOVE_AVL_NODE_CHECKED rbx, [rsi+16]
	mov rsi, rbx
	jmp make_avl

make_avl_rebalance_sr_b:
	;; (node y!lf!dt (node d x y!lf!lf)
	;;       (node y!dt y!lf!rt y!rt))
	or rsi, [rel avl_node_hightag]
	push rsi
	MOVE_AVL_NODE_CHECKED rsi, [rcx+8]
	call make_avl
	mov r11, rax
	pop rsi
	and rsi, [rel highmask]
	MOVE_STRING_CHECKED [rsi] ;rax
	mov rdx, [rsi+32]
	mov rsi, r10
	MOVE_AVL_NODE_CHECKED rdi, [rcx+16]
	call make_avl
	mov rsi, rax
	mov rdi, r11
	MOVE_STRING_CHECKED [rcx] ;rax
	mov rdx, [rcx+32]
	jmp make_avl



alloc:
	;; argument in rax
	add rax, 7		;round up to 8 bytes
	and al, 0xf8		;geez this is nice
alloc_noround:
	cmp [rel gc_stack], 0	;there we go
	je just_alloc
	push rax		;protecting nothing!
	call gc_steps
	pop rax
just_alloc:
	sub [rel tt], rax	;alloc from top
	mov r14, [rel tt]
	cmp r14, [rel bb]
	jng begin_gc
	mov rax, r14		;where shall gc return its stuff? or should this just jump back up?
	ret

gc_steps:
	;; size in rax; am using that for work factor thing
	;; mov r14, [rel tt]	;?
	imul rax, [rel kk]	;number of bytes to TRACE
	push rdx
	push rcx
	push rbx
	xor rcx, rcx

gc_steps_loop:
	;; I use a wide tag to tag the thing at the top of the GC stack. I think _this_ is pretty
	;; optimal/permissible: it incurs no overhead anywhere but the GC stack, and costs only a couple
	;; of instructions' overhead in this GC loop. And you can put any kind of garbage in a structure
	;; as long as the garbage isn't labeled as pointers.
	;; Meanwhile, how this GC loop knows how to find the pointers in a structure depends on external help.

	;; might need to make boxes twice as big as necessary to ensure the collector stack can be threaded
	;; through them. that's fine. if you really want to make a box that doesn't
	;; hold a pointer (so moving it doesn't require adding stuff to the stack), then fucker can inline
	;; his own move procedure.

	;; hmm. so what we do here is trace. it is technically unnecessary to add to gc_stack any structure
	;; that contains no pointers, because there will be nothing to trace. noice.

	;; now we'll repeatedly: take something from the stack, extract the tag, move all pointers in it
	;; (dispatching based on the tag to do it), and then check whether to continue the loop.
	;; hmm... number of bytes? we're not necessarily moving objects, just updating pointers in objects
	;; that we trace. however, what we can do is keep track of how many bytes are in the objects we trace.
	;; I think that would be good, yeah.
	;; geez, this can actually be run multithreaded for the most part.

	mov rdx, [rel gc_stack]
	shrd rcx, rdx, 8
	shr rcx, 53   ;so good, don't even need to zero rcx beforehand ;OR NOT, need a multiple of 8
	;; now rdx = pointer, rcx = tag
	;; now we want to dispatch based on tag. normally you'd use a jump table.
	;; eh, maybe I can do that.
	;; don't feel like using LEA.
	add rcx, gc_jump_table
	mov rbx, gc_steps_loop
	jmp [rcx]

trace_nothing:
trace_string:
	;; now this is kind of irritating, because memory grows downwards... actually, there's
	;; no reason for that, really. hmm.

trace_avl_node:			;arg in rax; use r14, r13, etc
	mov r14, [rel tt]
	mov r13, rax
	mov rax, [r13+8]
	cmp rax, 




move_avl_node:			;arg in rax, tt in r14
	sub r14, 40
	cmp r14, [rel bb]
	jl

	;; USE A FUCKING MACRO GODDAMMIT
;; move_string_checked:		;arg in rax... won't save rdx (can't)
;; 	cmp rax, [rel fromspace_bottom]
;; 	jl move_string_done
;; 	cmp rax, [rel fromspace_top]
;; 	jg move_string_done
;; 	jmp move_string
;; move_string_done:
;; 	ret

move_string:
	;; string in rax, let's see how little else I can use.
	;; will... save rdx
	;; will save rcx, rdi, rsi.
	;; jesus christ, I'm not moving bytes one by one. strings will fuckin' be stored with a length.
	;; ... I was planning to eventually make that true for every object, but I guess I can do it now.
	;; oh man. empty string? that'll be... less than 16 bytes. eh, as long as strings aren't used
	;; in the stack (which they don't need to be).
	push rdx
	mov rdx, [rax]		;length (bytes) or fwd ptr
	cmp rdx, 0
	jnl move_string_not_so_fast
	neg rdx
	mov rax, rdx
	pop rdx
	ret
move_string_not_so_fast:
	cmovz rdx, 8		;handle empty string...
	add rdx, 15		;round up as well as leave room for length... hm, empty string?
	and dx, 0xfff8		;(note we'll directly copy the length)
	sub [rel tt], rdx
	push rcx
	push rdi
	push rsi
	mov rcx, [rel tt]	;dest
	cmp rcx, [rel bb]
	jl fuck_memory
	mov rdi, rcx		;dest backup
move_string_loop:
	mov rsi, [rax]
	mov [rdi], rsi
	add rax, 8
	add rcx, 8
	sub rdx, 8
	jnz move_string_loop
	;; hmm, interesting question: garbage at the end of the string? seems it'll just be
	;; carried around indefinitely. well, shouldn't cause harm... when strings are eventually
	;; appended or something, I'll have to do some byte-by-byte copying, but no need now.

	mov rdx, rcx
	sub rdx, rdi		;size
	sub rax, rdx		;orig

	mov [rax], rdi		;forwarding ptr
	neg [rax]
	mov rcx, [rel gc_stack]
	mov [rax+8], rcx	;prev stack

	shl rax, 8		;space for...
	or rax, 2		;string tag
	mov [rel gc_stack], rax
	mov rax, rdi
	pop rsi
	pop rdi
	pop rcx
	pop rdx
	ret
	
	
	
	


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
	add [rel bb], 16
	mov rax, [rel bb]
	cmp rax, [rel tospace_top] ;in inlined cases, this check might be unnecessary
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



move_size_shftag:
	;; shftag is 0x<tag>000 0000 0000 0000, convenient for SHLD'ing (and coming from SHRD)
	;; perhaps standardizing tags would be useful
	;; arg in rax, size in rdi, shftag in rsi; fucks with rdx, rcx, r8 (could just save/restore rsi...)
	add [rel bb], rdi
	mov rdx, [rel ]	;dest
	cmp rdx, [rel tospace_bottom]
	jl out_of_memory

	;; now size will be at least 16. unroll unroll unroll... nah. and hypothetically things could be 8.
	mov r8, rax
	add rdx, rdi
	add r8, rdi

move_size_shftag_loop:	

	sub rdx, 8
	sub r8, 8
	mov rcx, [r8]
	mov [rdx], rcx
	cmp r8, rax
	jne move_size_tag_loop
	;; now rdx is new thing, rax is old

	mov [rax], rdx		;forwarding pointer
	neg [rax]
	;; now for stack
	mov rcx, [rel gc_stack]
	mov [rax+8], rcx
	shld rax, rsi, 8
	mov [rel gc_stack], rax
	mov rax, rdx
	ret
	
	
	
	


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


	
	
	





exit:
	mov rax, 0x2000001
	mov rdi, 0
	syscall



done:
	mov rax, 0x2000001
	mov rdi, 0
	syscall


	;; From an epic chat that I didn't send:

;; 	- a tagging register to provide information for GC about values held in registers
;; - use high bits to tag pointers on the stack for GC
;; - simply use "call" and "ret" to call and return from functions, and don't try to change the return address on the stack [note that it's basically impossible to do that with call/ret; if you use "call", then by the time the value is on the stack to change it, you have entered the other function; however, you don't want every function to begin by fucking with the value on the stack; that would be kind of a big waste of time, and also sometimes I enter functions with JMP rather than CALL, in which case it's impossible to do the right thing always unless I leave that information somewhere, which would take even more time]

;; Now there are a couple of things that I didn't have loaded into mind:
;; - that thing about how I'll have to zero things out to be sure that non-pointers are seen as such, and how I'll probably have at least one register be conventionally always a non-pointer.  That's a bit of a pain, but I think I'll be able to deal.
;; - pointers to the middle of objects, how they need to be paired with the original pointer and moved when the original pointer is moved.  I'll need to use the tagging register to tag the middle things as "pointer into paired thing".  Um, I think I _will_ pair registers, and I'll use one bit to indicate whether something is a sub-... no, actually, I just need one bit-pattern to indicate "slave pointer"; 

;; I suspect the strategy of "pointers are tagged by low bits; all things are aligned nicely [except byte strings] and you just repeatedly use "LEA reg, [ptr - tag + index*shift] or whatever; <do crap with [reg]>" might display an advantage here: automatic handling of the tagging issue.

;; Incidentally, the moving of stuff makes it difficult to have really shared structure.  Like, if A is a string, and B is A+20 and so is the substring thing... it'll be fine if A gets moved and then B, but if B gets moved first, then it'll leave a forwarding pointer in the middle of the A string.  'Course, if you really want to, it's pretty easy to work around this by making a structure that has a) a pointer to the original thing and b) a pointer into the middle.

	;; [1].
	;; Suppose the size of a semispace is 256 MB, i.e. 2^28. Then the 28th bit is constant throughout a
	;; semispace. Then, if the 29 th bit in the program's base memory are 10, then we can allocate... 6*256 MB
	;; and be sure of getting two consecutive semispaces with 29 28 bits of 00 01. Then... FUCK.

	;; arc> (fors (x a b f t) 0 3
	;;        (when (and (is (test a x) (test a t))
	;;                   (isnt (test a x) (test a f))
	;;                   (is (test b x) (test b f))
	;;                   (isnt (test b x) (test b t))
	;;                   (is (test a x) (test b x)))
	;;          (prsn x a b f t)))
        ;; 0 1 2 1 2
        ;; 0 2 1 2 1
        ;; 3 1 2 2 1
        ;; 3 2 1 1 2

	;; [2]
	;; I'm going to allocate from both directions. From the bottom is useful when reading in strings
	;; of unknown length. From the top is somewhat easier for allocation, because the "frontier" pointer
	;; that must be stored into memory, and that must be compared with the boundary, is the same as
	;; the pointer of the new place.  like:
	;; ;; from bottom:
	;; mov rax, [rel bb]
	;; add [rel bb], 16
	;; mov rbx, [rel bb]	;can't cmp mem, mem; extra instruction, temp. extra register
	;; cmp rbx, [rel tt]
	;; jg error
	;; ;; or
	;; mov rax, [rel bb]	;separate load, store; also excessive sub
	;; add rax, 16
	;; cmp rax, [rel tt]
	;; jg error
	;; mov [rel bb], rax
	;; sub rax, 16

	;; ;; versus, from top:
	;; sub [rel tt], 16
	;; mov rax, [rel tt]
	;; cmp rax, [rel bb]
	;; jl error
	;; ;; 
