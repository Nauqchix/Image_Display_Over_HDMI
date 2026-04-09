# Image Display Over HDMI using RISC-V SoC

## 1. Overview

This project presents the design and implementation of a complete System-on-Chip (SoC) capable of receiving image data via UART and rendering it to an HDMI display in real time.

The system integrates a RISC-V soft processor, memory-mapped peripherals, a dual-port framebuffer, and an HDMI output pipeline.

---

## 2. System Architecture

The system is organized around a RISC-V CPU that controls peripherals through a memory-mapped bus.

### Block Diagram
            +--------------------------+
            |        Host PC           |
            |   (Python Application)   |
            +-----------+--------------+
                        |
                        | UART
                        v
            +--------------------------+
            |        UART RX           |
            +-----------+--------------+
                        |
                        v
            +--------------------------+
            |      RISC-V CPU          |
            |       (VexRiscv)         |
            +-----------+--------------+
                        |
                        | Memory-mapped bus
                        v
            +--------------------------+
            |     Dual-Port RAM        |
            |     (Framebuffer)        |
            +-----------+--------------+
                        |
           +------------+-------------+
           |                          |
           v                          v
 CPU write (Port A)        HDMI read (Port B)

            +--------------------------+
            |    HDMI Controller       |
            +-----------+--------------+
                        |
                        v
                  HDMI Output
                  
---

## 3. Design Components

### 3.1 RISC-V CPU

- Core: VexRiscv  
- Handles:
  - UART parsing  
  - Framebuffer update  
  - Peripheral control  

---

### 3.2 UART Receiver

- Receives image data from host PC  
- Streaming interface  
- Memory-mapped to CPU  

---

### 3.3 Dual-Port RAM (Framebuffer)

- RGB565 format  
- Two ports:
  - Port A: CPU write  
  - Port B: HDMI read  
- Enables concurrent access  

---

### 3.4 HDMI Controller

- Generates video timing  
- Reads framebuffer  
- TMDS encoding  
- HDMI output  

---

### 3.5 Host Application (Python)

- Converts image → RGB565  
- Resizes to 300×300  
- Sends via UART  

---

## 4. Memory Map

| Address      | Description            |
|--------------|------------------------|
| 0x80000000   | Instruction ROM        |
| 0x40000000   | RAM / Framebuffer      |
| 0xF0000000   | Peripheral base        |

### Peripheral Registers

| Offset | Register        | Description                  |
|--------|----------------|------------------------------|
| 0x00   | HDMI_ENABLE     | Enable HDMI                  |
| 0x04   | FB_BASE_WORD    | Framebuffer base             |
| 0x10   | UART_DATA       | UART data                    |
| 0x14   | UART_STATUS     | UART status                  |

---

## 5. Data Flow

1. Host sends image via UART  
2. UART RX receives data  
3. CPU reads UART registers  
4. CPU writes framebuffer  
5. HDMI reads framebuffer  
6. Display updates in real time  

---

## 6. UART Protocol
Header : 'IMG1'
Width : 16-bit (little-endian)
Height : 16-bit
Data : RGB565 stream

---

## 7. Build and Run

### Build Firmware

```bash
.\build.ps1
## 7. Build and Run

### 7.1 Program FPGA

Generate the bitstream using Vivado and program the FPGA device.

Ensure that the latest `firmware_vex.hex` is correctly loaded into instruction memory before synthesis.

---

### 7.2 Test UART Pipeline

Run the following command to verify the UART-to-HDMI data path:

```bash
py -3.12 send_image.py --test
Expected behavior:

The display shows a 4-color test pattern:
Red
Green
Blue
White

This confirms correct operation of:

UART communication
CPU data handling
Framebuffer write
HDMI output pipeline
7.3 Send Image

To transmit and display a real image:

py -3.12 send_image.py dog.png

The image will be converted to RGB565 format and rendered on the HDMI display.

8. Results
Successful end-to-end UART to HDMI data transfer
Real-time image rendering on external display
Stable operation across multiple clock domains
Verified dual-port RAM framebuffer integrity
