# autoFix-k8s

Despliegue de AutoFix (Evaluacion 2) en Kubernetes (minikube) y scripts de apoyo.

## Imagenes (Docker Hub, usuario `francoone`)

| Imagen | Repo |
|---|---|
| `francoone/autofix-config-server` | autoFix-config-server |
| `francoone/autofix-eureka-server` | autoFix-eureka-server |
| `francoone/autofix-gateway` | autoFix-gateway |
| `francoone/autofix-ms-vehicles` | autoFix-ms-vehicles (M1) |
| `francoone/autofix-ms-repair-types` | autoFix-ms-repair-types (M2) |
| `francoone/autofix-ms-repair-orders` | autoFix-ms-repair-orders (M3) |
| `francoone/autofix-ms-reports` | autoFix-ms-reports (M4) |
| `francoone/autofix-frontend-eval2` | autoFix-frontend-eval2 |

Cada imagen se publica con la etiqueta de version (`1.0.0`) y `latest`.

### Construir y publicar

Los repos deben estar clonados como carpetas hermanas de `autoFix-k8s`. Requiere Docker (y `docker login` para publicar).

```
./scripts/build-images.sh            # solo build
./scripts/build-images.sh --push     # build + push a Docker Hub
VERSION=1.0.1 ./scripts/build-images.sh --push
```

## Despliegue en minikube

Requiere minikube corriendo dentro de una VM. En este equipo se usa el driver Hyper-V
(VirtualBox se congelaba al correr sobre Hyper-V, que Docker Desktop mantiene activo):

```
minikube start --driver=hyperv --hyperv-virtual-switch="Default Switch" --cpus=4 --memory=10240 --disk-size=40g
./scripts/deploy.sh          # despliega todo por etapas y espera cada una
./scripts/undeploy.sh        # elimina todo menos los datos; --all borra tambien los volumenes y el Secret
```

`deploy.sh` toma la IP con `minikube ip` y la inserta en los ConfigMaps del Gateway (CORS) y del frontend (`API_URL`).
La contrasena de las BD se toma de `DB_PASSWORD` o de `.env` (ignorado por git); si no existe, se genera y se guarda ahi.

Acceso desde el navegador del host (sin `port-forward`):

- Frontend: `http://<minikube-ip>:30000`
- API Gateway: `http://<minikube-ip>:30080/api`

### Objetos

| Componente | Objetos | Service |
|---|---|---|
| mysql-vehicles, mysql-repair-types, mysql-repair-orders | Deployment (Recreate), PVC 1 Gi, Secret `autofix-db` | ClusterIP 3306 |
| config-server | Deployment, ConfigMap (URL del config-repo) | ClusterIP 8888 |
| eureka-server | Deployment | ClusterIP 8761 |
| ms-vehicles, ms-repair-types, ms-repair-orders, ms-reports | Deployment, ConfigMap (`SERVER_PORT` 8081-8084, `DB_HOST`) | ClusterIP 8081-8084 |
| gateway | Deployment, ConfigMap (CORS) | **NodePort 30080** |
| frontend | Deployment, ConfigMap (`API_URL`) | **NodePort 30000** |

Los microservicios usan `server.port=${SERVER_PORT:0}`: puerto aleatorio en local y fijo en Kubernetes,
para que cada Service ClusterIP tenga un `targetPort`. El Gateway y las llamadas entre microservicios
siguen resolviendo por Eureka (`lb://...`), que registra la IP del pod con ese puerto.

Cada servicio Spring tiene `startupProbe` (hasta 5 min), `livenessProbe` y `readinessProbe` sobre
`/actuator/health/liveness` y `/readiness`, limite de 512 Mi y la JVM al 75 % de esa memoria.

### Comandos utiles

```
kubectl get pods,svc -o wide
kubectl logs deployment/ms-repair-orders
kubectl describe pod <pod>
kubectl rollout restart deployment/<nombre>   # recargar configuracion del config-repo
```
