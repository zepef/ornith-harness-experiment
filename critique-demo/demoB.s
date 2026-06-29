.intel_syntax noprefix
.section .note.GNU-stack,"",@progbits
.text
.global run_demo

# "Correction B" avec le SEUL fix de l'erreur d'assemblage (movzx au lieu de mov),
# appliquee a la valeur 42, puis on imprime le buffer (rcx) sur length (rdx).
run_demo:
    push    rbp
    mov     rbp, rsp
    mov     rdi, 42          # <<< la valeur a convertir est 42
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
    xor     edx, edx         # ecrase le "compteur de longueur"...
    div     rbx              # ...et div divise rdx:rax — or rax n'a JAMAIS recu rdi(=42)
    add     dl, '0'
    dec     rcx
    inc     edx              # corrompt le chiffre stocke (digit+1)
    mov     [rcx], dl
    test    rax, rax
    jnz     .l
    mov     edx, edx         # zero-extend edx->rdx (movzx 32->64 illegal aussi)

    mov     rsi, rcx         # imprimer ce que la "Correction B" a produit
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
