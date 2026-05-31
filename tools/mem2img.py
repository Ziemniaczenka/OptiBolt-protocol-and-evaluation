import sys
import re
from PIL import Image 
from numpy import array, uint8

if len(sys.argv) < 2:
    print("Uzycie: python mem2img.py <nazwa_pliku.mem>")
    sys.exit(1)

mem_file_name = sys.argv[1]

if not mem_file_name.lower().endswith('.mem'):
    print(f"Ostrzeżenie: Plik '{mem_file_name}' nie ma rozszerzenia .mem. Upewnij się, że podajesz plik tekstowy z pamięcią, a nie oryginalny obraz.")

try:
    with open(mem_file_name, 'r', encoding='utf-8') as mem_file:
        mem_file.readline() # pomin pierwsza linie naglowka
        
        width = int(re.sub(r'\n', '', re.sub(r'// WIDTH = ', '', mem_file.readline())))
        height = int(re.sub(r'\n', '', re.sub(r'// HEIGHT = ', '', mem_file.readline())))

        rgb = array([[[0]*4 for _ in range(width)] for _ in range(height)], dtype=uint8)

        w = 0
        h = 0
        for line in mem_file:
            pixel = line.strip()
            if len(pixel) == 3:
                # Odzyskaj dane pomnożone przez 16 (<<4) lub 17 dla lepszego wyskalowania
                rgb[h,w] = [int(pixel[0], 16)*17, int(pixel[1], 16)*17, int(pixel[2], 16)*17, 255]
                
                w += 1
                if w == width:
                    w = 0
                    h += 1

    image = Image.fromarray(rgb)
    image.show()
except UnicodeDecodeError:
    print("Błąd kodowania znaków: Próbujesz odczytać plik binarny (np. .png) jako plik tekstowy. Użyj pliku z rozszerzeniem .mem!")
except Exception as e:
    print(f"Blad podczas ladowania pamieci: {e}")