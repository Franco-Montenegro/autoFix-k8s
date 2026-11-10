#!/usr/bin/env bash
# Carga datos de demostracion a traves del API Gateway (el mismo camino que usa el frontend).
# Solo se ejecuta si no hay vehiculos registrados.
#
# Uso: ./scripts/seed-demo.sh [URL del Gateway]   (por defecto http://$(minikube ip):30080/api)
set -euo pipefail

API="${1:-http://$(minikube ip):30080/api}"

# call METODO RUTA [JSON] -> imprime el cuerpo; falla si la respuesta no es 2xx
call() {
  local out code
  out=$(curl -s -w $'\n%{http_code}' -X "$1" "${API}$2" -H 'Content-Type: application/json' ${3:+-d "$3"})
  code="${out##*$'\n'}"
  if [ "${code}" -lt 200 ] || [ "${code}" -ge 300 ]; then
    echo "ERROR ${code} en $1 $2: ${out%$'\n'*}" >&2; exit 1
  fi
  printf '%s' "${out%$'\n'*}"
}
id_of() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

if [ "$(call GET /vehicles)" != "[]" ]; then
  echo "Ya hay vehiculos registrados: no se cargan datos de demostracion."; exit 0
fi

echo "==> HU1: vehiculos"
vehicle() { call POST /vehicles "{\"licensePlate\":\"$1\",\"brand\":\"$2\",\"model\":\"$3\",\"vehicleType\":\"$4\",\"manufactureYear\":$5,\"engineType\":\"$6\",\"seats\":$7}" >/dev/null; echo "  $1 $2 $3"; }
vehicle ABCD12 Toyota  Corolla SEDAN     2018 GASOLINE 5
vehicle BCDF34 Ford    Ranger  PICKUP    2015 DIESEL   5
vehicle CDFG56 Hyundai Tucson  SUV       2021 HYBRID   5
vehicle DFGH78 Honda   e       HATCHBACK 2022 ELECTRIC 4
vehicle FGHJ90 Hyundai Staria  VAN       2020 DIESEL   9
vehicle GHJK11 Kia     Rio     SEDAN     2019 GASOLINE 5   # sin ingresos: fila vacia en HU4

echo "==> Bonos"
B_TOYOTA=$(call POST /bonuses '{"brand":"TOYOTA","year":2026,"month":8,"quantity":1,"amount":50000}' | id_of)
B_HYUNDAI=$(call POST /bonuses '{"brand":"HYUNDAI","year":2026,"month":9,"quantity":2,"amount":40000}' | id_of)
B_FORD=$(call POST /bonuses '{"brand":"FORD","year":2026,"month":10,"quantity":3,"amount":60000}' | id_of)

echo "==> HU3: ingresos, salidas, retiros y costos"
# order PATENTE INGRESO KM ITEMS_JSON -> id
order() { call POST /repair-orders "{\"licensePlate\":\"$1\",\"entryDateTime\":\"$2\",\"mileage\":$3,\"items\":$4}" | id_of; }
ready()  { call PATCH "/repair-orders/$1/ready"  "{\"dateTime\":\"$2\"}" >/dev/null; }
pickup() { call PATCH "/repair-orders/$1/pickup" "{\"dateTime\":\"$2\"}" | grep -o '"totalAmount":[0-9]*' | cut -d: -f2; }
bonus()  { call PUT "/repair-orders/$1/bonus" "{\"bonusId\":$2}" >/dev/null; }

# Agosto
o=$(order ABCD12 2026-08-03T10:00:00 45000 '[{"repairTypeId":3},{"repairTypeId":4,"repairDateTime":"2026-08-04T09:00:00"}]')
bonus $o "$B_TOYOTA"; ready $o 2026-08-05T17:00:00; echo "  #$o ABCD12 entregado: \$$(pickup $o 2026-08-07T10:00:00)"
o=$(order BCDF34 2026-08-19T15:30:00 128000 '[{"repairTypeId":3},{"repairTypeId":10,"repairDateTime":"2026-08-20T10:00:00"}]')
ready $o 2026-08-25T18:00:00; echo "  #$o BCDF34 entregado: \$$(pickup $o 2026-08-29T11:00:00)"
o=$(order FGHJ90 2026-08-24T09:30:00 30000 '[{"repairTypeId":1},{"repairTypeId":7}]')
ready $o 2026-08-24T16:00:00; echo "  #$o FGHJ90 entregado: \$$(pickup $o 2026-08-24T18:00:00)"
# Septiembre
o=$(order CDFG56 2026-09-10T11:00:00 22000 '[{"repairTypeId":2},{"repairTypeId":5},{"repairTypeId":9,"repairDateTime":"2026-09-11T10:00:00"}]')
bonus $o "$B_HYUNDAI"; ready $o 2026-09-12T13:00:00; echo "  #$o CDFG56 entregado: \$$(pickup $o 2026-09-12T16:30:00)"
o=$(order ABCD12 2026-09-21T16:00:00 52000 '[{"repairTypeId":8}]')
ready $o 2026-09-23T12:00:00; echo "  #$o ABCD12 entregado: \$$(pickup $o 2026-09-24T09:30:00)"
o=$(order FGHJ90 2026-09-28T11:00:00 31000 '[{"repairTypeId":1}]')
bonus $o "$B_HYUNDAI"; ready $o 2026-09-29T15:00:00; echo "  #$o FGHJ90 entregado: \$$(pickup $o 2026-10-01T10:00:00)"
# Octubre
o=$(order DFGH78 2026-10-05T09:30:00 8000 '[{"repairTypeId":11},{"repairTypeId":7},{"repairTypeId":1,"repairDateTime":"2026-10-06T09:00:00"}]')
ready $o 2026-10-07T15:00:00; echo "  #$o DFGH78 entregado: \$$(pickup $o 2026-10-08T10:00:00)"
o=$(order BCDF34 2026-10-15T10:00:00 131000 '[{"repairTypeId":1},{"repairTypeId":6}]')
bonus $o "$B_FORD"; ready $o 2026-10-16T17:00:00; echo "  #$o BCDF34 entregado: \$$(pickup $o 2026-10-20T11:00:00)"
o=$(order ABCD12 2026-10-26T14:00:00 55000 '[{"repairTypeId":1},{"repairTypeId":7}]')
ready $o 2026-10-27T18:00:00; echo "  #$o ABCD12 listo para retiro"
o=$(order CDFG56 2026-10-29T10:00:00 23000 '[{"repairTypeId":4}]')
echo "  #$o CDFG56 en reparacion"

echo
echo "==> Verificacion"
echo "  HU4 historial:  $(call GET /history | grep -o '"licensePlate"' | wc -l | tr -d ' ') filas"
echo "  HU5 octubre:    $(call GET '/reports/r1?year=2026&month=10' | grep -o '"grandTotal":{[^}]*}')"
echo "  HU6 octubre:    $(call GET '/reports/r2?year=2026&month=10' | grep -o '"month":"[^"]*","previous":"[^"]*","beforePrevious":"[^"]*"')"
