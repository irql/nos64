[bits 16]
[org 0x7c00]

SECTORS equ 10
RELOC equ 0x7c00
MEM_MAP equ 0x7000
MEM_MAP_LEN equ 0x6FF0

jmp 0x0000:start ; Set CS to 0

start:
  ; If we make SP anywhere within the image, then it will
  ; be overwritten when we load the disk to 0x7c00
  mov sp, end
  mov bp, sp
  mov cx, SECTORS - 1
  mov bx, RELOC
  mov si, 1
  .load_loop:
    push cx
      mov cx, si
      mov ah, 2 ; Read in CHS mode (I could never get LBA to work in QEMU)
      mov al, 1 ; Sectors
      mov ch, 0 ; Cylinder
      mov dh, 0 ; Head
        int 0x13
    pop cx
    jnc .load_ok

    mov si, error_1
      call print_str

    .halt:
      pause
    jmp .halt

    .load_ok:
      push si
        mov si, dot
          call print_str
      pop si
      inc si
      add bx, 0x200
  loop .load_loop

  cmp word [RELOC + 0x200], 0xbeef
  je .data_ok
    mov si, error_2
      call print_str
    jmp .halt
  .data_ok:

    ; Next, probe memory
    ; It's _VERY_ important that we've read the sectors
    ; correctly, because the code for `do_e820` resides
    ; in the second sector of the boot media
    xor ax, ax
    mov es, ax
    mov di, MEM_MAP ; Store the actual memory entries here
      call do_e820
    mov [MEM_MAP_LEN], bp ; Store the number of entries here

    xor ax, ax
    mov ss, ax
    mov sp, start
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    cld
    
    mov di, 0x9000 ; Free space (which becomes the PLM4, PDPT, PD & PT).

    ; Notify the BIOS that we will be running long mode (AMD recommended)
    mov ax, 0xEC00
    mov bx, 2
      int 0x15

    ; Zero out the 16KB buffer
    push di
      mov ecx, 0x1000
      xor eax, eax
      rep stosd
    pop di

    ; Build the PLM4 (Page Map Level 4)
    lea eax, [es:di + 0x1000]
    or eax, 3        ; PAGE_PRESENT | PAGE_WRITE == 01b | 10b == 11b == 3
    mov [es:di], eax ; First PML4 entry

    ; Build the PDPT (Page Directory Pointer Table)
    lea eax, [es:di + 0x2000]
    or eax, 3
    mov [es:di + 0x1000], eax

    ; Build the PD (Page Directory)
    lea eax, [es:di + 0x3000]
    or eax, 3
    mov [es:di + 0x2000], eax

    push di
      ; Build the PT (Page Table)
      lea di, [es:di + 0x3000]
      mov eax, 3
      .build_page_table:
        mov [es:di], eax
        add eax, 0x1000
        add di, 8
        cmp eax, 0x200000 ; Stop at 2MB
      jb .build_page_table
    pop di ; di should still point to the PLM4

    ; Set the PAE and PGE bit
    mov eax, 10100000b
    mov cr4, eax

    ; Point CR3 at the PML4
    mov edx, edi
    mov cr3, edx

    ; Read from the EFER MSR..
    mov ecx, 0xC0000080
    rdmsr

    ; ..and set the LME bit
    or eax, 0x00000100
    wrmsr

    ; Activate long mode by enabling paging and protection simultaneously
    mov ebx, cr0
    or ebx, 0x80000001
    mov cr0, ebx

    ; Load our GDT (Gate Descriptor Table)
    lgdt [GDT.pointer]

    ; Load CS with 64-bit segment and flush the instruction cache
    jmp 0x0008:landing64

align 4
GDT: ; Global Descriptor Table
  .null:
    dw 0xffff ; Limit(low)
    dw 0      ; Base(low)
    db 0      ; Base(mid)
    db 0      ; Access
    db 1      ; Granularity(limit(mid)+flags, both 4b)
    db 0      ; Base(high)
  .code:
    dw 0
    dw 0
    db 0
    db 10011010b ; Exec/read
    db 10101111b ; 64 bits
    db 0
  .data:
    dw 0
    dw 0
    db 0
    db 10010010b ; read/write
    db 0
    db 0
  dw 0
.pointer:
  dw $ - GDT - 1
  dd GDT

print_str:
  lodsb
  or al, al
  jz .1
    mov ah, 0xE
      int 0x10
    jmp print_str
  .1:
  ret

error_1 db 'Error reading disk.',0
error_2 db 'Disk corrupt.',0
dot db '.',0

times 446 - ($ - $$) db 0
MBR:
  .part1:
    dq 0
    dq 0
  .part2:
    dq 0
    dq 0
  .part3:
    dq 0
    dq 0
  .part4:
    dq 0
    dq 0
dw 0xAA55 ; Mark sector as bootable
; Start of sector 2
dw 0xbeef ; Checksum

%include "e820.asm"

[bits 64]
landing64:
  cli
  mov rsp, RELOC ; We can safely reclaim the bootloader memory at this point
  mov ax, 0x0010
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax

  ; Video memory is 0xB8FA0 - 0xB8000 = 0xFA0 = 80 * 25 * 2
  mov rdi, 0xB8000
  mov bx, 0
  call update_cursor
  mov rcx, 500
  mov rax, 0x0720072007200720 ; black BG, grey FG
  rep stosq

  mov rdi, 0xB8000
  call memory_init
  call interrupt_init
  call keyboard_init
  call print_newline
  ;call dump_registers

  ;mov rcx, 0x5000000
  ;.1: loop .1
  ; Shutdown the system (requires -device isa-debug-exit,iobase=0xf4,iosize=0x04 /w/ QEMU)
  ;mov dx, 0xf4
  ;xor al, al
  ;out dx, al
  
  .halt:
    pause
  jmp .halt

%include 'debug.asm'
%include 'memory.asm'
%include 'interrupt.asm'
%include 'devices/keyboard.asm'

times (SECTORS * 0x200) - ($ - $$) db 0
end:
