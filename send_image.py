import argparse
import os
import sys
import time
from pathlib import Path

import serial

try:
    from PIL import Image
except Exception:
    Image = None

DEFAULT_PORT = "COM4"
DEFAULT_BAUD = 115200
WIDTH = 300
HEIGHT = 300
HEADER = b"IMG1"
PIXEL_BYTES = WIDTH * HEIGHT * 2


def rgb888_to_rgb565(r: int, g: int, b: int) -> int:
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def build_packet_from_rgb565_bytes(raw: bytes) -> bytes:
    if len(raw) != PIXEL_BYTES:
        raise ValueError(
            f"RGB565 payload must be exactly {PIXEL_BYTES} bytes, got {len(raw)}"
        )
    payload = bytearray()
    payload.extend(HEADER)
    payload.extend((WIDTH & 0xFF, (WIDTH >> 8) & 0xFF))
    payload.extend((HEIGHT & 0xFF, (HEIGHT >> 8) & 0xFF))
    payload.extend(raw)
    return bytes(payload)


def build_test_pattern() -> bytes:
    raw = bytearray()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if x < WIDTH // 2 and y < HEIGHT // 2:
                r, g, b = 255, 0, 0
            elif x >= WIDTH // 2 and y < HEIGHT // 2:
                r, g, b = 0, 255, 0
            elif x < WIDTH // 2 and y >= HEIGHT // 2:
                r, g, b = 0, 0, 255
            else:
                r, g, b = 255, 255, 255
            pixel = rgb888_to_rgb565(r, g, b)
            raw.extend((pixel & 0xFF, (pixel >> 8) & 0xFF))
    return build_packet_from_rgb565_bytes(bytes(raw))


def build_from_raw_rgb565(image_path: str) -> bytes:
    raw = Path(image_path).read_bytes()
    return build_packet_from_rgb565_bytes(raw)


def build_from_regular_image(image_path: str) -> bytes:
    if Image is None:
        raise RuntimeError("Pillow is not installed. Install with: pip install pillow")

    img = Image.open(image_path).convert("RGB")
    img = img.resize((WIDTH, HEIGHT))
    raw = bytearray()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            r, g, b = img.getpixel((x, y))
            pixel = rgb888_to_rgb565(r, g, b)
            raw.extend((pixel & 0xFF, (pixel >> 8) & 0xFF))
    return build_packet_from_rgb565_bytes(bytes(raw))


def build_packet_from_image_path(image_path: str) -> bytes:
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"File not found: {image_path}")

    suffix = Path(image_path).suffix.lower()
    if suffix in {".raw", ".rgb565", ".bin"}:
        return build_from_raw_rgb565(image_path)
    return build_from_regular_image(image_path)


def send_packet(port: str, baud: int, packet: bytes, delay: float, chunk: int, chunk_pause: float) -> int:
    print(f"Prepared image packet: {len(packet)} bytes")
    print(f"Port: {port}, baud: {baud}")

    if delay > 0:
        print(f"Waiting {delay:.2f}s before sending...")
        time.sleep(delay)

    try:
        with serial.Serial(port, baud, timeout=1) as ser:
            time.sleep(0.2)
            print("Sending header + size + pixels...")
            if chunk <= 0:
                ser.write(packet)
            else:
                for i in range(0, len(packet), chunk):
                    ser.write(packet[i:i + chunk])
                    ser.flush()
                    if chunk_pause > 0:
                        time.sleep(chunk_pause)
            ser.flush()
    except Exception as exc:
        print(f"Serial send failed: {exc}")
        return 1

    print("Image sent successfully.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Send a 300x300 image over UART using IMG1 protocol. Normal image files are auto-converted to RGB565."
    )
    parser.add_argument("--port", default=DEFAULT_PORT)
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD)
    parser.add_argument("--delay", type=float, default=0.2)
    parser.add_argument("--chunk", type=int, default=256, help="bytes per write, 0 = send all at once")
    parser.add_argument("--chunk-pause", type=float, default=0.0, help="pause between chunks in seconds")
    parser.add_argument("--test", action="store_true")
    parser.add_argument("image", nargs="?")
    args = parser.parse_args()

    try:
        if args.test:
            packet = build_test_pattern()
        else:
            if not args.image:
                print("Error: provide an image path, or use --test")
                return 1
            packet = build_packet_from_image_path(args.image)
    except Exception as exc:
        print(f"Failed to prepare image: {exc}")
        return 1

    return send_packet(args.port, args.baud, packet, args.delay, args.chunk, args.chunk_pause)


if __name__ == "__main__":
    sys.exit(main())
