[bits 64]

MEM_FREE     equ 1
MEM_RESERVE  equ 2
MEM_ACPI_REC equ 3
MEM_ACPI_NVS equ 4
MEM_BAD      equ 5

memory_globals:
  .mem_base dq 0
  .mem_size dq 0
  .tbl_size dq 0

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

        xor rdx, rdx
        mov rax, r9
        mov rbx, 256 * 64 ; Each bit in a qword corresponds to one 256 byte region
        div rbx
        mov [memory_globals.tbl_size], rax

        pop rdi
        mov rsi, .s_notice
          call print64
        mov rax, r8
          call printhex64
        mov rsi, .s_size
          call print64
        mov rax, r9
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

memory_alloc:
  ret
