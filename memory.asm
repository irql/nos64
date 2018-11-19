[bits 64]

MEM_FREE     equ 1
MEM_RESERVE  equ 2
MEM_ACPI_REC equ 3
MEM_ACPI_NVS equ 4
MEM_BAD      equ 5

memory_globals:
  .mem_base  dq 0
  .mem_size  dq 0
  .tbl_size  dq 0
  .free_base dq 0
  .free_size dq 0

PMEM_TBL_BASE equ memory_globals.mem_base
PMEM_TBL_SIZE equ memory_globals.tbl_size

; Does not save any register states
memory_init:
  push rdi

  xor rcx, rcx
  mov cx, [MEM_MAP_LEN]
  mov rsi, MEM_MAP
  .1:
    lodsq ; Start of region
    mov r8, rax
    lodsq ; Length of region
    mov r9, rax
    lodsd ; Type
    mov r10, rax
    lodsd ; ACPI flags (unused)

    cmp r10, MEM_FREE ; Find free memory
    jne .2
      cmp r8, 0x10000  ; That's over the 64k mark
      jl .2
        mov [memory_globals.mem_base], r8
        mov [memory_globals.mem_size], r9

        ; Calculate size of allocation table
        xor rdx, rdx
        mov rax, r9
        mov rbx, 256 * 64 ; Each bit in a qword corresponds to one 256 byte region
        div rbx
        mov [PMEM_TBL_SIZE], rax

        ; free_base is the start of memory following the allocation table
        mov rcx, r8
        add rcx, rax
        mov [memory_globals.free_base], rcx

        ; free_size is the amount of free memory minus the allocation table
        mov rcx, r9
        sub rcx, rax
        mov [memory_globals.free_size], rcx

        mov rcx, rax
        xor rax, rax
        mov rdi, [PMEM_TBL_BASE]
        rep stosq

        pop rdi
        mov rsi, .s_notice
          call print64
        mov rax, [memory_globals.free_base]
          call printhex64
        mov rsi, .s_size
          call print64
        mov rax, [memory_globals.free_size]
          call printhex64
        call print_newline
        ret
  .2:
  dec rcx
  test rcx, rcx
  jnz .1

  pop rdi
  ret
  .s_notice db 'MEMORY BASE: ',0
  .s_size   db ' SIZE: ',0

; TODO: can only allocate 64 blocks at a time (max of 16k)
;       because the function does not compute contiguous free
;       bits at the end of record boundaries.
; rcx = number of blocks requested (each is 256 bytes)
; rax is updated to point to the start of the blocks (contiguous region)
memory_alloc:
  push r8  ; bit mask
  push r9  ; last bit index in bit_loop
  push r10 ; finalized bitmask
  push r11 ; index at which allocation started within the block
  push rcx
  push rbx
  push rsi
    mov rsi, [PMEM_TBL_BASE]
    .entry_loop:
      ;mov rax, rsi
      ;call printhex64
      ;call print_newline

      xor rbx, rbx
      xor rax, rax
      xor r9, r9
      xor r10, r10

      ; Check if we've exceeded the bounds of the allocation table
      mov r11, [PMEM_TBL_BASE]
      add r11, [PMEM_TBL_SIZE]
      cmp rsi, r11
      jle .load_next
        xor rax, rax
        jmp .end
      .load_next:
      lodsq
      not rax
      ; TODO: determine if we can fit the allocation in this block prior to bit_loop
      .bit_loop:
        bsf rbx, rax ; Scan rax for lowest-set bit and put index in rbx

        ; If indices are not contiguous, start over
        cmp rcx, [rsp + 16]
        jne .second_pass
          mov r9, rbx
          mov r11, r9
          jmp .is_contig

        .second_pass:
          inc r9
          cmp rbx, r9
          je .is_contig
            ;push rsi
            ;  mov rsi, .s_nocont
            ;  call print64
            ;pop rsi
            xor r10, r10
            mov rcx, [rsp + 16]
            cmp rax, -1 ; If we've exhausted all the bits in this block, move to the next
            jge .entry_loop
            jmp .bit_loop

        .is_contig:
        mov r8, 1 ; Create bit mask to xor rax by
        push cx
          mov cl, bl
          shl r8, cl
        pop cx
        xor rax, r8
        or r10, r8

        ;push rax
        ;  not rax
        ;  call printhex64 ; First column
        ;  add rdi, 2
        ;  mov rax, r10
        ;  call printhex64 ; Second col - bitmask
        ;  add rdi, 2
        ;  mov rax, rbx
        ;  call printhex64 ; Third col - cur bit index
        ;  add rdi, 2
        ;  mov rax, rcx
        ;  call printhex64 ; Fourth col - cur bit scanned
        ;  call print_newline
        ;pop rax
        dec rcx
        test rcx, rcx
        jnz .bit_loop

        sub rsi, 8
        or [rsi], r10 ; Mark bits in the block as in-use

        mov rax, rsi
        sub rax, [PMEM_TBL_BASE]
        shl rax, 11 ; Multiply entry-index by 2048 (256 * 8)
        shl r11, 8  ; Multiply bit-index by 256
        add rax, r11
        add rax, [memory_globals.free_base] ; Start of free memory (post table)
      .end:
  pop rsi
  pop rbx
  pop rcx
  pop r11
  pop r10
  pop r9
  pop r8
  ret
  .s_nocont db 'Not contiguous.',10,0
  .s_toosmall db 'Not enough bits.',10,0
