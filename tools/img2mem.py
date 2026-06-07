import sys
import re
from PIL import Image 
from numpy import asarray

if len(sys.argv) < 2:
    print("Uzycie: python img2mem.py <nazwa_pliku.png>")
    sys.exit(1)

image_file = sys.argv[1]

try:
    image = Image.open(image_file).convert('RGB')
except Exception as e:
    print(f"Nie mozna otworzyc pliku: {e}")
    sys.exit(1)

array = asarray(image)

r = array[:,:,0]
g = array[:,:,1]
b = array[:,:,2]

output_file_name = re.sub(r'\.[a-zA-Z0-9]+$', '.mem', image_file)

with open(output_file_name, 'w') as output_file:
    output_file.write(f"// Image ROM content of: {image_file}\n")
    output_file.write(f"// WIDTH = {image.width}\n")
    output_file.write(f"// HEIGHT = {image.height}\n")

    for h in range(image.height):
        for w in range(image.width):
            # Zapisz 4 najstarsze bity dla R, G i B (format RGB 12-bit, po jednym hex)
            pixel = f"{r[h,w]>>4:X}{g[h,w]>>4:X}{b[h,w]>>4:X}"
            output_file.write(pixel + "\n")

print(f"Sukces! Utworzono plik: {output_file_name}")
print(f"Wymiary obrazka: WIDTH={image.width}, HEIGHT={image.height}")