#!env python3
# Quickfix script to convert XBM images to bitmaps for the SSD1306
# Run using bmtoa -cc 01 file | ./rasterize.py
import fileinput
import string

lines = 0
data = {}
for line in fileinput.input():
    data[lines] = line
    lines = lines + 1
    if lines % 8 == 0:
        lines = 0
        print(".DB", end="")
        for i in range(0, len(data[0]) - 1):
            if not data[0][i] in string.printable:
                continue
            if i % 4 == 0:
                    print(" ", end="")
            if i % 16 == 0 and i != 0:
                    print("\n.DB ", end="")
            byte = 0
            for j in range(0, 8):
#                print("Pos " + str(i) + " bit " + str(7-j) + " value " + data[j][i])
                byte |= int(data[j][i]) << 7-j
            print(format(byte, '#04X')+ ", ", end="")
        print()
        print()
