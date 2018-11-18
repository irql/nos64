[bits 64]

interrupt_idt_descriptor:
  .size dw 256 * 16 - 1
  .offset dq 0

interrupt_globals:
  .idt_base equ interrupt_idt_descriptor.offset

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
  mov [interrupt_globals.idt_base], rax

  ;push rdi
  ;mov rdi, rax
  ;xor rax, rax
  ;mov rcx, (256 * 16) / 8
  ;rep stosq
  ;pop rdi ; Preserve rdi if we want to print anything

  ; Set all interrupts to the same routine by default
  mov rbx, rax

  mov ax, interrupt_common_handler
  and ax, 0xFFFF

  mov dx, interrupt_common_handler
  shr dx, 16
  and dx, 0xFFFF

  .idte_set_loop:
    mov [rbx], ax ; base low
    mov [rbx + 2], word 0x08 ; selector
    mov [rbx + 4], byte 0 ; reserved
    mov [rbx + 5], byte 0x8E ; flags
    mov [rbx + 6], dx ; base mid
    mov [rbx + 8], dword 0 ; base high
    mov [rbx + 12], dword 0 ; reserved
    add rbx, 16
  loop .idte_set_loop

  lidt [interrupt_idt_descriptor]
  sti ; Enable interrupts

  ret
  .s_failed_alloc db 'Failed to allocate memory for IDT.',10,0

interrupt_common_handler:
  push rax

  mov ax, ds
  push ax

  mov ax, 0x10
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax

  in al, 0x60
  mov rdi, 0xB8000
  call printhex64

  pop bx
  mov ds, bx
  mov es, bx
  mov fs, bx
  mov gs, bx
  mov ss, bx

  pop rax
  sti
  iret
