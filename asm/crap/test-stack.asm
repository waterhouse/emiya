

        mov rax, 0xfffefafd








nerf:
        dec rdi
        jz done
        call nerf
done:
        ret