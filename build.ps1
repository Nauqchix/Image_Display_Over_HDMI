$ErrorActionPreference = "Stop"

# ===== Toolchain =====
$CC      = "riscv-none-elf-gcc"
$OBJCOPY = "riscv-none-elf-objcopy"
$OBJDUMP = "riscv-none-elf-objdump"
$SIZE    = "riscv-none-elf-size"

# ===== Files =====
$ELF      = "firmware.elf"
$HEX_RAW  = "firmware.hex"
$HEX_VEX  = "firmware_vex.hex"
$ASM      = "firmware.asm"

# ===== Compile flags =====
$ARCH  = "rv32im"
$ABI   = "ilp32"

$CFLAGS = @(
    "-march=$ARCH"
    "-mabi=$ABI"
    "-Os"
    "-ffreestanding"
    "-nostdlib"
    "-nostartfiles"
    "-Wall"
    "-Wextra"
)

# ===== Sources =====
$SRC = @("start.S","Firmware.c")
$LDS = "linker.ld"

Write-Host "==== Compile ===="
& $CC $CFLAGS -T $LDS $SRC -o $ELF

Write-Host "==== Disassemble ===="
& $OBJDUMP -d $ELF > $ASM

Write-Host "==== Objcopy → verilog hex ===="
& $OBJCOPY -O verilog $ELF $HEX_RAW

Write-Host "==== Convert → VexRiscv word hex ===="

$input = Get-Content $HEX_RAW -Raw

# remove @address
$input = $input -replace "@[0-9A-Fa-f]+",""

$bytes = $input -split "\s+" | Where-Object { $_ -ne "" }

$out = @()

for ($i=0; $i -lt $bytes.Length; $i+=4) {

    $b0=$bytes[$i]
    $b1=$bytes[$i+1]
    $b2=$bytes[$i+2]
    $b3=$bytes[$i+3]

    $word="$b3$b2$b1$b0".ToLower()

    $out += $word
}

$out | Set-Content $HEX_VEX

Write-Host "==== Size ===="
& $SIZE $ELF

Write-Host ""
Write-Host "Build complete:"
Write-Host "  $ELF"
Write-Host "  $ASM"
Write-Host "  $HEX_RAW"
Write-Host "  $HEX_VEX (use this for \$readmemh)"