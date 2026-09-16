"""Prueba local de la composicion de imagenes (sin AWS).

Genera un thumbnail 128x128 y una polaroid a partir de una imagen de prueba,
para verificar que Pillow y la logica de polaroid.py funcionan.

Uso:
    python scripts/smoke-test-polaroid.py [ruta_imagen]

Si no pasas una imagen, se genera una de prueba.
"""

import sys
from io import BytesIO

from PIL import Image

sys.path.insert(0, ".")
from app.polaroid import make_polaroid, make_thumbnail  # noqa: E402


def sample_image_bytes():
    img = Image.new("RGB", (800, 600), (70, 130, 180))
    buf = BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1], "rb") as f:
            raw = f.read()
    else:
        raw = sample_image_bytes()

    thumb = make_thumbnail(raw)
    with open("thumb-test.jpg", "wb") as f:
        f.write(thumb.read())

    pol = make_polaroid(raw, "Felicidades a los novios! Con carino, la familia.")
    with open("polaroid-test.jpg", "wb") as f:
        f.write(pol.read())

    # Verifica tamano del thumbnail
    thumb.seek(0)
    assert Image.open("thumb-test.jpg").size == (128, 128), "el thumbnail no es 128x128"
    print("OK: thumb-test.jpg (128x128) y polaroid-test.jpg generados.")


if __name__ == "__main__":
    main()
