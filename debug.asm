PRINT_DELAY              equ 0x10
video_memory             equ 0xB8000
dump_registers_di_offset equ video_memory

; Modifies rdi
print_newline:
  push rdx
  push rax
  push rbx
    xor edx, edx
    mov rax, rdi
    sub rax, 0xB8000
    mov ebx, 0xA0
    div ebx
    mov rax, 0xA0
    sub eax, edx
    add rdi, rax
    call update_cursor
  pop rbx
  pop rax
  pop rdx
  ret

; rdi = Buffer (modified/incremented)
; rsi = String (null terminated)
print64:
  push rsi
  push rax
  push rcx
  push rdx
  xor rax, rax
    .start:
      lodsb
      or al, al
        jz .done
      cmp al, 10
        jne .normal
          call print_newline
          jmp .update_cursor
      .normal:
      or ax, 0x5f00
      stosw
      push rcx
        mov rcx, PRINT_DELAY
        .loop: nop
        loop .loop
      pop rcx
      .update_cursor:
        call update_cursor
    jmp .start
  .done:
  pop rdx
  pop rcx
  pop rax
  pop rsi
  ret

; bx = index into video memory to drop cursor (max 0x7CF = 80 * 25 - 1)
; resets rdi if it grows beyond video memory (0xB8FA0)
update_cursor:
  push ax
  push dx
  push bx
    cmp rdi, 0xB8FA0
    jl .1
      xor bx, bx
      mov rdi, 0xB8000
      push rdi
      push rax
      push rcx
        mov rcx, 2000
        mov rax, 0x5f205f20
        rep stosd
      pop rcx
      pop rax
      pop rdi
    .1:

    ; calculate bx based on di
    mov bx, di
    sub bx, 0x8000
    shr bx, 1

    ; Select cursor low port
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al

    ; Write low
    mov al, bl
    inc dx
    out dx, al

    ; Select cursor high port
    mov al, 0x0E
    dec dx
    out dx, al

    ; Write high
    mov al, bh
    inc dx
    out dx, al
  pop bx
  pop dx
  pop ax
  ret

; Does not preserve any registers
print_character_map:
  mov rdi, 0xB8000
  xor rax, rax
  mov ax, 0x5f00
  .2:
    stosw
  
    push ax
      mov ax, 0x5f20
      stosw
    pop ax
  
    push ax
      call printhex8
    pop ax
  
    push rax
      mov eax, 0x5f205f20
      stosd
    pop rax
  
    add bx, 8
      call update_cursor
    
    inc al
    cmp rdi, 0xB8F90
  jl .2
  
  mov rax, 0x5f475f415f575f53
  stosq
  mov rax, 0x5f295f3a5f345f36
  stosq
  mov bx, 0x7CF
    call update_cursor

  ret

