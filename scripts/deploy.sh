#!/usr/bin/env bash
# Despliega AutoFix en minikube, por etapas y esperando que cada una este lista:
#   Secret y ConfigMaps -> 3 MySQL -> Config Server -> Eureka -> M1-M4 -> Gateway -> Frontend
#
# Uso: ./scripts/deploy.sh
# La contrasena de las BD se toma de DB_PASSWORD o de autoFix-k8s/.env (ignorado por git);
# si no existe, se genera una al azar y se guarda en .env. Debe ser siempre la misma:
# MySQL solo la fija la primera vez que inicializa su volumen.
set -euo pipefail

K8S_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFESTS="${K8S_DIR}/manifests"
ENV_FILE="${K8S_DIR}/.env"
TIMEOUT=600s

if [ -z "${DB_PASSWORD:-}" ] && [ -f "${ENV_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi
if [ -z "${DB_PASSWORD:-}" ]; then
  DB_PASSWORD="$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
  echo "DB_PASSWORD=${DB_PASSWORD}" > "${ENV_FILE}"
  echo "Contrasena de BD generada y guardada en .env"
fi

MINIKUBE_IP="$(minikube ip)"
echo "minikube ip: ${MINIKUBE_IP}"

step() { echo; echo "==> $*"; }
wait_for() { for d in "$@"; do kubectl rollout status "deployment/$d" --timeout="${TIMEOUT}"; done; }

step "Secret de las bases de datos"
kubectl create secret generic autofix-db \
  --from-literal=username=autofix \
  --from-literal=password="${DB_PASSWORD}" \
  --from-literal=root-password="${DB_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

step "ConfigMaps (con la IP de minikube)"
sed "s/__MINIKUBE_IP__/${MINIKUBE_IP}/g" "${MANIFESTS}/00-configmaps.yml" | kubectl apply -f -

step "Bases de datos"
kubectl apply -f "${MANIFESTS}/01-mysql.yml"
wait_for mysql-vehicles mysql-repair-types mysql-repair-orders

step "Config Server"
kubectl apply -f "${MANIFESTS}/02-config-server.yml"
wait_for config-server

step "Eureka"
kubectl apply -f "${MANIFESTS}/03-eureka-server.yml"
wait_for eureka-server

step "Microservicios M1-M4"
for f in 04-ms-vehicles 05-ms-repair-types 06-ms-repair-orders 07-ms-reports; do
  kubectl apply -f "${MANIFESTS}/${f}.yml"
done
wait_for ms-vehicles ms-repair-types ms-repair-orders ms-reports

step "API Gateway"
kubectl apply -f "${MANIFESTS}/08-gateway.yml"
wait_for gateway

step "Frontend"
kubectl apply -f "${MANIFESTS}/09-frontend.yml"
wait_for frontend

step "Estado"
kubectl get pods,svc -o wide
echo
echo "Frontend: http://${MINIKUBE_IP}:30000"
echo "Gateway:  http://${MINIKUBE_IP}:30080/api"
