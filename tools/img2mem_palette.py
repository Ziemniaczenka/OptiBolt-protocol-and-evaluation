import sys
import re
from PIL import Image
from numpy import asarray

def convert_img_to_palette_mem(image_file, output_file_name=None):
    try:
        image = Image.open(image_file).convert('RGB')
    except Exception as e:
        print(f"Nie mozna otworzyc pliku: {e}")
        sys.exit(1)

    array = asarray(image)
    r = array[:, :, 0]
    g = array[:, :, 1]
    b = array[:, :, 2]

    # Collect 12-bit RGB colors
    pixels_12b = []
    color_order = []
    color_to_idx = {}

    for h in range(image.height):
        for w in range(image.width):
            c_hex = f"{r[h,w]>>4:X}{g[h,w]>>4:X}{b[h,w]>>4:X}"
            if c_hex not in color_to_idx:
                color_to_idx[c_hex] = len(color_order)
                color_order.append(c_hex)
            pixels_12b.append(c_hex)

    num_colors = len(color_order)
    print(f"Liczba unikalnych kolorow: {num_colors}")
    for idx, c in enumerate(color_order):
        print(f"  Kolor {idx}: 12'h{c}")

    if num_colors <= 2:
        palette_bits = 1
    elif num_colors <= 4:
        palette_bits = 2
    elif num_colors <= 16:
        palette_bits = 4
    elif num_colors <= 256:
        palette_bits = 8
    else:
        print(f"Blad: Zbyt duzo kolorow dla palety: {num_colors}")
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

    print(f"Sukces! Utworzono plik: {output_file_name}")
    print(f"Wymiary obrazka: WIDTH={image.width}, HEIGHT={image.height}, BITS_PER_PIXEL={palette_bits}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Uzycie: python img2mem_palette.py <nazwa_pliku.png> [wyjsciowy_plik.mem]")
        sys.exit(1)

    out_name = sys.argv[2] if len(sys.argv) >= 3 else None
    convert_img_to_palette_mem(sys.argv[1], out_name)

