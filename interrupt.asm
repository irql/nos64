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

  push rdi
  mov rdi, rax
  xor rax, rax
  mov rcx, (256 * 16) / 8
  rep stosq
  pop rdi ; Preserve rdi if we want to print anything

  ; Set all interrupts to the same routine by default
  ;mov rbx, rax

  ;mov ax, interrupt_common_handler
  ;and ax, 0xFFFF

  ;mov dx, interrupt_common_handler
  ;shr dx, 16
  ;and dx, 0xFFFF

  .idte_set_loop:
    mov [rbx], ax ; base low
    mov [rbx + 2], word 0x08 ; selector
    mov [rbx + 4], byte 0 ; reserved
    ;mov [rbx + 5], byte 0x8F ; flags
    mov [rbx + 5], byte 0
    mov [rbx + 6], dx ; base mid
    mov [rbx + 8], dword 0 ; base high
    mov [rbx + 12], dword 0 ; reserved
    add rbx, 16
  loop .idte_set_loop

  ;mov rax, interrupt_keyboard
  ;mov rbx, 0x21
  ;call interrupt_set

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

  mov al, 0x20 ; New master PVO
  out 0x21, al
  xor al, al
  out 0x80, al

  mov al, 0x30 ; New slave PVO
  out 0xA1, al
  xor al, al
  out 0x80, al

  mov al, 4    ; Tell the master there is a slave at IRQ2
  out 0x21, al
  xor al, al
  out 0x80, al

  mov al, 2    ; Tell the slave it's cascade identity
  out 0xA1, al
  xor al, al
  out 0x80, al

  mov al, 1    ; 8086 mode
  out 0x21, al
  xor al, al
  out 0x80, al

  mov al, 1    ; 8086 mode
  out 0xA1, al
  xor al, al
  out 0x80, al

  ; Restore saved masks
  mov al, bl
  out 0x21, al
  mov al, cl
  out 0xA1, al

  ; Load the IDT
  lidt [interrupt_idt_descriptor]
  sti ; Enable interrupts
  ret

  .s_failed_alloc db 'Failed to allocate memory for IDT.',10,0

; rax = addres of ISR
; rbx = interrupt number
interrupt_set:
  push rdx
  push rbx
    mov rdx, rax
    shr rdx, 16

    shl rbx, 4
    lea rbx, [interrupt_globals.idt_base + rbx]
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

;interrupt_keyboard:
;  mov ax, 0x10
;  mov ds, ax
;  in al, 0x60
;  mov rdi, 0xB8000
;  call printhex8
;  iretq

interrupt_common_handler:
  ;push rax

  ;mov ax, ds
  ;push ax

  ;mov rax, rsp
  ;push rax
  ;mov ax, 0x10
  ;mov ds, ax
  ;mov rdi, 0xB8000
  ;pop rax
  ;call printhex64
  ;call print_newline
  ;mov es, ax
  ;mov fs, ax
  ;mov gs, ax
  ;mov ss, ax

  ;in al, 0x60
  ;mov rdi, 0xB8000
  ;mov rax, [rsp]
  ;call printhex64

  ;pop bx
  ;mov ds, bx
  ;mov es, bx
  ;mov fs, bx
  ;mov gs, bx
  ;mov ss, bx

  ;pop rax
  iretq
