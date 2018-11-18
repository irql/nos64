[bits 64]

keyboard_init:
  mov rax, interrupt_keyboard
  mov rbx, 0x21
  call interrupt_set
  ret

interrupt_keyboard:
  push rax
  push rbx
  push rcx
  push rsi
    in al, 0x60 ; Read from keyboard
    mov bl, al
    ;call printhex8
    ;add rdi, 2
    mov rsi, .sc_table
    mov rcx, .sc_tbl_length / 4
    .search_loop:
      lodsd
      cmp al, bl
      je .found
    loop .search_loop
    jmp .not_found
    .found:
      shr eax, 16
      xor ah, ah
      mov ah, 0x5f
      mov [rdi], ax
      add rdi, 2
      call update_cursor
    .not_found:
    mov al, 0x20
    out 0x20, al
  pop rsi
  pop rcx
  pop rbx
  pop rax
  iretq
  .sc_table:
		db 0x1e, 0x9e, 'a', 0
		db 0x30, 0xb0, 'b', 0
		db 0x2e, 0xae, 'c', 0
		db 0x20, 0xa0, 'd', 0
		db 0x12, 0x92, 'e', 0
		db 0x21, 0xa1, 'f', 0
		db 0x22, 0xa2, 'g', 0
		db 0x23, 0xa3, 'h', 0
		db 0x17, 0x97, 'i', 0
		db 0x24, 0xa4, 'j', 0
		db 0x25, 0xa5, 'k', 0
		db 0x26, 0xa6, 'l', 0
		db 0x32, 0xb2, 'm', 0
		db 0x31, 0xb1, 'n', 0
		db 0x18, 0x98, 'o', 0
		db 0x19, 0x99, 'p', 0
		db 0x10, 0x90, 'q', 0
		db 0x13, 0x93, 'r', 0
		db 0x1f, 0x9f, 's', 0
		db 0x14, 0x94, 't', 0
		db 0x16, 0x96, 'u', 0
		db 0x2f, 0xaf, 'v', 0
		db 0x11, 0x91, 'w', 0
		db 0x2d, 0xad, 'x', 0
		db 0x15, 0x95, 'y', 0
		db 0x2c, 0xac, 'z', 0
		db 0x39, 0xb9, ' ', 0
		db 0x0e, 0x8e, '<', 0 ; Backspace
  .sc_tbl_length equ $ - .sc_table
