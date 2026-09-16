# Práctica 1: InstaBox

**Nombre:** <tu nombre>
**Materia:** Desarrollo en la Nube — ITESO
**Fecha:** <fecha de entrega>

## Descripción del proyecto

InstaBox es el backend de una estación de fotos para bodas y eventos sociales.
Resuelve un problema del fotógrafo: como atiende varios eventos a la vez,
necesita mantener separadas las fotos y los mensajes de cada uno, y al terminar
entregar un álbum estilo Polaroid listo para imprimir.

El sistema ofrece cuatro operaciones. La primera registra un evento nuevo (con
el nombre del cliente, el tipo de evento y la fecha) y devuelve un
identificador único. La segunda recibe una foto y un mensaje de un invitado:
genera una versión reducida de la imagen, arma la Polaroid agregando el marco
blanco y el mensaje debajo, y guarda ambas versiones junto con su información.
La tercera permite consultar los datos de un evento y cuántas fotos lleva. La
última cierra el evento y entrega todas las Polaroids empaquetadas en un solo
archivo comprimido para descargar.

Todo corre en la nube de AWS con una separación clara de responsabilidades. El
código de la aplicación se ejecuta en un servidor EC2 y es el único punto de
entrada por HTTP. Las imágenes se almacenan en S3, separadas en dos carpetas:
una para las fotos originales reducidas y otra para las Polaroids terminadas.
La información de eventos y fotos se guarda en una base de datos relacional en
RDS, con dos tablas conectadas por el identificador del evento. Las contraseñas
de la base de datos no viven en el código: se guardan en AWS Secrets Manager y
la aplicación las obtiene al momento de ejecutarse, usando los permisos que le
otorga su instance profile. Cada archivo se identifica con un nombre único para
evitar colisiones. El resultado es una solución sencilla, funcional y coherente
con una arquitectura de nube.

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
