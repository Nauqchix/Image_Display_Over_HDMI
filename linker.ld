ENTRY(_start)

MEMORY
{
  ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
  RAM (rwx) : ORIGIN = 0x40000000, LENGTH = 64K
}

SECTIONS
{
  .text : {
    *(.init)
    *(.text*)
    *(.rodata*)
  } > ROM

  .data : {
    *(.data*)
  } > RAM

  .bss : {
    *(.bss*)
    *(COMMON)
  } > RAM

  . = ALIGN(4);
  _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}