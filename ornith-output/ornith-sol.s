.intel_syntax noprefix
.global my_printf

my_printf:
    push rbp                  # save old frame pointer
    mov rbp, rsp              # set new frame pointer
    
    sub rsp, 320              # allocate space for locals and args
    
    # Save callee-saved registers to known locations
    mov qword ptr [rbp-16], rbx     # save rbx at [rbp-16]
    mov qword ptr [rbp-24], r12     # save r12 at [rbp-24]
    mov qword ptr [rbp-32], r13     # save r13 at [rbp-32]
    mov qword ptr [rbp-40], r14     # save r14 at [rbp-40]
    mov qword ptr [rbp-48], r15     # save r15 at [rbp-48]
    
    # Save vararg registers to memory (BEFORE they get clobbered)
    mov qword ptr [rbp-56], rsi     # save arg 0 (rsi) at [rbp-56]
    mov qword ptr [rbp-64], rdx     # save arg 1 (rdx) at [rbp-64]
    mov qword ptr [rbp-72], rcx     # save arg 2 (rcx) at [rbp-72]
    mov qword ptr [rbp-80], r8      # save arg 3 (r8) at [rbp-80]
    mov qword ptr [rbp-88], r9      # save arg 4 (r9) at [rbp-88]
    
    mov r12, rdi              # fmt_ptr = format string pointer (from rdi)
    xor ebx, ebx              # arg_idx = 0
    lea r14, [rsp]            # write_buf at current rsp (bottom of allocation)

format_loop:
    movzx eax, byte ptr [r12]     # load current char
    test al, al                   # check for null terminator
    jz done_format

    cmp al, '%'
    je check_specifier
    jmp output_char

check_specifier:
    lea r13, [r12 + 1]            # point to next char after %
    movzx eax, byte ptr [r13]     # load specifier char

    cmp al, 's'
    je handle_s
    cmp al, 'd'
    je handle_d
    cmp al, 'c'
    je handle_c
    cmp al, '%'
    je handle_percent

    # Unknown specifier - output % literally and advance past it
    mov byte ptr [r14], '%'
    mov rsi, r14                  # set buffer pointer
    mov edx, 1                    # set length
    call do_write
    add r12, 1                      # advance past the first %
    jmp format_loop

output_char:
    mov byte ptr [r14], al
    mov rsi, r14                  # set buffer pointer
    mov edx, 1                    # set length
    call do_write
    add r12, 1                      # advance past literal char
    jmp format_loop

handle_s:
    cmp ebx, 5
    jb fetch_reg_s
    # Read from stack for args beyond the first 5 (arg indices 5+)
    mov rax, qword ptr [rbp + 8*(ebx - 3)]
    jmp load_ptr_done
fetch_reg_s:
    # Fetch from saved register slots
    mov rax, qword ptr [rbp - 56 - rbx*8]
    jmp load_ptr_done
.s_rsi:
    mov rax, rsi
    jmp load_ptr_done
.s_rdx:
    mov rax, rdx
    jmp load_ptr_done
.s_rcx:
    mov rax, rcx
    jmp load_ptr_done
.s_r8:
    mov rax, r8
    jmp load_ptr_done
load_ptr_done:
    test rax, rax                   # check for NULL pointer
    jz .skip_s
    mov r15, rax                    # save string ptr in callee-saved reg
    xor ecx, ecx                    # count = 0
.skip_s_loop:
    cmp byte ptr [r15 + rcx], 0
    je .skip_s_done
    inc ecx
    jmp .skip_s_loop
.skip_s_done:
    mov rsi, r15                    # buf ptr for write
    mov edx, ecx                    # count for write
    call do_write
.skip_s:
    add ebx, 1                      # arg_idx++
    lea r12, [r13 + 1]              # fmt_ptr = after specifier char
    jmp format_loop

handle_d:
    cmp ebx, 5
    jb fetch_reg_d
    # Read from stack for args beyond the first 5 (arg indices 5+)
    mov rax, qword ptr [rbp + 8*(ebx - 3)]
    jmp load_int_done
