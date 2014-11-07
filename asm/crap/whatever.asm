%line 1+1 jump-table-creation2.asm
[default rel]
[sectalign 8]
%line 6+0 jump-table-creation2.asm
times (((8) - (($-$$) % (8))) % (8)) nop
%line 7+1 jump-table-creation2.asm
 nop
 nop
 nop
 mov rax, 0xfffefafd
[sectalign 8]
%line 11+0 jump-table-creation2.asm
times (((8) - (($-$$) % (8))) % (8)) nop
%line 12+1 jump-table-creation2.asm
%line 23+1 jump-table-creation2.asm
%line 30+1 jump-table-creation2.asm
 call startup
 and rdi, 3
 lea rax, [dickass]
 ret
 jmp [rax + 8*rdi]
[sectalign 8]
%line 67+0 jump-table-creation2.asm
times (((8) - (($-$$) % (8))) % (8)) nop
%line 68+1 jump-table-creation2.asm
the_tables:
%line 77+1 jump-table-creation2.asm
dickass:
%line 77+0 jump-table-creation2.asm
 dq 0
 dq 0
 dq 0
 dq 0
%line 78+1 jump-table-creation2.asm
fuck:
 mov rax, 33
 ret
jerk:
 mov rax, 66
 ret
idiot:
 mov rax, 99
 ret
suck:
 mov rax, 9001
 ret
startup:
%line 112+1 jump-table-creation2.asm
%line 112+0 jump-table-creation2.asm
 ;; lea rax, [jerk]
 ;; mov [dickass + ((0-1)*8)], rax
 ;; lea rax, [fuck]
 ;; mov [dickass + ((1-1)*8)], rax
 ;; lea rax, [idiot]
 ;; mov [dickass + ((2-1)*8)], rax
 ;; lea rax, [suck]
 ;; mov [dickass + ((3-1)*8)], rax
%line 113+1 jump-table-creation2.asm
 ret

        
