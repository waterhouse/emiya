%line 1+1 repl6.asm
[section .data]
loop_str: db "loop", 10, 0
str_str: db "%s", 10, 0
num_str: db "%ld", 10, 0
big_err: db "I don't know who I am anymore!", 10, 0
not_found_str: db "Didn't find %s", 10, 0
err_str: db "Oh fuck me there was an error", 10, 0
bad_str: db "Bad input: %s", 10, 0
die_str: db "Out of memory. This should be fixed in the future.", 10, 0





















































tospace_top: dq 0
tospace_bottom: dq 0
fromspace_top: dq 0
fromspace_bottom: dq 0

kk: dq 4
bb: dq 0
tt: dq 0

gc_stack: dq 0











gc_jump_table: dq gc_jump
gc_jump:
 dq trace_nothing
 dq trace_string
 dq trace_avl_node


checked_move_table: dq checked_move
checked_move:
 dq checked_move_nothing
 dq checked_move_string
 dq checked_move_avl_node
move_table: dq the_move_table
the_move_table:
 dq move_nothing
 dq move_string
 dq move_avl_node


tree: dq 0
stack_top: dq 0

avl_node_hightag: dq 0x2000000000000000
highmask: dq 0x0fffffffffffffff
hightag: dq 0xf000000000000000
r10_avl_tag: dq 0x0000020000000000
r11_avl_tag: dq 0x0000200000000000
rcx_r10_avl: dq 0x0000020000000200
r10_r11_mask: dq 0xffff00ffffffffff




%line 129+1 repl6.asm

%line 142+1 repl6.asm

%line 153+1 repl6.asm

%line 187+1 repl6.asm






[section .bss]
buf: resb 32


[section .text]

[extern _printf]
[extern _read]
[extern _write]
[extern _sleep]
[extern _exit]
[extern _mmap]
[extern _munmap]

[global start]
start:



















 mov rbp, rsp
 and sp, 0xfff0

 cmp qword [rbp], 2
 jl done

 mov rax, 1
 call read_intarg
 add rax, 15
 and ax, 0xfff8
 mov r12, rax
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




loop:




 call print_rax
%line 260+0 repl6.asm
 mov rax, qword [rel gc_stack]
 call print_rax
 mov rax, 69
 call print_rax
 mov rax, 0
 cmp qword [rel gc_stack], rax
 ja ..@11.do_work
..@11.get_ass:
 mov rax, 32
 call print_rax
 sub qword [rel tt], 40
 mov rax, [rel tt]
 cmp rax, [rel bb]
 jg ..@11.done
..@11.begin_gc:
 xor rax, rax
 call gc_flip
 jmp ..@11.get_ass
..@11.do_work:
 call print_rax
 push rax
 mov rax, rax
 mov rax, 40
 call gc_steps
 mov rax, rax
 pop rax
 mov rax, 69
 call print_rax
 jmp ..@11.get_ass
..@11.done:
%line 261+1 repl6.asm
 mov r12, rax


 mov rsi, rax
 add rsi, 8
 xor rax, rax
 mov rdi, 0
 mov rdx, 32
 call _read

 cmp rax, 0
 je done
 cmp rax, -1
 je doh





 mov r13, rax
 mov rcx, r12
 add rcx, r13
 mov byte [rcx], 0




 mov rcx, r12
find_space:
 inc rcx
 cmp byte [rcx], 10
 je found_newline
 cmp byte [rcx], 32
 je found_space
 cmp byte [rcx], 0
 je bad_input
 jmp find_space

found_newline:
 mov byte [rcx], 0
 mov rbx, r12




 sub rcx, r12
 mov [r12], rcx
 mov rdx, [rel tree]
 call lookup
 jc not_found

 mov rdi, num_str
 mov rsi, rax
 xor rax, rax
 call _printf
 jmp loop

not_found:
 mov rdi, not_found_str
 mov rsi, r12
 xor rax, rax
 call _printf
 jmp loop

found_space:


 sub rcx, r12
 mov [r12], rcx
 add rcx, r12
 inc rcx
 mov rax, rcx

 call parse_int


 mov r8, r12
 mov r9, rax
 mov rsi, [rel tree]

 mov r15, 0x0000000200100002
 call avl_add_dca
 xor r15, r15
 jmp loop

