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
  push rdx
  push rsi
    in al, 0x60 ; Read from keyboard
    mov bl, al

    ; Uncomment to debug scan codes
    ;call printhex8
    ;add rdi, 2
    ;jmp .done

    cld ; Scan forward, not backward
    mov rsi, .sc_table
    mov rcx, .sc_tbl_length / 4
    .search_loop:
      lodsd

      ; Keydown scancode
      cmp al, bl
      je .found_keydown

      ; Keyup scancode
      cmp ah, bl
      je .found_keyup

    loop .search_loop
    jmp .done
    .found_keydown:
      xor edx, edx
      mov edx, eax
      shr edx, 24

      cmp dl, KEY_CHAR
      jne .check_backsp
        cmp byte [.shift_state], 0xff
        je .search_upper_loop
        cmp byte [.caps_state], 0xff
        jne .found_char
        mov rsi, .sc_table
        mov rcx, .sc_tbl_length / 4
          .search_upper_loop:
            lodsd

            ; Scancode match?
            cmp al, bl
            jne .search_upper_next

            push bx
              mov bl, KEY_CHAR | KEY_SHIFT

              ; Is caps-lock on?
              cmp byte [.caps_state], 0xff
              jne .normal_behavior

                ; If so, is shift also on?
                cmp byte [.shift_state], 0xff
                je .normal_behavior

                  ; If it's only caps but not shift,
                  ; we should only upper-case alphabetical
                  ; keys.
                  push rax
                    shr eax, 16 ; Easier to compare the ASCII value
                    xor dx, dx

                    ; Don't mess with the modifier-comparator value
                    ; if we're alredy on A-Z!
                    cmp al, 'A'
                    jl .nonAZ
                    cmp al, 'Z'
                    jle .isAZ

                    .nonAZ:
                    mov dl, KEY_CHAR
                    cmp al, 'z'
                    cmovg bx, dx
                    cmp al, 'a'
                    cmovl bx, dx

                    .isAZ:
                  pop rax

              .normal_behavior:
              ; Is it a shift key?
              mov edx, eax
              shr edx, 24
              cmp dl, bl
            pop bx
            je .found_char

            .search_upper_next:
            loop .search_upper_loop
            jmp .done
        .found_char:
          shr eax, 16

          cmp al, 10 ; Special case for Return
          jne .normal_char
            call print_newline
            jmp .done
          .normal_char:
            xor ah, ah
            mov ah, COLOR
            mov [rdi], ax
            add rdi, 2
            call update_cursor
            jmp .done

      .check_backsp:
      cmp dl, KEY_BACKSPACE
      jne .check_shift
        sub rdi, 2
        mov [rdi], word (COLOR << 8) | 0x20
        call update_cursor
        jmp .done

      .check_shift:
      cmp dl, KEY_SHIFT
      jne .check_caps
        mov [.shift_state], byte 0xff
        jmp .done

      .check_caps:
      cmp dl, KEY_CAPS
      jne .done
        not byte [.caps_state]
        jmp .done

    .found_keyup:
      xor edx, edx
      mov edx, eax
      shr edx, 24

      cmp dl, KEY_SHIFT
      jne .done
        mov [.shift_state], byte 0
        jmp .done
    .done:
    ; Acknowledge PIC interrupt
    mov al, 0x20
    out 0x20, al
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  iretq
  .shift_state db 0
  .caps_state  db 0
    KEY_CHAR       equ 00000001b
    KEY_BACKSPACE  equ 00000010b
    KEY_SHIFT      equ 00000100b
    KEY_CAPS       equ 00001000b
  .sc_table:
    db 0x1e, 0x9e, 'a', KEY_CHAR
    db 0x30, 0xb0, 'b', KEY_CHAR
    db 0x2e, 0xae, 'c', KEY_CHAR
    db 0x20, 0xa0, 'd', KEY_CHAR
    db 0x12, 0x92, 'e', KEY_CHAR
    db 0x21, 0xa1, 'f', KEY_CHAR
    db 0x22, 0xa2, 'g', KEY_CHAR
    db 0x23, 0xa3, 'h', KEY_CHAR
    db 0x17, 0x97, 'i', KEY_CHAR
    db 0x24, 0xa4, 'j', KEY_CHAR
    db 0x25, 0xa5, 'k', KEY_CHAR
    db 0x26, 0xa6, 'l', KEY_CHAR
    db 0x32, 0xb2, 'm', KEY_CHAR
    db 0x31, 0xb1, 'n', KEY_CHAR
    db 0x18, 0x98, 'o', KEY_CHAR
    db 0x19, 0x99, 'p', KEY_CHAR
    db 0x10, 0x90, 'q', KEY_CHAR
    db 0x13, 0x93, 'r', KEY_CHAR
    db 0x1f, 0x9f, 's', KEY_CHAR
    db 0x14, 0x94, 't', KEY_CHAR
    db 0x16, 0x96, 'u', KEY_CHAR
    db 0x2f, 0xaf, 'v', KEY_CHAR
    db 0x11, 0x91, 'w', KEY_CHAR
    db 0x2d, 0xad, 'x', KEY_CHAR
    db 0x15, 0x95, 'y', KEY_CHAR
    db 0x2c, 0xac, 'z', KEY_CHAR
    db 0x0b, 0x8b, '0', KEY_CHAR
    db 0x02, 0x82, '1', KEY_CHAR
    db 0x03, 0x83, '2', KEY_CHAR
    db 0x04, 0x84, '3', KEY_CHAR
    db 0x05, 0x85, '4', KEY_CHAR
    db 0x06, 0x86, '5', KEY_CHAR
    db 0x07, 0x87, '6', KEY_CHAR
    db 0x08, 0x88, '7', KEY_CHAR
    db 0x09, 0x89, '8', KEY_CHAR
    db 0x0a, 0x8a, '9', KEY_CHAR
    db 0x0c, 0x8c, '-', KEY_CHAR
    db 0x0d, 0x8d, '=', KEY_CHAR
    db 0x1a, 0x9a, '[', KEY_CHAR
    db 0x1b, 0x9b, ']', KEY_CHAR
    db 0x2b, 0xab, '\', KEY_CHAR
    db 0x27, 0xa7, ';', KEY_CHAR
    db 0x28, 0xa8, 27h, KEY_CHAR
    db 0x33, 0xb3, ',', KEY_CHAR
    db 0x34, 0xb4, '.', KEY_CHAR
    db 0x35, 0xb5, '/', KEY_CHAR
    db 0x29, 0xa9, '`', KEY_CHAR
    db 0x39, 0xb9, ' ', KEY_CHAR
    ;db 0x0f, 0x8f, 09h, KEY_CHAR ; Tab (TODO special handling)
    db 0x1c, 0x9c,  10, KEY_CHAR

    db 0x1e, 0x9e, 'A', KEY_CHAR | KEY_SHIFT
    db 0x30, 0xb0, 'B', KEY_CHAR | KEY_SHIFT
    db 0x2e, 0xae, 'C', KEY_CHAR | KEY_SHIFT
    db 0x20, 0xa0, 'D', KEY_CHAR | KEY_SHIFT
    db 0x12, 0x92, 'E', KEY_CHAR | KEY_SHIFT
    db 0x21, 0xa1, 'F', KEY_CHAR | KEY_SHIFT
    db 0x22, 0xa2, 'G', KEY_CHAR | KEY_SHIFT
    db 0x23, 0xa3, 'H', KEY_CHAR | KEY_SHIFT
    db 0x17, 0x97, 'I', KEY_CHAR | KEY_SHIFT
    db 0x24, 0xa4, 'J', KEY_CHAR | KEY_SHIFT
    db 0x25, 0xa5, 'K', KEY_CHAR | KEY_SHIFT
    db 0x26, 0xa6, 'L', KEY_CHAR | KEY_SHIFT
    db 0x32, 0xb2, 'M', KEY_CHAR | KEY_SHIFT
    db 0x31, 0xb1, 'N', KEY_CHAR | KEY_SHIFT
    db 0x18, 0x98, 'O', KEY_CHAR | KEY_SHIFT
    db 0x19, 0x99, 'P', KEY_CHAR | KEY_SHIFT
    db 0x10, 0x90, 'Q', KEY_CHAR | KEY_SHIFT
    db 0x13, 0x93, 'R', KEY_CHAR | KEY_SHIFT
    db 0x1f, 0x9f, 'S', KEY_CHAR | KEY_SHIFT
    db 0x14, 0x94, 'T', KEY_CHAR | KEY_SHIFT
    db 0x16, 0x96, 'U', KEY_CHAR | KEY_SHIFT
    db 0x2f, 0xaf, 'V', KEY_CHAR | KEY_SHIFT
    db 0x11, 0x91, 'W', KEY_CHAR | KEY_SHIFT
    db 0x2d, 0xad, 'X', KEY_CHAR | KEY_SHIFT
    db 0x15, 0x95, 'Y', KEY_CHAR | KEY_SHIFT
    db 0x2c, 0xac, 'Z', KEY_CHAR | KEY_SHIFT
    db 0x0b, 0x8b, ')', KEY_CHAR | KEY_SHIFT
    db 0x02, 0x82, '!', KEY_CHAR | KEY_SHIFT
    db 0x03, 0x83, '@', KEY_CHAR | KEY_SHIFT
    db 0x04, 0x84, '#', KEY_CHAR | KEY_SHIFT
    db 0x05, 0x85, '$', KEY_CHAR | KEY_SHIFT
    db 0x06, 0x86, '%', KEY_CHAR | KEY_SHIFT
    db 0x07, 0x87, '^', KEY_CHAR | KEY_SHIFT
    db 0x08, 0x88, '&', KEY_CHAR | KEY_SHIFT
    db 0x09, 0x89, '*', KEY_CHAR | KEY_SHIFT
    db 0x0a, 0x8a, '(', KEY_CHAR | KEY_SHIFT
    db 0x0c, 0x8c, '_', KEY_CHAR | KEY_SHIFT
    db 0x0d, 0x8d, '+', KEY_CHAR | KEY_SHIFT
    db 0x1a, 0x9a, '{', KEY_CHAR | KEY_SHIFT
    db 0x1b, 0x9b, '}', KEY_CHAR | KEY_SHIFT
    db 0x2b, 0xab, '|', KEY_CHAR | KEY_SHIFT
    db 0x27, 0xa7, ':', KEY_CHAR | KEY_SHIFT
    db 0x28, 0xa8, '"', KEY_CHAR | KEY_SHIFT
    db 0x33, 0xb3, '<', KEY_CHAR | KEY_SHIFT
    db 0x34, 0xb4, '>', KEY_CHAR | KEY_SHIFT
    db 0x35, 0xb5, '?', KEY_CHAR | KEY_SHIFT
    db 0x39, 0xb9, ' ', KEY_CHAR | KEY_SHIFT
    db 0x29, 0xa9, '~', KEY_CHAR | KEY_SHIFT
    db 0x1c, 0x9c,  10, KEY_CHAR | KEY_SHIFT

    db 0x0e, 0x8e,   0, KEY_BACKSPACE
    db 0x2a, 0xaa,   0, KEY_SHIFT ; Left shift
    db 0x36, 0xb6,   0, KEY_SHIFT ; Right shift
    db 0x3a, 0xba,   0, KEY_CAPS
  .sc_tbl_length equ $ - .sc_table
