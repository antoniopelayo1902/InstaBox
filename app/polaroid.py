"""Procesamiento de imagenes con Pillow.

- make_thumbnail: reduce la foto original a 128x128 (requisito de la practica).
- make_polaroid: compone la foto estilo Polaroid (marco blanco + mensaje abajo).
"""

import os
import textwrap
from io import BytesIO

from PIL import Image, ImageDraw, ImageFont

from .config import THUMB_SIZE

# Medidas del Polaroid (en px).
PHOTO_SIZE = 500        # la foto va dentro de un cuadro de 500x500
SIDE_BORDER = 40        # marco blanco lateral y superior
BOTTOM_BORDER = 160     # espacio inferior para el mensaje
TEXT_MARGIN = 20


def make_thumbnail(image_bytes, size=THUMB_SIZE):
    """Reduce la imagen a exactamente `size` (128x128) y la regresa como JPEG."""
    img = Image.open(BytesIO(image_bytes)).convert("RGB")
    img = img.resize(size)
    out = BytesIO()
    img.save(out, format="JPEG", quality=85)
    out.seek(0)
    return out


def _load_font(size):
    """Busca una fuente TTF; si no hay, usa la default escalable de Pillow."""
    candidates = [
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",   # Amazon Linux 2023
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",     # Debian/Ubuntu
        "/usr/share/fonts/dejavu/DejaVuSans.ttf",
        "/Library/Fonts/Arial.ttf",                            # macOS
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                pass
    # Pillow >= 10.1 permite tamano en la fuente por defecto.
    try:
        return ImageFont.load_default(size)
    except TypeError:
        return ImageFont.load_default()


def _draw_message(draw, message, font, area):
    """Dibuja el mensaje centrado dentro de `area` (x0, y0, x1, y1)."""
    if not message:
        return
    x0, y0, x1, y1 = area
    max_width = x1 - x0 - 2 * TEXT_MARGIN

    # Ajusta el texto en varias lineas segun el ancho disponible.
    avg_char_w = max(draw.textlength("n", font=font), 1)
    chars_per_line = max(int(max_width / avg_char_w), 1)
    lines = []
    for paragraph in message.splitlines() or [message]:
        lines.extend(textwrap.wrap(paragraph, width=chars_per_line) or [""])

    ascent, descent = font.getmetrics()
    line_h = ascent + descent + 6
    total_h = line_h * len(lines)
    y = y0 + max((y1 - y0 - total_h) / 2, 0)

    for line in lines:
        w = draw.textlength(line, font=font)
        x = x0 + (x1 - x0 - w) / 2
        draw.text((x, y), line, fill="black", font=font)
        y += line_h


def make_polaroid(image_bytes, message):
    """Compone la foto en formato Polaroid y la regresa como JPEG."""
    photo = Image.open(BytesIO(image_bytes)).convert("RGB")
    photo = photo.resize((PHOTO_SIZE, PHOTO_SIZE))

    width = PHOTO_SIZE + SIDE_BORDER * 2
    height = PHOTO_SIZE + SIDE_BORDER + BOTTOM_BORDER

    canvas = Image.new("RGB", (width, height), "white")
    canvas.paste(photo, (SIDE_BORDER, SIDE_BORDER))

    draw = ImageDraw.Draw(canvas)
    font = _load_font(34)
    text_area = (
        SIDE_BORDER,
        SIDE_BORDER + PHOTO_SIZE,
        SIDE_BORDER + PHOTO_SIZE,
        height,
    )
    _draw_message(draw, message, font, text_area)

    out = BytesIO()
    canvas.save(out, format="JPEG", quality=90)
    out.seek(0)
    return out