bad_input:
 mov rdi, bad_str
 mov rsi, r12
 xor rax, rax
 call _printf
 jmp loop



 xor rax, rax
 mov rdi, 0
 mov rsi, buf
 mov rdx, r10
 call _write

 cmp rax, 0
 jl doh

 jmp loop

 jmp done


parse_int:


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



 shl rax, 3
 add rax, rbp
 mov rax, [rax+8]



 jmp parse_int

doh: xor rax, rax
 mov rdi, err_str
 call _printf
 jmp done






claim_memory:
 push rbp
 mov rbp, rsp
 and sp, 0xfff0


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


str_cmp:




 push rax
 push rdx
 mov rdx, [rax]
 cmp rdx, [rdi]
 cmovg rdx, [rdi]
 add rax, 8
 add rdi, 8
 jmp str_cmp_loop
str_cmp_step:
 inc rax
 inc rdi
str_cmp_loop:
 cmp rdx, 0
 je str_cmp_out
 mov cl, [rax]
 cmp cl, [rdi]
 setb al


 je str_cmp_step
 inc rax
 and rax, 2
 dec rax
 pop rdx
 add rsp, 8
 ret
str_cmp_out:
 pop rdx
 sub rax, [rsp]
 add rdi, rax
 pop rax



 mov rax, [rax]
 cmp rax, [rdi]
 setl al
 setg cl
 sub al, cl
 movsx rax, al
 ret

lookup:

 cmp rdx, 0
 je lookup_fail
 mov rax, [rdx]
%line 504+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@12.ok
 cmp rax, [rel fromspace_top]
 jnl ..@12.ok

 call move_string

 mov [rdx], rax
..@12.ok:
%line 505+1 repl6.asm
 mov rdi, rbx
 call str_cmp
 cmp rax, 1
 je lookup_left
 cmp rax, -1
 je lookup_right
 mov rax, [rdx+32]
 ret
lookup_left:
 mov rax, [rdx+8]
%line 514+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@13.ok
 cmp rax, [rel fromspace_top]
 jnl ..@13.ok
 call move_avl_node
 mov [rdx+8], rax
..@13.ok:
%line 515+1 repl6.asm
 mov rdx, rax
 jmp lookup
lookup_right:
 mov rax, [rdx+16]
%line 518+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@14.ok
 cmp rax, [rel fromspace_top]
 jnl ..@14.ok
 call move_avl_node
 mov [rdx+16], rax
..@14.ok:
%line 519+1 repl6.asm
 mov rdx, rax
 jmp lookup
lookup_fail:
 stc
 ret













make_avl:


 call print_rax
%line 540+0 repl6.asm
 mov rax, qword [rel gc_stack]
 call print_rax
 mov rax, 69
 call print_rax
 mov rax, 0
 cmp qword [rel gc_stack], rax
 ja ..@15.do_work
..@15.get_ass:
 mov rax, 32
 call print_rax
 sub qword [rel tt], 40
 mov rbx, [rel tt]
 cmp rbx, [rel bb]
 jg ..@15.done
..@15.begin_gc:
 xor rbx, rbx
 call gc_flip
 jmp ..@15.get_ass
..@15.do_work:
 call print_rax
 push rbx
 mov rbx, rax
 mov rax, 40
 call gc_steps
 mov rax, rbx
 pop rbx
 mov rax, 69
 call print_rax
 jmp ..@15.get_ass
..@15.done:
%line 541+1 repl6.asm
 mov [rbx], rax
 mov [rbx+8], rdi
 mov [rbx+16], rsi
 mov [rbx+32], rdx


 cmp rdi, 0
 cmova rdi, [rdi+24]
 cmp rsi, 0
 cmova rsi, [rsi+24]
 cmp rdi, rsi
 cmova rsi, rdi
 inc rsi
 mov [rbx+24], rsi
 mov rax, rbx
 ret

avl_add:












 mov r8, rax
 mov r9, rdi




avl_add_dca:
 cmp rsi, 0
 je avl_add_make_bottom
 mov rax, [rsi]
%line 580+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@16.ok
 cmp rax, [rel fromspace_top]
 jnl ..@16.ok

 call move_string

 mov [rsi], rax
..@16.ok:
%line 581+1 repl6.asm
 mov rdi, r8
 add rax, 8
 add rdi, 8
 call str_cmp
 cmp rax, 0
 je avl_add_make_bottom

 mov rbx, rsi
 or rbx, [rel avl_node_hightag]
 push rbx
 cmp rax, 0
 jl insert_right

