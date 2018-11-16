; rdi = Buffer (modified/incremented)
; rsi = String (null terminated)
print64:
  push rsi
  push rbx
  push rax
  push rcx
    .start:
      lodsb
      or al, al
        jz .done
      or ax, 0x5f00
      stosw
      mov rbx, rdi
      sub rbx, 0xB8000
      shr rbx, 1
        call update_cursor
      mov rcx, 0x100000
    .1: nop
    loop .1
    jmp .start
  .done:
  pop rcx
  pop rax
  pop rbx
  pop rsi
  ret

; bx = index into video memory to drop cursor (max 0x7CF = 80 * 25 - 1)
update_cursor:
  push dx
  push ax
  push bx
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
  pop ax
  pop dx
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

; al = char
; rdi is incremented
printhex8:
  push rax
    mov eax, 0x5f785f5c ; '\x'
    stosd
  pop rax

  push rcx
  push rax
    mov rcx, 2
    rol al, 4
    .3:
      push ax
        and al, 0x0f
        cmp al, 0xa
    jge .1
        add al, 0x30
    jmp .2
    .1:
        add al, 0x37
    .2:
        mov ah, 0x5f
        stosw
      pop ax
      shr al, 4
    loop .3
  pop rax
  pop rcx
  ret

; rax - value
; rdi - buffer (modified/incremented)
printhex64:
  push rax
  push rcx

  push rax
    mov eax, 0x5f785f30 ; '0x'
    stosd
  pop rax

  mov rcx, 8
  .1:
    push rax
    push rcx
      dec rcx
      and rcx, rcx
      jz .6
        .5:
          shr rax, 8
        loop .5
      .6:
      mov rcx, 2
      rol al, 4
      .4:
        push ax
          .2:
            and al, 0x0f
            cmp al, 0x0a
            jl .3
              add al, 0x07
            .3:
            add al, 0x30
            mov ah, 0x5f
            stosw
        pop ax
        shr al, 4
      loop .4
    pop rcx
    pop rax
  loop .1

  push rbx
    mov rbx, rdi
    sub rbx, 0xB8000
    shr rbx, 1
      call update_cursor
  pop rbx

  pop rcx
  pop rax
  ret

; Should preserve all registers
dump_registers:
  push rax
  push rsi
  push rdi

    ; First column

    mov rdi, 0xB8000
    mov rsi, dump_rax
      call print64
      call printhex64

    mov rdi, 0xB80A0
    mov rsi, dump_rbx
      call print64
    mov rax, rbx
      call printhex64

    mov rdi, 0xB8140
    mov rsi, dump_rcx
      call print64
    mov rax, rcx
      call printhex64
    
    mov rdi, 0xB81E0
    mov rsi, dump_rdx
      call print64
    mov rax, rdx
      call printhex64

    mov rdi, 0xB8280
    mov rsi, dump_cs
      call print64
    mov rax, cs
      call printhex64

    mov rdi, 0xB8280
    mov rsi, dump_cs
      call print64
    mov rax, cs
      call printhex64

    mov rdi, 0xB8320
    mov rsi, dump_es
      call print64
    mov rax, es
      call printhex64

    mov rdi, 0xB83C0
    mov rsi, dump_fs
      call print64
    mov rax, fs
      call printhex64

    mov rdi, 0xB8460
    mov rsi, dump_eflags
      call print64
    pushfq
    pop rax
      call printhex64

    ; Second column

    mov rdi, 0xB8032
    mov rsi, dump_rbp
      call print64
    mov rax, rbp
      call printhex64

    mov rdi, 0xB80D2
    mov rsi, dump_rsp
      call print64
    mov rax, rsp
    sub rax, 3 * 8 ; All the values we put on the stack
      call printhex64

    mov rdi, 0xB8172
    mov rsi, dump_rdi
      call print64
    mov rax, [rsp]
      call printhex64

    mov rdi, 0xB8212
    mov rsi, dump_rsi
      call print64
    mov rax, [rsp + 8]
      call printhex64

    mov rdi, 0xB82B2
    mov rsi, dump_ds
      call print64
    mov rax, ds
      call printhex64

    mov rdi, 0xB8352
    mov rsi, dump_gs
      call print64
    mov rax, gs
      call printhex64

    mov rdi, 0xB83F2
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
