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
  ;
  ; Obviously, this allocation will never be free'd.
  mov rcx, 16
  call memory_alloc
  test rax, rax
  jnz .alloc_ok
    mov rsi, .s_failed_alloc
    call print64
    jmp landing64.halt
  .alloc_ok:
  mov [interrupt_globals.idt_base], rax

  ; Set all interrupts to the same routine by default
  mov rbx, rax
  mov rcx, 256
  mov rax, interrupt_common_handler
  .idte_set_loop:
    mov rbx, rcx
    call interrupt_set
  loop .idte_set_loop

  ; Set an ISR for the PIT
  mov rbx, 0x20
  mov rax, interrupt_pit_handler
  call interrupt_set

  ; Remap the PIC prior to loading the IDT

  ; bl = master mask
  in al, 0x21 ; PIC master data
  mov bl, al
  ; cl = slave mask
  in al, 0xA1 ; PIC slave data
  mov cl, al

  mov al, 0x11 ; Initialize master
  out 0x20, al
  xor al, al
  out 0x80, al ; io_wait()

  mov al, 0x11 ; Initialize slave
  out 0xA0, al
  xor al, al
  out 0x80, al

  mov al, 0x20 ; New master interrupt descriptor offset
  out 0x21, al
  xor al, al
  out 0x80, al

  mov al, 0x30 ; New slave interrupt descriptor offset
  out 0xA1, al
  xor al, al
  out 0x80, al

  mov al, 0100b; Tell the master there is a slave at IRQ2
  out 0x21, al
  xor al, al
  out 0x80, al

  mov al, 2    ; Tell the slave it's cascade identity
  out 0xA1, al
  xor al, al
  out 0x80, al

  mov al, 1    ; master = 8086 mode
  out 0x21, al
  xor al, al
  out 0x80, al

  mov al, 1    ; slave = 8086 mode
  out 0xA1, al
  xor al, al
  out 0x80, al

  ; Restore saved masks
  mov al, bl
  out 0x21, al
  mov al, cl
  out 0xA1, al

  ; Mask PIT (disable everything but keyboard (IRQ=1, line=2)
  ;in al, 0x21
  ;or al, ~(2)
  ;out 0x21, al

  ; Load the IDT
  lidt [interrupt_idt_descriptor]
  sti ; Enable interrupts
  ret

  .s_failed_alloc db 'Failed to allocate memory for IDT.',10,0

; rax = address of ISR
; rbx = interrupt number
interrupt_set:
  push rdx
  push rbx
    mov rdx, rax
    shr rdx, 16

    shl rbx, 4
    add rbx, [interrupt_globals.idt_base]

    mov [rbx], ax
    mov [rbx + 2], word 0x08
    mov [rbx + 4], byte 0
    mov [rbx + 5], byte 0x8F ; present | interrupt | dpl=0
    mov [rbx + 6], dx
    mov [rbx + 8], dword 0
    mov [rbx + 12], dword 0
  pop rbx
  pop rdx
  ret

interrupt_pit_handler:
  push rax
  push rdi
    mov rdi, 0xb8000 + 124
    mov rax, [.ticks]
    call printhex64
    inc qword [.ticks]
    mov al, 0x20
    out 0x20, al
  pop rdi
  pop rax
  iretq
  .ticks dq 0

interrupt_common_handler:
  iretq