insert_left:
 mov rbx, [rsi+8]
%line 595+0 repl6.asm
 cmp rbx, [rel fromspace_bottom]
 jl ..@17.ok
 cmp rbx, [rel fromspace_top]
 jnl ..@17.ok
 xchg rax, rbx
 call move_avl_node
 xchg rax, rbx
 mov [rsi+8], rbx
..@17.ok:
%line 596+1 repl6.asm
 mov rsi, rbx
 call avl_add_dca



 pop rsi
 and rsi, [rel highmask]

 mov rdi, rax
 mov rax, [rsi]
%line 605+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@18.ok
 cmp rax, [rel fromspace_top]
 jnl ..@18.ok

 call move_string

 mov [rsi], rax
..@18.ok:
%line 606+1 repl6.asm
 mov rbx, [rsi+16]
%line 606+0 repl6.asm
 cmp rbx, [rel fromspace_bottom]
 jl ..@19.ok
 cmp rbx, [rel fromspace_top]
 jnl ..@19.ok
 xchg rax, rbx
 call move_avl_node
 xchg rax, rbx
 mov [rsi+16], rbx
..@19.ok:
%line 607+1 repl6.asm
 mov rdx, [rsi+32]
 mov rsi, rbx
 jmp make_avl_rebalance


insert_right:
 mov rbx, [rsi+16]
%line 613+0 repl6.asm
 cmp rbx, [rel fromspace_bottom]
 jl ..@20.ok
 cmp rbx, [rel fromspace_top]
 jnl ..@20.ok
 xchg rax, rbx
 call move_avl_node
 xchg rax, rbx
 mov [rsi+16], rbx
..@20.ok:
%line 614+1 repl6.asm
 mov rsi, rbx
 call avl_add_dca
 pop rdi
 and rdi, [rel highmask]
 mov rsi, rax
 mov rax, [rdi]
%line 619+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@21.ok
 cmp rax, [rel fromspace_top]
 jnl ..@21.ok

 call move_string

 mov [rdi], rax
..@21.ok:
%line 620+1 repl6.asm
 mov rdx, [rdi+32]
 mov rbx, [rdi+8]
%line 621+0 repl6.asm
 cmp rbx, [rel fromspace_bottom]
 jl ..@22.ok
 cmp rbx, [rel fromspace_top]
 jnl ..@22.ok
 xchg rax, rbx
 call move_avl_node
 xchg rax, rbx
 mov [rdi+8], rbx
..@22.ok:
%line 622+1 repl6.asm
 mov rdi, rbx
 jmp make_avl_rebalance

avl_add_make_bottom:


 mov rax, r8
 mov rdx, r9
 xor rdi, rdi
 xor rsi, rsi

 mov r15, 0x0000000000220001
 jmp make_avl

make_avl_rebalance:























 xor r10, r10
 cmp rdi, 0
 cmova r10, [rdi+24]
 xor r11, r11
 cmp rsi, 0
 cmova r11, [rsi+24]

 sub r10, r11
 cmp r10, -1
 jl make_avl_rebalance_sr
 cmp r10, 1
 jg make_avl_rebalance_sl

 jmp make_avl




make_avl_rebalance_sl:

 mov rcx, [rdi+16]
%line 680+0 repl6.asm
 cmp rcx, [rel fromspace_bottom]
 jl ..@23.ok
 cmp rcx, [rel fromspace_top]
 jnl ..@23.ok
 xchg rax, rcx
 call move_avl_node
 xchg rax, rcx
 mov [rdi+16], rcx
..@23.ok:
%line 681+1 repl6.asm

 cmp rcx, 0
 je make_avl_rebalance_sl_a
 mov r10, [rdi+8]
%line 684+0 repl6.asm
 cmp r10, [rel fromspace_bottom]
 jl ..@24.ok
 cmp r10, [rel fromspace_top]
 jnl ..@24.ok
 xchg rax, r10
 call move_avl_node
 xchg rax, r10
 mov [rdi+8], r10
..@24.ok:
%line 685+1 repl6.asm
 xor r11, r11
 cmp r10, 0
 cmovne r11, [r10+24]
 cmp r11, [rcx+24]
 jg make_avl_rebalance_sl_b


make_avl_rebalance_sl_a:

 or rdi, [rel avl_node_hightag]
 push rdi
 mov rdi, rcx
 call make_avl
 mov rsi, rax
 pop rdi
 and rdi, [rel highmask]
 mov rax, [rdi]
