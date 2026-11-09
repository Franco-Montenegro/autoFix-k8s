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
