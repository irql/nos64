[bits 64]

interrupt_init:
  ; There are 256 interrupts in the IDT
  ; Each IDT entry is 16 bytes, so we allocate 4096 bytes for the
  ; entire table (16 "pages" where each "page" is 256 bytes)
  mov rcx, 16
  call memory_alloc
  test rax, rax
  jnz .alloc_ok
    mov rsi, .s_failed_alloc
    call print64
    jmp landing64.halt
  .alloc_ok:
  ret
  .s_failed_alloc db 'Failed to allocate memory for IDT.',10,0