%line 701+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@25.ok
 cmp rax, [rel fromspace_top]
 jnl ..@25.ok

 call move_string

 mov [rdi], rax
..@25.ok:
%line 702+1 repl6.asm
 mov rdx, [rdi+32]
 mov rbx, [rdi+8]
%line 703+0 repl6.asm
 cmp rbx, [rel fromspace_bottom]
 jl ..@26.ok
 cmp rbx, [rel fromspace_top]
 jnl ..@26.ok
 xchg rax, rbx
 call move_avl_node
 xchg rax, rbx
 mov [rdi+8], rbx
..@26.ok:
%line 704+1 repl6.asm
 mov rdi, rbx
 jmp make_avl

make_avl_rebalance_sl_b:


 or rdi, [rel avl_node_hightag]
 push rdi
 mov rdi, [rcx+16]
%line 712+0 repl6.asm
 cmp rdi, [rel fromspace_bottom]
 jl ..@27.ok
 cmp rdi, [rel fromspace_top]
 jnl ..@27.ok
 xchg rax, rdi
 call move_avl_node
 xchg rax, rdi
 mov [rcx+16], rdi
..@27.ok:
%line 713+1 repl6.asm

 or r15, [rel rcx_r10_avl]
 call make_avl
 pop rbx
 push rax
 and rbx, [rel highmask]
 mov rax, [rbx]
%line 719+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@28.ok
 cmp rax, [rel fromspace_top]
 jnl ..@28.ok

 call move_string

 mov [rbx], rax
..@28.ok:
%line 720+1 repl6.asm
 mov rdx, [rbx+32]
 mov rdi, r10
 pop r10
 mov rsi, [rcx+8]
%line 723+0 repl6.asm
 cmp rsi, [rel fromspace_bottom]
 jl ..@29.ok
 cmp rsi, [rel fromspace_top]
 jnl ..@29.ok
 xchg rax, rsi
 call move_avl_node
 xchg rax, rsi
 mov [rcx+8], rsi
..@29.ok:
%line 724+1 repl6.asm
 call make_avl
 mov rdi, rax
 mov rsi, r10
 mov rax, [rcx]
%line 727+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@30.ok
 cmp rax, [rel fromspace_top]
 jnl ..@30.ok

 call move_string

 mov [rcx], rax
..@30.ok:
%line 728+1 repl6.asm
 mov rdx, [rcx+32]
 xor r15, [rel rcx_r10_avl]
 jmp make_avl


make_avl_rebalance_sr:

 mov rcx, [rsi+8]
%line 735+0 repl6.asm
 cmp rcx, [rel fromspace_bottom]
 jl ..@31.ok
 cmp rcx, [rel fromspace_top]
 jnl ..@31.ok
 xchg rax, rcx
 call move_avl_node
 xchg rax, rcx
 mov [rsi+8], rcx
..@31.ok:
%line 736+1 repl6.asm
 cmp rcx, 0
 je make_avl_rebalance_sr_a
 mov r10, [rsi+16]
%line 738+0 repl6.asm
 cmp r10, [rel fromspace_bottom]
 jl ..@32.ok
 cmp r10, [rel fromspace_top]
 jnl ..@32.ok
 xchg rax, r10
 call move_avl_node
 xchg rax, r10
 mov [rsi+16], r10
..@32.ok:
%line 739+1 repl6.asm
 xor r11, r11
 cmp r10, 0
 cmovne r11, [r10+24]
 cmp r11, [rcx+24]
 jg make_avl_rebalance_sr_b

make_avl_rebalance_sr_a:

 or rsi, [rel avl_node_hightag]
 push rsi
 mov rsi, rcx
 call make_avl
 mov rdi, rax
 pop rsi
 and rsi, [rel highmask]
 mov rax, [rsi]
%line 754+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@33.ok
 cmp rax, [rel fromspace_top]
 jnl ..@33.ok

 call move_string

 mov [rsi], rax
..@33.ok:
%line 755+1 repl6.asm
 mov rdx, [rsi+32]
 mov rbx, [rsi+16]
%line 756+0 repl6.asm
 cmp rbx, [rel fromspace_bottom]
 jl ..@34.ok
 cmp rbx, [rel fromspace_top]
 jnl ..@34.ok
 xchg rax, rbx
 call move_avl_node
 xchg rax, rbx
 mov [rsi+16], rbx
