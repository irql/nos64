OUT=boot.img
ASM=nasm
ASM_OPTS=-o $(OUT)
EMUL=qemu-system-x86_64
EMUL_OPTS=-drive index=0,format=raw,file=$(OUT) -device isa-debug-exit,iobase=0xf4,iosize=0x04

.PHONY: clean

all:
	$(ASM) $(ASM_OPTS) boot.asm

clean:
		rm $(OUT)

emul:
	$(EMUL) $(EMUL_OPTS)