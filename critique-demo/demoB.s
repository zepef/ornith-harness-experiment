.intel_syntax noprefix
.section .note.GNU-stack,"",@progbits
.text
.global run_demo

# "Correction B" with ONLY the assembler-error fixed (mov edx,edx instead of mov rdx,edx),
# applied to the value 42, then we print the buffer (rcx) with length (rdx).
run_demo:
    push    rbp
    mov     rbp, rsp
    mov     rdi, 42          # <<< the value to convert is 42
    sub     rsp, 32
    lea     rcx, [rsp+31]
    xor     edx, edx
    test    rdi, rdi
    jns     .p
    mov     byte ptr [rcx-1], '-'
    dec     rcx
    neg     rdi
.p:
    mov     rbx, 10
.l:
    xor     edx, edx         # wipes the "length counter"...
    div     rbx              # ...and div divides rdx:rax — but rax NEVER received rdi(=42)
    add     dl, '0'
    dec     rcx
    inc     edx              # corrupts the stored digit (digit+1)
    mov     [rcx], dl
    test    rax, rax
    jnz     .l
    mov     edx, edx         # zero-extend edx->rdx (movzx 32->64 is illegal too)

    mov     rsi, rcx         # print whatever "Correction B" produced
    mov     rax, 1
    mov     rdi, 1
    syscall
    mov     byte ptr [rsp], 10
    mov     rax, 1
    mov     rdi, 1
    lea     rsi, [rsp]
    mov     rdx, 1
    syscall

    add     rsp, 32
    pop     rbp
    ret
