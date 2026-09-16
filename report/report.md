# Práctica 1: InstaBox

**Nombre:** <tu nombre>
**Materia:** Desarrollo en la Nube — ITESO
**Fecha:** <fecha de entrega>

## Descripción del proyecto

<!-- 200-300 palabras. Sugerencia de contenido:

InstaBox es un backend serverless-friendly desplegado en AWS para la estación
de fotos de un fotógrafo de eventos. Permite registrar eventos, recibir fotos
con un mensaje de los invitados, generar una versión Polaroid de cada foto y,
al finalizar el evento, entregar un álbum en formato .zip.

El backend está construido en Python con FastAPI y corre en una instancia EC2.
Expone cuatro endpoints: POST /events crea un evento y lo registra en la base
de datos; POST /upload recibe una foto y un mensaje, reduce la imagen a 128x128,
compone la Polaroid (marco blanco y mensaje debajo) con Pillow, sube ambas
versiones a S3 y guarda la metadata en RDS; GET /events/{id} devuelve la
información del evento y el número de fotos; POST /finish empaqueta las
Polaroids en un archivo .zip descargable.

Describe aquí las decisiones de arquitectura: por qué RDS PostgreSQL, cómo se
relacionan las tablas events y photos por event_id, cómo la EC2 usa el instance
profile LabInstanceProfile para leer las credenciales desde Secrets Manager sin
hardcodearlas, y cómo se organizan los objetos en S3 (pictures/ y polaroids/).
-->

## Diagrama de arquitectura

```
Cliente HTTP
     │
     ▼
  EC2 (FastAPI)  ── instance profile: LabInstanceProfile
     ├──► Secrets Manager  (credenciales de RDS)
     ├──► RDS PostgreSQL    (tablas events, photos)
     └──► S3                (pictures/ 128x128, polaroids/)
```

<!-- Puedes reemplazar el diagrama por una imagen exportada. -->

## Declaración sobre el uso de IA

Utilicé asistencia de IA (Kiro) para <describe: generar el andamiaje del
backend, los scripts de infraestructura y el README>. Revisé, entendí y probé
el código generado; las decisiones de arquitectura y la validación en la nube
fueron propias. El uso de IA fue de apoyo al aprendizaje y no sustituyó la
comprensión del desarrollo.

## Anexos (opcional)

<!-- Capturas: bucket S3 y archivos, RDS con las tablas, secret en Secrets
Manager, EC2 con su instance profile, respuestas de los endpoints, etc. -->
