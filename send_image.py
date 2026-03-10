import sys
import serial
from PIL import Image

PORT = "COM6"       
BAUD = 921600
WIDTH = 300
HEIGHT = 300

def rgb888_to_rgb565(r, g, b):
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)

def main():

    if len(sys.argv) < 2:
        print("Usage: python send_image.py image.png")
        return

    image_path = sys.argv[1]

    print("Opening image:", image_path)

    img = Image.open(image_path).convert("RGB")
    img = img.resize((WIDTH, HEIGHT))

    print("Image resized to 300x300")

    ser = serial.Serial(PORT, BAUD)

    print("Sending header...")

    # HEADER
    ser.write(b'IMG1')

    # WIDTH
    ser.write(bytes([WIDTH & 0xFF]))
    ser.write(bytes([(WIDTH >> 8) & 0xFF]))

    # HEIGHT
    ser.write(bytes([HEIGHT & 0xFF]))
    ser.write(bytes([(HEIGHT >> 8) & 0xFF]))

    print("Sending pixels...")

    total = WIDTH * HEIGHT
    sent = 0

    for y in range(HEIGHT):
        for x in range(WIDTH):

            r, g, b = img.getpixel((x, y))
            pixel = rgb888_to_rgb565(r, g, b)

            ser.write(bytes([pixel & 0xFF]))
            ser.write(bytes([(pixel >> 8) & 0xFF]))

            sent += 1

            if sent % 10000 == 0:
                print(f"{sent}/{total} pixels sent")

    ser.close()

    print("Image sent successfully!")

if __name__ == "__main__":
    main()