# InstaBox

Backend para la estación de fotos de un fotógrafo de eventos. Los invitados
suben fotos con un mensaje; al terminar el evento se genera un álbum estilo
**Polaroid** empaquetado en un `.zip`. Práctica 1 — Desarrollo en la Nube (ITESO).

## Arquitectura

```
                         AWS
   ┌──────────────────────────────────────────────────┐
   │  EC2  (backend FastAPI)                            │
   │    instance profile: LabInstanceProfile            │
   │      │                                             │
   │      ├──► Secrets Manager   (credenciales de RDS)  │
   │      ├──► RDS PostgreSQL     (events, photos)       │
   │      └──► S3                 (pictures/, polaroids/)│
   └──────────────────────────────────────────────────┘
```

- **EC2** corre el backend y expone los endpoints por HTTP (puerto 8000).
- La EC2 usa el **instance profile `LabInstanceProfile`**; no se usan credenciales de usuario.
- Las **credenciales de RDS** se leen de **Secrets Manager en tiempo de ejecución**.
- **RDS PostgreSQL** guarda dos tablas relacionadas por `event_id`: `events` y `photos`.
- **S3** guarda la foto original reducida (128x128) en `pictures/` y la polaroid en `polaroids/`.
- Cada foto se guarda con un nombre único (**UUID**).

## Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/events` | Crea un evento en RDS. Regresa `event_id`. |
| `POST` | `/upload` | Recibe `event_id`, `message` y `file`. Sube reducida a `pictures/`, polaroid a `polaroids/` y guarda metadata en RDS. |
| `GET`  | `/events/{event_id}` | Metadata del evento + número de fotos. |
| `POST` | `/finish` | Devuelve un `.zip` con las polaroids del evento (y borra las originales). |
| `GET`  | `/health` | Healthcheck. |

## Estructura

```
InstaBox/
├── app/
│   ├── main.py         # endpoints FastAPI
│   ├── config.py       # configuración (bucket, secret, región)
│   ├── secrets.py      # lee credenciales de RDS desde Secrets Manager
│   ├── db.py           # conexión a RDS PostgreSQL
│   ├── s3_utils.py     # subir/descargar/borrar en S3
│   └── polaroid.py     # reducción 128x128 + composición Polaroid (Pillow)
├── sql/schema.sql      # tablas events y photos
├── scripts/
│   ├── config.sh       # configuración compartida
│   ├── setup-network.sh
│   ├── setup-s3.sh
│   ├── setup-rds.sh
│   ├── setup-secret.sh
│   ├── init-db.sh
│   ├── deploy-ec2.sh
│   ├── remote-setup.sh # corre dentro de la EC2
│   └── teardown.sh
├── report/report.md    # borrador del reporte
├── requirements.txt
└── README.md
```

## Requisitos

- AWS CLI configurado (en el Learner Lab: exporta las credenciales del lab).
- `bash`, `curl`, `ssh`, `scp`, `openssl`.
- `psql` (cliente de PostgreSQL) para inicializar el esquema.
- Python 3.11+ (para probar localmente, opcional).
- El key pair del lab (`vockey`) y su `labsuser.pem` descargado.

## Despliegue paso a paso

> Ajusta el nombre del bucket (debe ser único global):
> ```bash
> export S3_BUCKET=instabox-mi-equipo-123
> export EC2_KEY_PATH=~/Downloads/labsuser.pem
> ```

```bash
cd InstaBox

# 1. Red (security groups en la VPC default)
./scripts/setup-network.sh

# 2. Bucket S3 con pictures/ y polaroids/
./scripts/setup-s3.sh

# 3. RDS PostgreSQL (tarda varios minutos)
./scripts/setup-rds.sh

# 4. Guardar credenciales de RDS en Secrets Manager
./scripts/setup-secret.sh

# 5. Crear las tablas events y photos
./scripts/init-db.sh

# 6. Lanzar EC2, copiar el código y arrancar la app
./scripts/deploy-ec2.sh
```

Al final, `deploy-ec2.sh` imprime la URL base, por ejemplo
`http://<IP_PUBLICA>:8000`.

## Probar la API

```bash
BASE=http://<IP_PUBLICA>:8000

# Crear evento
curl -s -X POST $BASE/events \
  -H 'Content-Type: application/json' \
  -d '{"client_name":"Ana y Luis","event_type":"boda","event_date":"2026-09-20"}'
# -> {"event_id":"...."}

EVENT_ID=<pega-el-event_id>

# Subir 3 fotos con mensaje
curl -s -X POST $BASE/upload \
  -F "event_id=$EVENT_ID" -F "message=Felicidades!" -F "file=@foto1.jpg"
curl -s -X POST $BASE/upload \
  -F "event_id=$EVENT_ID" -F "message=Que vivan los novios" -F "file=@foto2.jpg"
curl -s -X POST $BASE/upload \
  -F "event_id=$EVENT_ID" -F "message=Los queremos" -F "file=@foto3.png"

# Consultar metadata + número de fotos
curl -s $BASE/events/$EVENT_ID

# Descargar el zip de polaroids
curl -s -X POST $BASE/finish \
  -H 'Content-Type: application/json' \
  -d "{\"event_id\":\"$EVENT_ID\"}" \
  -o polaroids.zip
unzip -l polaroids.zip
```

## Limpieza de recursos (IMPORTANTE)

Elimina todo (EC2, RDS, secret, bucket y security groups) con:

```bash
./scripts/teardown.sh
```

Te pedirá confirmación y esperará a que RDS y EC2 se borren antes de quitar los
security groups.

## Notas de seguridad

- El bucket S3 no es público; solo la EC2 (vía IAM) escribe y lee.
- El security group de RDS solo permite el puerto 5432 desde el SG de la EC2
  (y desde tu IP mientras corres `init-db.sh`).
- Las credenciales de RDS viven en Secrets Manager, nunca en el código ni en
  variables de ambiente con el valor en claro.
- La app valida tipo (JPEG/PNG) y tamaño de archivo en `/upload`.

## Declaración sobre uso de IA

Ver `report/report.md`.
