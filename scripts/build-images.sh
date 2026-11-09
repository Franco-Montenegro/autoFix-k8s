#!/usr/bin/env bash
# Construye las 8 imagenes de AutoFix (Evaluacion 2) y, con --push, las publica en Docker Hub.
#
# Uso (desde cualquier carpeta; los repos deben estar como carpetas hermanas de autoFix-k8s):
#   ./scripts/build-images.sh                 # solo build
#   ./scripts/build-images.sh --push          # build + push (requiere 'docker login')
#
# Variables opcionales:
#   DOCKERHUB_USER  usuario de Docker Hub (por defecto: francoone)
#   VERSION         etiqueta de version   (por defecto: 1.0.0); siempre se agrega tambien 'latest'
set -euo pipefail

DOCKERHUB_USER="${DOCKERHUB_USER:-francoone}"
VERSION="${VERSION:-1.0.0}"
PUSH=false
[ "${1:-}" = "--push" ] && PUSH=true

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# carpeta del repo -> nombre de la imagen
IMAGES=(
  "autoFix-config-server:autofix-config-server"
  "autoFix-eureka-server:autofix-eureka-server"
  "autoFix-gateway:autofix-gateway"
  "autoFix-ms-vehicles:autofix-ms-vehicles"
  "autoFix-ms-repair-types:autofix-ms-repair-types"
  "autoFix-ms-repair-orders:autofix-ms-repair-orders"
  "autoFix-ms-reports:autofix-ms-reports"
  "autoFix-frontend-eval2:autofix-frontend-eval2"
)

for entry in "${IMAGES[@]}"; do
  dir="${entry%%:*}"
  image="${DOCKERHUB_USER}/${entry##*:}"
  echo "==> ${image}:${VERSION}  (${dir})"
  docker build -t "${image}:${VERSION}" -t "${image}:latest" "${ROOT}/${dir}"
  if [ "${PUSH}" = true ]; then
    docker push "${image}:${VERSION}"
    docker push "${image}:latest"
  fi
done

echo
echo "Imagenes construidas:"
docker images --filter "reference=${DOCKERHUB_USER}/autofix-*" --format '  {{.Repository}}:{{.Tag}}  {{.Size}}' | sort
