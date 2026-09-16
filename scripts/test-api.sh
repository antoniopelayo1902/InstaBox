#!/usr/bin/env bash
#
# test-api.sh
# Corre el flujo completo de la API contra la URL que le pases. Util para el
# video: crea un evento, sube 3 fotos, consulta la metadata y descarga el zip.
#
# Uso:
#   ./test-api.sh http://<IP_PUBLICA>:8000 [foto1 foto2 foto3]
#
# Si no pasas fotos, usa las de demo-fotos/.
#
set -euo pipefail

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  echo "Uso: ./test-api.sh http://<IP>:8000 [foto1 foto2 foto3]" >&2
  exit 1
fi
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ "$#" -ge 3 ]]; then
  F1="$1"; F2="$2"; F3="$3"
else
  F1="${ROOT_DIR}/demo-fotos/foto1.jpg"
  F2="${ROOT_DIR}/demo-fotos/foto2.jpg"
  F3="${ROOT_DIR}/demo-fotos/foto3.jpg"
fi

echo "== 1) Crear evento =="
EV=$(curl -s -X POST "$BASE/events" -H 'Content-Type: application/json' \
  -d '{"client_name":"Ana y Luis","event_type":"boda","event_date":"2026-09-20"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['event_id'])")
echo "event_id = $EV"
echo

echo "== 2) Subir 3 fotos con mensaje =="
curl -s -o /dev/null -w "  foto1 -> HTTP %{http_code}\n" -X POST "$BASE/upload" \
  -F "event_id=$EV" -F "message=Felicidades a los novios!" -F "file=@${F1}"
curl -s -o /dev/null -w "  foto2 -> HTTP %{http_code}\n" -X POST "$BASE/upload" \
  -F "event_id=$EV" -F "message=Que vivan los novios" -F "file=@${F2}"
curl -s -o /dev/null -w "  foto3 -> HTTP %{http_code}\n" -X POST "$BASE/upload" \
  -F "event_id=$EV" -F "message=Los queremos, la familia" -F "file=@${F3}"
echo

echo "== 3) GET metadata del evento =="
curl -s "$BASE/events/$EV" | python3 -m json.tool
echo

echo "== 4) Finish: descargar zip de polaroids =="
curl -s -X POST "$BASE/finish" -H 'Content-Type: application/json' \
  -d "{\"event_id\":\"$EV\"}" -o polaroids.zip -w "  finish -> HTTP %{http_code}\n"
echo "  Contenido del zip:"
unzip -l polaroids.zip | sed 's/^/    /'
echo
echo "Listo. event_id usado: $EV"
