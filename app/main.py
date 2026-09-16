"""InstaBox API.

Backend para la estacion de fotos del fotografo de eventos.

Endpoints:
  POST /events              -> crea un evento en RDS, regresa event_id
  POST /upload              -> sube foto reducida + polaroid a S3 y guarda en RDS
  GET  /events/{event_id}   -> metadata del evento + numero de fotos
  POST /finish              -> zip descargable con las polaroids del evento
"""

import io
import uuid
import zipfile
from datetime import date
from typing import Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from .config import (
    ALLOWED_CONTENT_TYPES,
    MAX_UPLOAD_BYTES,
    PICTURES_PREFIX,
    POLAROIDS_PREFIX,
)
from .db import dict_cursor, get_conn
from .polaroid import make_polaroid, make_thumbnail
from .s3_utils import delete_keys, download_bytes, upload_fileobj

app = FastAPI(title="InstaBox", version="1.0.0")


# --------------------------- modelos ---------------------------

class EventIn(BaseModel):
    client_name: str
    event_type: Optional[str] = None
    event_date: Optional[date] = None


class FinishIn(BaseModel):
    event_id: str


# --------------------------- helpers ---------------------------

def _event_exists(cur, event_id):
    cur.execute("SELECT 1 FROM events WHERE event_id = %s", (event_id,))
    return cur.fetchone() is not None


# --------------------------- endpoints ---------------------------

@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/events")
def create_event(event: EventIn):
    """Crea un evento nuevo y regresa el event_id generado."""
    event_id = str(uuid.uuid4())
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO events (event_id, client_name, event_type, event_date)
                VALUES (%s, %s, %s, %s)
                """,
                (event_id, event.client_name, event.event_type, event.event_date),
            )
    return {"event_id": event_id}


@app.post("/upload")
async def upload(
    event_id: str = Form(...),
    message: str = Form(""),
    file: UploadFile = File(...),
):
    """Sube la foto reducida a pictures/, compone la polaroid en polaroids/
    y guarda el registro en RDS. Todo en la misma llamada."""
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Solo se permiten imagenes JPEG o PNG")

    raw = await file.read()
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=400, detail="La imagen excede el tamano maximo permitido")
    if not raw:
        raise HTTPException(status_code=400, detail="Archivo vacio")

    # Verifica que el evento exista antes de subir nada.
    with get_conn() as conn:
        with conn.cursor() as cur:
            if not _event_exists(cur, event_id):
                raise HTTPException(status_code=404, detail="Evento no encontrado")

    # Nombre unico (UUID) para original y polaroid.
    photo_id = str(uuid.uuid4())
    picture_key = f"{PICTURES_PREFIX}{photo_id}.jpg"
    polaroid_key = f"{POLAROIDS_PREFIX}{photo_id}.jpg"

    # 1) foto original reducida 128x128
    upload_fileobj(make_thumbnail(raw), picture_key, content_type="image/jpeg")
    # 2) polaroid compuesta (marco + mensaje)
    upload_fileobj(make_polaroid(raw, message), polaroid_key, content_type="image/jpeg")

    # 3) metadata en RDS
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO photos (photo_id, event_id, message, picture_key, polaroid_key)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (photo_id, event_id, message, picture_key, polaroid_key),
            )

    return {
        "photo_id": photo_id,
        "event_id": event_id,
        "message": message,
        "picture_key": picture_key,
        "polaroid_key": polaroid_key,
    }


@app.get("/events/{event_id}")
def get_event(event_id: str):
    """Regresa la metadata del evento y el numero de fotos asociadas."""
    with get_conn() as conn:
        with dict_cursor(conn) as cur:
            cur.execute("SELECT * FROM events WHERE event_id = %s", (event_id,))
            event = cur.fetchone()
            if event is None:
                raise HTTPException(status_code=404, detail="Evento no encontrado")
            cur.execute(
                "SELECT COUNT(*) AS photo_count FROM photos WHERE event_id = %s",
                (event_id,),
            )
            event["photo_count"] = cur.fetchone()["photo_count"]
    return event


@app.post("/finish")
def finish(payload: FinishIn):
    """Empaqueta las polaroids del evento en un .zip descargable.

    Al terminar, elimina las fotos ORIGINALES de pictures/ (las polaroids
    se conservan), tal como describe el enunciado."""
    event_id = payload.event_id

    with get_conn() as conn:
        with dict_cursor(conn) as cur:
            if not _event_exists(cur, event_id):
                raise HTTPException(status_code=404, detail="Evento no encontrado")
            cur.execute(
                "SELECT photo_id, picture_key, polaroid_key FROM photos WHERE event_id = %s",
                (event_id,),
            )
            rows = cur.fetchall()

    if not rows:
        raise HTTPException(status_code=404, detail="El evento no tiene fotos")

    # Construye el zip en memoria con las polaroids.
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        for row in rows:
            data = download_bytes(row["polaroid_key"]).read()
            arcname = row["polaroid_key"].split("/")[-1]
            zf.writestr(arcname, data)
    zip_buffer.seek(0)

    # Elimina las fotos originales (se conservan solo las polaroids).
    delete_keys([row["picture_key"] for row in rows])

    filename = f"event-{event_id}-polaroids.zip"
    return StreamingResponse(
        zip_buffer,
        media_type="application/zip",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
