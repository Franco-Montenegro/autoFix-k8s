#!/usr/bin/env bash
# Elimina AutoFix de minikube. Con --all tambien borra los volumenes (datos de las BD).
set -euo pipefail
MANIFESTS="$(cd "$(dirname "$0")/.." && pwd)/manifests"

for f in 09-frontend 08-gateway 07-ms-reports 06-ms-repair-orders 05-ms-repair-types 04-ms-vehicles \
         03-eureka-server 02-config-server; do
  kubectl delete -f "${MANIFESTS}/${f}.yml" --ignore-not-found
done
# MySQL: Deployments y Services; los PVC solo con --all
kubectl delete deployment,service mysql-vehicles mysql-repair-types mysql-repair-orders --ignore-not-found
kubectl delete -f "${MANIFESTS}/00-configmaps.yml" --ignore-not-found
if [ "${1:-}" = "--all" ]; then
  kubectl delete pvc mysql-vehicles mysql-repair-types mysql-repair-orders --ignore-not-found
  kubectl delete secret autofix-db --ignore-not-found
fi