..@34.ok:
%line 757+1 repl6.asm
 mov rsi, rbx
 jmp make_avl

make_avl_rebalance_sr_b:


 or rsi, [rel avl_node_hightag]
 push rsi
 mov rsi, [rcx+8]
%line 765+0 repl6.asm
 cmp rsi, [rel fromspace_bottom]
 jl ..@35.ok
 cmp rsi, [rel fromspace_top]
 jnl ..@35.ok
 xchg rax, rsi
 call move_avl_node
 xchg rax, rsi
 mov [rcx+8], rsi
..@35.ok:
%line 766+1 repl6.asm
 or r15, [rel rcx_r10_avl]
 call make_avl
 pop rsi
 and rsi, [rel highmask]
 push rax
 mov rax, [rsi]
%line 771+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@36.ok
 cmp rax, [rel fromspace_top]
 jnl ..@36.ok

 call move_string

 mov [rsi], rax
..@36.ok:
%line 772+1 repl6.asm
 mov rdx, [rsi+32]
 mov rsi, r10
 pop r10
 mov rdi, [rcx+16]
%line 775+0 repl6.asm
 cmp rdi, [rel fromspace_bottom]
 jl ..@37.ok
 cmp rdi, [rel fromspace_top]
 jnl ..@37.ok
 xchg rax, rdi
 call move_avl_node
 xchg rax, rdi
 mov [rcx+16], rdi
..@37.ok:
%line 776+1 repl6.asm
 call make_avl
 mov rsi, rax
 mov rdi, r10
 mov rax, [rcx]
%line 779+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@38.ok
 cmp rax, [rel fromspace_top]
 jnl ..@38.ok

 call move_string

 mov [rcx], rax
..@38.ok:
%line 780+1 repl6.asm
 mov rdx, [rcx+32]
 xor r15, [rel rcx_r10_avl]
 jmp make_avl








































gc_steps:


 imul rax, [rel kk]
 push rdx
 push rcx
 push rbx
 mov rax, [rel gc_stack]
 call print_rax
 xor rcx, rcx
 mov r13, rax

gc_steps_loop:





















 mov rbx, [rel gc_stack]
 shrd rcx, rbx, 8
 shr rcx, 53

 mov rdx, [rbx]
 neg rdx
 mov rbx, [rbx+8]
 mov [rel gc_stack], rbx




 add rcx, [rel gc_jump_table]
 call [rcx]
 jg gc_steps_loop

trace_nothing:
 ret
trace_string:
 mov rbx, [rdx]
 sub r13, rbx
 ret
trace_avl_node:
 mov rax, [rdx]
%line 880+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@39.ok
 cmp rax, [rel fromspace_top]
 jnl ..@39.ok

 call move_string

 mov [rdx], rax
..@39.ok:
%line 881+1 repl6.asm
 mov rax, [rdx+8]
%line 881+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@40.ok
 cmp rax, [rel fromspace_top]
 jnl ..@40.ok
 call move_avl_node
 mov [rdx+8], rax
..@40.ok:
%line 882+1 repl6.asm
 mov rax, [rdx+16]
%line 882+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@41.ok
 cmp rax, [rel fromspace_top]
 jnl ..@41.ok
 call move_avl_node
 mov [rdx+16], rax
..@41.ok:
%line 883+1 repl6.asm
 sub r13, 40
 ret

checked_move_nothing:
 ret

checked_move_avl_node:
 cmp rax, [rel fromspace_bottom]
 jl avl_node_fine
 cmp rax, [rel fromspace_top]
 jnl avl_node_fine
 jmp move_avl_node
avl_node_fine:
 ret
move_avl_node:
 cmp qword [rax], 0
 jnl actually_move_avl_node
 mov rax, [rax]
 neg rax
 ret
actually_move_avl_node:
 sub qword [rel tt], 40
 mov r14, [rel tt]
 cmp r14, [rel bb]
 jl fuck_memory
 push rcx

 mov rcx, [rax]
 mov [r14], rcx
 mov rcx, [rax+8]
 mov [r14+8], rcx
 mov rcx, [rax+16]
 mov [r14+16], rcx
 mov rcx, [rax+24]
 mov [r14+24], rcx
 mov rcx, [rax+32]
 mov [r14+32], rcx

 mov [rax], r14
 neg qword [rax]



 mov rcx, [rel gc_stack]
 mov [rax+8], rcx
 xchg r14, rax
 shl r14, 8
 or r14, 0x2
 mov [rel gc_stack], r14
 pop rcx
 ret