fetch_reg_d:
    # Fetch from saved register slots
    mov rax, qword ptr [rbp - 56 - rbx*8]
    jmp load_int_done
.d_rsi:
    mov rax, rsi
    jmp load_int_done
.d_rdx:
    mov rax, rdx
    jmp load_int_done
.d_rcx:
    mov rax, rcx
    jmp load_int_done
.d_r8:
    mov rax, r8
    jmp load_int_done
load_int_done:
    call int_to_str
    # After return: rsi = buf ptr, edx = length (set by int_to_str)
    call do_write                   # write the string
    add ebx, 1                      # arg_idx++
    lea r12, [r13 + 1]              # fmt_ptr = after specifier char
    jmp format_loop

handle_c:
    cmp ebx, 5
    jb fetch_reg_c_full
    # Read from stack for args beyond the first 5 (arg indices 5+)
    movzx eax, byte ptr [rbp + 8*(ebx - 3)]
    jmp done_fetch_c
fetch_reg_c_full:
    # Fetch from saved register slots
    movzx eax, byte ptr [rbp - 56 - rbx*8]
    jmp done_fetch_c
.c_rsi:
    mov rax, rsi
    jmp done_fetch_c
.c_rdx:
    mov rax, rdx
    jmp done_fetch_c
.c_rcx:
    mov rax, rcx
    jmp done_fetch_c
.c_r8:
    mov rax, r8
    jmp done_fetch_c
done_fetch_c:
    mov byte ptr [r14], al          # put low byte of rax into write buffer
    mov rsi, r14                    # set buffer pointer
    mov edx, 1                      # set length
    call do_write
    add ebx, 1                      # arg_idx++
    lea r12, [r13 + 1]              # fmt_ptr = after specifier char
    jmp format_loop

handle_percent:
    mov byte ptr [r14], '%'
    mov rsi, r14                    # set buffer pointer
    mov edx, 1                      # set length
    call do_write
    lea r12, [r13 + 1]              # fmt_ptr = after the second %
    jmp format_loop

done_format:
    # Restore callee-saved registers
    mov rbx, qword ptr [rbp-16]     # restore rbx
    mov r12, qword ptr [rbp-24]     # restore r12
    mov r13, qword ptr [rbp-32]     # restore r13
    mov r14, qword ptr [rbp-40]     # restore r14
    mov r15, qword ptr [rbp-48]     # restore r15
    mov rsp, rbp
    pop rbp
    ret

# Convert signed integer in rax to decimal string
# Output: rsi = pointer to start of string, edx = length
int_to_str:
    lea rdi, [rsp + 63]             # end of write buffer (fill right-to-left)

    mov rcx, rdi                      # current fill position
    xor ebx, ebx                      # digit count

    test rax, rax
    jns .positive

    sub rcx, 1
    mov byte ptr [rcx], '-'
    neg rax                           # negate in 64-bit (handles INT_MIN correctly)

.positive:
    test rax, rax
    jnz .digit_loop

    sub rcx, 1
    mov byte ptr [rcx], '0'
    inc ebx
    jmp .done_convert

.digit_loop:
    xor edx, edx                      # clear high bits for div
    mov r8d, 10
    div r8                            # rax = quotient, rdx = remainder

    sub rcx, 1
    add dl, '0'                       # convert digit to ASCII (dl is low byte of rdx)
    mov byte ptr [rcx], dl
    inc ebx                           # increment digit count

    test rax, rax
    jnz .digit_loop

.done_convert:
    lea rsi, [rcx + 1]                # pointer to start of string
    mov edx, ebx                      # length
    ret

# Write buffer: rsi = buf ptr, edx = byte count
# Writes to stdout (fd=1) using write(2) syscall
do_write:
    push rcx
    push r11

    mov eax, 1                        # syscall number for write
    mov edi, 1                        # fd = stdout
    syscall                           # write(1, rsi, edx)

    pop r11
    pop rcx
    ret