; Used by the other printhex* calls
; rcx = number of bytes to dump from rax (zero'd)
_printhex:

  push rax
    mov eax, 0x5f785f30 ; '0x'
    stosd
  pop rax

  .1:
    push rax
    push rcx
      dec rcx
      shl cl, 3
      shr rax, cl
      mov rcx, 2
      rol al, 4
      .4:
        push ax
          and al, 0x0f
          cmp al, 0x0a
          jl .3
            add al, 0x07
          .3:
          add al, 0x30
          mov ah, 0x5f
          stosw
          call update_cursor
          push rcx
            mov rcx, PRINT_DELAY
            .loop: nop
            loop .loop
          pop rcx
        pop ax
        shr al, 4
      loop .4
    pop rcx
    pop rax
  loop .1
  ret

; ax - value
; rdi - buffer
printhex8:
  push rcx
    mov rcx, 1
      call _printhex
  pop rcx
  ret
printhex16:
  push rcx
    mov rcx, 2
      call _printhex
  pop rcx
  ret
printhex32:
  push rcx,
    mov rcx, 4
      call _printhex
  pop rcx
  ret
printhex64:
  push rcx
    mov rcx, 8
      call _printhex
  pop rcx
  ret

; Should preserve all registers
dump_registers:
  push rax
  push rsi
  push rdi

    ; First column

    mov rdi, dump_registers_di_offset
    mov rsi, dump_rax
      call print64
      call printhex64

    mov rdi, dump_registers_di_offset + 0xA0
    mov rsi, dump_rbx
      call print64
    mov rax, rbx
      call printhex64

    mov rdi, dump_registers_di_offset + 0x140
    mov rsi, dump_rcx
      call print64
    mov rax, rcx
      call printhex64
    
    mov rdi, dump_registers_di_offset + 0x1E0
    mov rsi, dump_rdx
      call print64
    mov rax, rdx
      call printhex64

    mov rdi, dump_registers_di_offset + 0x280
    mov rsi, dump_cs
      call print64
    mov rax, cs
      call printhex64

    mov rdi, dump_registers_di_offset + 0x320
    mov rsi, dump_es
      call print64
    mov rax, es
      call printhex64

    mov rdi, dump_registers_di_offset + 0x3C0
    mov rsi, dump_fs
      call print64
    mov rax, fs
      call printhex64

    mov rdi, dump_registers_di_offset + 0x460
    mov rsi, dump_eflags
      call print64
    pushfq
    pop rax
      call printhex64

    ; Second column

    mov rdi, dump_registers_di_offset + 0x32
    mov rsi, dump_rbp
      call print64
    mov rax, rbp
      call printhex64

    mov rdi, dump_registers_di_offset + 0xD2
    mov rsi, dump_rsp
      call print64
    mov rax, rsp
    sub rax, 3 * 8 ; Subtract all the values we put on the stack
      call printhex64

    mov rdi, dump_registers_di_offset + 0x172
    mov rsi, dump_rdi
      call print64
    mov rax, [rsp]
      call printhex64

    mov rdi, dump_registers_di_offset + 0x212
    mov rsi, dump_rsi
      call print64
    mov rax, [rsp + 8]
      call printhex64

    mov rdi, dump_registers_di_offset + 0x2B2
    mov rsi, dump_ds
      call print64
    mov rax, ds
      call printhex64

    mov rdi, dump_registers_di_offset + 0x352
    mov rsi, dump_gs
      call print64
    mov rax, gs
      call printhex64

    mov rdi, dump_registers_di_offset + 0x3F2
    mov rsi, dump_ss
      call print64
    mov rax, ss
      call printhex64

  pop rdi
  pop rsi
  pop rax
  ret

dump_rax db 'RAX: ',0
dump_rbx db 'RBX: ',0
dump_rcx db 'RCX: ',0
dump_rdx db 'RDX: ',0

dump_rsp db 'RSP: ',0
dump_rbp db 'RBP: ',0

dump_rsi db 'RSI: ',0
dump_rdi db 'RDI: ',0

dump_cs  db ' CS: ', 0
dump_ds  db ' DS: ', 0
dump_es  db ' ES: ', 0
dump_fs  db ' FS: ', 0
dump_gs  db ' GS: ', 0
dump_ss  db ' SS: ', 0

dump_eflags db 'FLAG:', 0

dump_memory:
  xor rcx, rcx
  xor rbx, rbx
  mov cx, [MEM_MAP_LEN]
  mov rdx, MEM_MAP
  .1:
    mov al, byte [MEM_MAP_LEN]
    sub al, cl
      call printhex8
    add rdi, 2
    mov rax, [rdx]
      call printhex64
    add rdi, 2
    mov rax, [rdx + 8]
      call printhex64
    add rdi, 2
    mov eax, [rdx + 16]
    cmp eax, 1
    jne .2
      add rbx, [rdx + 8]
      mov rsi, dump_mem_free
      call print64
    .2:
    cmp eax, 2
    jne .3
      mov rsi, dump_mem_reserved
      call print64
    .3:
    cmp eax, 3
    jne .4
      mov rsi, dump_mem_acpi_reclaim
      call print64
    .4:
    cmp eax, 4
    jne .5
      mov rsi, dump_mem_acpi_nvs
      call print64
    .5:
    cmp eax, 5
    jne .6
      mov rsi, dump_mem_bad
      call print64
    .6:
    add rdx, 24
    add rdi, 66
  dec rcx
  test rcx, rcx
  jnz .1

  mov rax, rbx
    call printhex64
  ret

dump_mem_free db 'Free',0
dump_mem_reserved db 'Resv',0
dump_mem_acpi_reclaim db 'ACPI Reclaimable',0
dump_mem_acpi_nvs db 'ACPI NVS',0
dump_mem_bad db 'Bad',0