checked_move_string:
 cmp rax, [rel fromspace_bottom]
 jl checked_move_string_ret
 cmp rax, [rel fromspace_top]
 jnl checked_move_string_ret
 jmp move_string
checked_move_string_ret:
 ret
move_nothing:
 ret
move_string:



 push rdx
 mov rdx, [rax]
 cmp rdx, 0
 jnl actually_move_string
 neg rdx
 mov rax, rdx
 pop rdx
 ret
actually_move_string:
 setz dl
 add rdx, 15
 and dx, 0xfff8
 sub [rel tt], rdx
 push rcx
 push rdi
 push rsi
 mov rcx, [rel tt]
 cmp rcx, [rel bb]
 jl fuck_memory
 mov rdi, rcx
move_string_loop:
 mov rsi, [rax]
 mov [rdi], rsi
 add rax, 8
 add rcx, 8
 sub rdx, 8
 jnz move_string_loop




 mov rdx, rcx
 sub rdx, rdi
 sub rax, rdx

 mov [rax], rdi
 neg qword [rax]
 mov rcx, [rel gc_stack]
 mov [rax+8], rcx

 shl rax, 8
 or rax, 2
 mov [rel gc_stack], rax
 mov rax, rdi
 pop rsi
 pop rdi
 pop rcx
 pop rdx
 ret

gc_flip:



 push rax
 mov rax, [rel tospace_top]
 xchg [rel fromspace_top], rax
 mov [rel tospace_top], rax
 mov [rel tt], rax
 mov [rel tospace_bottom], rax
 xchg [rel fromspace_bottom], rax
 mov [rel tospace_bottom], rax
 mov [rel bb], rax

 cmp qword [rel gc_stack], 0
 jne fuck_memory




 push r14
 mov rax, [rel tree]
%line 1020+0 repl6.asm
 cmp rax, [rel fromspace_bottom]
 jl ..@42.ok
 cmp rax, [rel fromspace_top]
 jnl ..@42.ok
 call move_avl_node
 mov [rel tree], rax
..@42.ok:
%line 1021+1 repl6.asm
 pop r14
 pop rax



 push r15
 push r14








%line 1045+1 repl6.asm

%line 1079+1 repl6.asm

 mov r14, 0b00001111
%line 1080+0 repl6.asm
 and r14, r15
 cmp r14, 0b00001111
 je ..@43.move_reg2_first
 mov r14, 0b11110000
 and r14, r15
 cmp r14, 0b11110000
 je ..@43.move_reg1_first
 xchg rax, rax
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rax
 xchg rax, rbx
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rbx
 jmp ..@43.done
..@43.move_reg1_first:
 sub rbx, rax
 xchg rax, rax
 shl r14, 3
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rax
 add rbx, rax
 shr r15, 8
 jmp ..@43.done
..@43.move_reg2_first:
 sub rax, rbx
 xchg rax, rbx
 shr r14, 1
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rbx
 shr r15, 8
 add rax, rbx
..@43.done:
%line 1081+1 repl6.asm
 mov r14, 0b00001111
%line 1081+0 repl6.asm
 and r14, r15
 cmp r14, 0b00001111
 je ..@46.move_reg2_first
 mov r14, 0b11110000
 and r14, r15
 cmp r14, 0b11110000
 je ..@46.move_reg1_first
 xchg rax, rcx
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rcx
 xchg rax, rdx
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rdx
 jmp ..@46.done
..@46.move_reg1_first:
 sub rdx, rcx
 xchg rax, rcx
 shl r14, 3
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rcx
 add rdx, rcx
 shr r15, 8
 jmp ..@46.done
..@46.move_reg2_first:
 sub rcx, rdx
 xchg rax, rdx
 shr r14, 1
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rdx
 shr r15, 8
 add rcx, rdx
..@46.done:
%line 1082+1 repl6.asm
 mov r14, 0b00001111
%line 1082+0 repl6.asm
 and r14, r15
 cmp r14, 0b00001111
 je ..@49.move_reg2_first
 mov r14, 0b11110000
 and r14, r15
 cmp r14, 0b11110000
 je ..@49.move_reg1_first
 xchg rax, rdi
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rdi
 xchg rax, rsi
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rsi
 jmp ..@49.done
