# N/OS 64

The 64-bit nanokernel operating system.
Let's have fun! :-)

#### Dependencies
  - nasm

#### How to build
  - `make`

#### How to run
  The target (whether it be physical or a hypervisor) must be an x86 architecture
  and support long mode. "make" will generate a boot.img, which is bootable, and
  you may do with it what you wish.

#### Known issues
  - `memory_alloc` does not work when rcx (blocks requested) > 64
  - Crashes VirtualBox for some unknown reason
  - Crashes in QEMU when memory available > 2GB
  - Keyboard driver doesn't support numpad (yet)

#### High level todos
  - Select filesystem
  - Determine & enforce executable format
  - Build basic user environment with interpreter
  - More rugged debugging for kernel, possibly serial(w 8295 PIC)
  - IPC mechanism TBD
    - Interface for processes to subscribe to events, such as the keyboard

#### Low-level todos
  - Write IDE/ATA driver for disk access (and determine what else is needed to these ends)
  - VGA support
  - (low priority) Use APIC instead of 8295
