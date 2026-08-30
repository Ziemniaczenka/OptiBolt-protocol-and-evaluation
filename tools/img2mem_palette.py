#!/usr/bin/env python3
"""
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Converts raster image into a palette-indexed
 * draw_bitmap.sv formatted memory file.
 * Instead of storing uncompressed 12-bit RGB values per pixel, 
 * this script maps all unique colors into an indexed color palette table.

USAGE:
    python tools/img2mem_palette.py <input_image> [output_file.mem]

EXAMPLES:
    1. Convert logo with default output name (creates OptiBolt400x102_palette.mem):
       python tools/img2mem_palette.py doc/image_sources/OptiBolt400x102.png

    2. Convert with explicit output path:
       python tools/img2mem_palette.py doc/image_sources/OptiBolt400x102.png rtl/evaluation/display/data/OptiBolt400x102.mem

SYSTEMVERILOG INTEGRATION:
    In SystemVerilog (see `draw_bitmap.sv`):
        draw_bitmap #(
            .BITMAP('{WIDTH, HEIGHT}),
            .USE_PALETTE(1'b1),
            .PALETTE_BITS(2),
            .PALETTE('{12'hFFF, 12'h000, 12'hFF3, 12'hCDF})
        ) u_draw_logo ( ... );

"""

import sys
import re
from PIL import Image
from numpy import asarray

def convert_img_to_palette_mem(image_file, output_file_name=None):
    """
    Reads an image, extracts unique 12-bit RGB colors, generates palette metadata,
    and writes hex index per pixel to output_file_name.
    """
    try:
        image = Image.open(image_file).convert('RGB')
    except Exception as e:
        print(f"Error opening image file '{image_file}': {e}")
        sys.exit(1)

    array = asarray(image)
    r = array[:, :, 0]
    g = array[:, :, 1]
    b = array[:, :, 2]

    # Collect 12-bit RGB colors
    color_order = []
    color_to_idx = {}

    for h in range(image.height):
        for w in range(image.width):
            c_hex = f"{r[h,w]>>4:X}{g[h,w]>>4:X}{b[h,w]>>4:X}"
            if c_hex not in color_to_idx:
                color_to_idx[c_hex] = len(color_order)
                color_order.append(c_hex)

    num_colors = len(color_order)
    print(f"Image dimensions: {image.width}x{image.height} ({image.width * image.height} pixels)")
    print(f"Unique 12-bit colors found: {num_colors}")
    for idx, c in enumerate(color_order):
        print(f"  Palette[{idx}] = 12'h{c}")

    if num_colors <= 2:
        palette_bits = 1
    elif num_colors <= 4:
        palette_bits = 2
    elif num_colors <= 16:
        palette_bits = 4
    elif num_colors <= 256:
        palette_bits = 8
    else:
        print(f"Error: Too many unique colors for palette mode ({num_colors} > 256).")
        sys.exit(1)

    if not output_file_name:
        output_file_name = re.sub(r'\.[a-zA-Z0-9]+$', '_palette.mem', image_file)

    with open(output_file_name, 'w') as output_file:
        output_file.write(f"// Palette Image ROM content of: {image_file}\n")
        output_file.write(f"// WIDTH = {image.width}\n")
        output_file.write(f"// HEIGHT = {image.height}\n")
        output_file.write(f"// PALETTE_BITS = {palette_bits}\n")
        output_file.write(f"// PALETTE_COLORS = {num_colors}\n")
        for idx, c in enumerate(color_order):
            output_file.write(f"// COLOR_{idx} = 12'h{c}\n")

        for h in range(image.height):
            for w in range(image.width):
                c_hex = f"{r[h,w]>>4:X}{g[h,w]>>4:X}{b[h,w]>>4:X}"
                idx = color_to_idx[c_hex]
                if palette_bits <= 4:
                    output_file.write(f"{idx:X}\n")
                else:
                    output_file.write(f"{idx:02X}\n")

    print(f"Successfully generated palette memory file: {output_file_name}")
    print(f"Total bits required: {image.width * image.height * palette_bits} bits "
          f"({image.width * image.height * palette_bits / 36864:.2f} RAMB36 tiles)")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    out_name = sys.argv[2] if len(sys.argv) >= 3 else None
    convert_img_to_palette_mem(sys.argv[1], out_name)
