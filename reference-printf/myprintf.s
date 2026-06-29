.intel_syntax noprefix
.section .note.GNU-stack,"",@progbits
.text
.global my_printf

# int my_printf(const char *fmt, ...)   -- SysV AMD64 / Linux
# rdi = fmt ; rsi,rdx,rcx,r8,r9 = first 5 varargs (rest on stack -> not handled)
my_printf:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 48                 # save area for the 5 vararg registers (+pad)
    mov     [rsp+0],  rsi
    mov     [rsp+8],  rdx
    mov     [rsp+16], rcx
    mov     [rsp+24], r8
    mov     [rsp+32], r9

    mov     r12, rdi                # r12 = format pointer
    lea     r13, [rsp]              # r13 = pointer to next vararg slot

.Lnext:
    mov     al, [r12]
    test    al, al
    jz      .Ldone
    cmp     al, '%'
    je      .Lspec
    call    putc                    # literal char (al)
    inc     r12
    jmp     .Lnext

.Lspec:
    inc     r12
    mov     al, [r12]
    test    al, al
    jz      .Ldone                  # trailing '%'
    cmp     al, '%'
    je      .Llit
    cmp     al, 'c'
    je      .Ldoc
    cmp     al, 's'
    je      .Ldos
    cmp     al, 'd'
    je      .Ldod
    mov     al, '%'                 # unknown specifier: emit verbatim
    call    putc
    mov     al, [r12]
    call    putc
    inc     r12
    jmp     .Lnext

.Llit:
    mov     al, '%'
    call    putc
    inc     r12
    jmp     .Lnext

.Ldoc:                              # %c
    mov     rax, [r13]
    add     r13, 8
    call    putc
    inc     r12
    jmp     .Lnext

.Ldos:                              # %s
    mov     r14, [r13]
    add     r13, 8
.Ls_loop:
    mov     al, [r14]
    test    al, al
    jz      .Ls_end
    call    putc
    inc     r14
    jmp     .Ls_loop
.Ls_end:
    inc     r12
    jmp     .Lnext

.Ldod:                              # %d (signed 32-bit)
    movsxd  rax, dword ptr [r13]
    add     r13, 8
    sub     rsp, 32                 # scratch buffer, filled backwards
    lea     r14, [rsp+31]
    mov     byte ptr [r14], 0
    xor     r15, r15                # sign flag
    test    rax, rax
    jns     .Ld_loop
    mov     r15, 1
    neg     rax
.Ld_loop:
    xor     rdx, rdx
    mov     rbx, 10
    div     rbx                     # rax=quotient, rdx=remainder
    add     dl, '0'
    dec     r14
    mov     [r14], dl
    test    rax, rax
    jnz     .Ld_loop
    test    r15, r15
    jz      .Ld_print
    dec     r14
    mov     byte ptr [r14], '-'
.Ld_print:
    mov     al, [r14]
    test    al, al
    jz      .Ld_done
    call    putc
    inc     r14
    jmp     .Ld_print
.Ld_done:
    add     rsp, 32
    inc     r12
    jmp     .Lnext

.Ldone:
    add     rsp, 48
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    xor     eax, eax
    ret

# print the single byte in AL to stdout via sys_write
putc:
    sub     rsp, 16
    mov     [rsp], al
    mov     rax, 1                  # sys_write
    mov     rdi, 1                  # fd = stdout
    lea     rsi, [rsp]
    mov     rdx, 1
    syscall
    add     rsp, 16
    ret
