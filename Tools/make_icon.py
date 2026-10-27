# Disegna l'icona di NettoLR: la marca da bollo prugna con la N, su fondo notte.
# Crea anche le varianti per iOS 18: «scura» e «tinta» (in scala di grigi, la colora il sistema).
# Uso: python3 Tools/make_icon.py   (richiede Pillow)
from PIL import Image, ImageDraw, ImageOps

LATO = 1024
SCALA = 4                      # si disegna 4 volte più grande e poi si riduce: bordi morbidi
NOTTE = (0x21, 0x13, 0x1B)
ROSA = (0xD8, 0x8B, 0xB2)
CARTELLA = "Resources/Assets.xcassets/AppIcon.appiconset"


def disegna(fondo, timbro, inchiostro):
    L = LATO * SCALA
    img = Image.new("RGB", (L, L), fondo)
    d = ImageDraw.Draw(img)
    u = L / 100                # griglia 100×100, come il disegno del logo
    # La marca: quadrato 20…80 con i dentelli tolti lungo i bordi
    d.rectangle([20 * u, 20 * u, 80 * u, 80 * u], fill=timbro)
    r = 3.6 * u
    for i in range(7):
        p = (20 + i * 10) * u
        for cx, cy in [(p, 20 * u), (p, 80 * u), (20 * u, p), (80 * u, p)]:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fondo)
    # Cornice interna e N
    d.rectangle([28 * u, 28 * u, 72 * u, 72 * u], outline=inchiostro, width=round(2 * u))
    n = [(38, 64), (38, 36), (44, 36), (56, 54), (56, 36), (62, 36), (62, 64), (56, 64), (44, 46), (44, 64)]
    d.polygon([(x * u, y * u) for x, y in n], fill=inchiostro)
    return img.resize((LATO, LATO), Image.LANCZOS)


chiara = disegna(NOTTE, ROSA, NOTTE)
chiara.save(f"{CARTELLA}/AppIcon.png")
chiara.save(f"{CARTELLA}/AppIcon-dark.png")      # il logo è già su fondo scuro
ImageOps.grayscale(chiara).convert("RGB").save(f"{CARTELLA}/AppIcon-tinted.png")
print("icone pronte")
