.intel_syntax noprefix
.section .note.GNU-stack,"",@progbits
.text
.global print_int_buggy

# "Correction B" from the critique, transcribed faithfully
print_int_buggy:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 32
    lea     rcx, [rsp+31]   # end of buffer
    xor     edx, edx        # "Length counter = 0"
    test    rdi, rdi
    jns     .positive
    mov     byte ptr [rcx-1], '-'
    dec     rcx
    neg     rdi             # Make positive
.positive:
    mov     rbx, 10
.conv_loop:
    xor     edx, edx        # "Clear remainder"
    div     rbx             # rax = q, rdx = r
    add     dl, '0'
    dec     rcx
    inc     edx             # "Increment length counter"
    mov     [rcx], dl       # Store digit
    test    rax, rax
    jnz     .conv_loop
    mov     rdx, edx        # "Move length to rdx"
    pop     rbp
    ret