..@49.move_reg1_first:
 sub rsi, rdi
 xchg rax, rdi
 shl r14, 3
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rdi
 add rsi, rdi
 shr r15, 8
 jmp ..@49.done
..@49.move_reg2_first:
 sub rdi, rsi
 xchg rax, rsi
 shr r14, 1
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rsi
 shr r15, 8
 add rdi, rsi
..@49.done:
%line 1083+1 repl6.asm
 shr r15, 4
 xchg rax, rbp
%line 1084+0 repl6.asm
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, rbp
%line 1085+1 repl6.asm
 mov r14, 0b00001111
%line 1085+0 repl6.asm
 and r14, r15
 cmp r14, 0b00001111
 je ..@53.move_reg2_first
 mov r14, 0b11110000
 and r14, r15
 cmp r14, 0b11110000
 je ..@53.move_reg1_first
 xchg rax, r8
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r8
 xchg rax, r9
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r9
 jmp ..@53.done
..@53.move_reg1_first:
 sub r9, r8
 xchg rax, r8
 shl r14, 3
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r8
 add r9, r8
 shr r15, 8
 jmp ..@53.done
..@53.move_reg2_first:
 sub r8, r9
 xchg rax, r9
 shr r14, 1
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r9
 shr r15, 8
 add r8, r9
..@53.done:
%line 1086+1 repl6.asm
 mov r14, 0b00001111
%line 1086+0 repl6.asm
 and r14, r15
 cmp r14, 0b00001111
 je ..@56.move_reg2_first
 mov r14, 0b11110000
 and r14, r15
 cmp r14, 0b11110000
 je ..@56.move_reg1_first
 xchg rax, r10
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r10
 xchg rax, r11
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r11
 jmp ..@56.done
..@56.move_reg1_first:
 sub r11, r10
 xchg rax, r10
 shl r14, 3
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r10
 add r11, r10
 shr r15, 8
 jmp ..@56.done
..@56.move_reg2_first:
 sub r10, r11
 xchg rax, r11
 shr r14, 1
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r11
 shr r15, 8
 add r10, r11
..@56.done:
%line 1087+1 repl6.asm
 mov r14, 0b00001111
%line 1087+0 repl6.asm
 and r14, r15
 cmp r14, 0b00001111
 je ..@59.move_reg2_first
 mov r14, 0b11110000
 and r14, r15
 cmp r14, 0b11110000
 je ..@59.move_reg1_first
 xchg rax, r12
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r12
 xchg rax, r13
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r13
 jmp ..@59.done
..@59.move_reg1_first:
 sub r13, r12
 xchg rax, r12
 shl r14, 3
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r12
 add r13, r12
 shr r15, 8
 jmp ..@59.done
..@59.move_reg2_first:
 sub r12, r13
 xchg rax, r13
 shr r14, 1
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r13
 shr r15, 8
 add r12, r13
..@59.done:
%line 1088+1 repl6.asm
 pop r14
 push rax
 xchg rax, r14
%line 1090+0 repl6.asm
 xor r14, r14
 shrd r14, r15, 4
 shr r14, 57
 add r14, [rel checked_move_table]
 call [r14]
 xchg rax, r14
%line 1091+1 repl6.asm
 pop rax
 pop r15


 push rax
 push rbx
 push rcx
 push rdx
 push rsi
 mov rcx, hightag
 mov rbx, rsp
 add rbx, 32
trace_stack_loop:
 add rbx, 8
 cmp rbx, [rel stack_top]
 je trace_stack_done
 test [rbx], rcx
 jz trace_stack_loop
 mov rax, [rbx]
 xor rdx, rdx
 shld rdx, rax, 4
 jz trace_stack_loop
 shr rax, 4
 cmp rax, [rel fromspace_bottom]
 jl trace_stack_loop
 cmp rax, [rel fromspace_top]
 jnl trace_stack_loop
 mov rdi, rdx
 add rdx, [rel move_table]
 call [rdx]
 shl rdi, 60
 or rax, rdi
 mov [rbx], rax
 jmp trace_stack_loop
trace_stack_done:
 pop rsi
 pop rdx
 pop rcx
 pop rbx
 pop rax

 ret




















fuck_memory:
 mov rdi, die_str
 xor rax, rax
 call _printf

done:
exit:

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


























































