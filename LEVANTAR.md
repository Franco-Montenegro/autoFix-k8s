# Cómo levantar AutoFix en minikube (paso a paso)

Guía para levantar la aplicación completa desde cero (por ejemplo, después de reiniciar el computador)
y para apagarla. Cada paso dice **qué hacer**, **qué deberías ver** y **qué está pasando**.

Solo se necesita este repo (`autoFix-k8s`): las imágenes se descargan de Docker Hub (`francoone/autofix-*`)
y la configuración la lee el Config Server desde GitHub (`autoFix-config-repo`).

---

## Requisitos (una sola vez)

- Windows con **Hyper-V** activado (lo usa Docker Desktop, así que ya está).
- **minikube** y **kubectl** instalados (`minikube version`, `kubectl version --client`).
- **Git for Windows** (trae el bash con el que se ejecutan los scripts `.sh`).
- Este repo clonado, por ejemplo en `C:\Users\franc\Claude\MIngeSo\AutoFix_Software\autoFix-k8s`.

> **Ojo con `bash`:** en PowerShell, el comando `bash` abre el bash de **WSL** (Ubuntu), donde no están
> `minikube` ni `kubectl`. Los scripts se ejecutan siempre con el bash de Git:
> `& "C:\Program Files\Git\bin\bash.exe" ./scripts/<script>.sh`

---

## Levantar

### Paso 1. Abrir PowerShell como administrador

Menú Inicio → escribir "PowerShell" → clic derecho → **Ejecutar como administrador**.

*Por qué:* minikube usa una VM de **Hyper-V**, y crear, encender o consultar VMs de Hyper-V requiere permisos de administrador.

### Paso 2. Encender la VM de minikube

```powershell
minikube start --driver=hyperv --hyperv-virtual-switch="Default Switch" --cpus=4 --memory=10240 --disk-size=40g
```

Deberías ver, al final: `Done! kubectl is now configured to use "minikube" cluster`. Tarda 1–2 minutos.

*Qué pasa:* se enciende (o se crea, la primera vez) una máquina virtual de Hyper-V con 4 CPU y 10 GB de RAM, y dentro de ella un clúster de Kubernetes de un solo nodo.

Verificar:

```powershell
minikube status        # host, kubelet y apiserver: Running
kubectl get nodes      # minikube   Ready
minikube ip            # ej. 172.20.154.11  <- anótala: es la IP para el navegador
```

### Paso 3. Ir a la carpeta del repo

```powershell
cd C:\Users\franc\Claude\MIngeSo\AutoFix_Software\autoFix-k8s
```

### Paso 4. Desplegar la aplicación

```powershell
& "C:\Program Files\Git\bin\bash.exe" ./scripts/deploy.sh
```

Tarda **1,5 a 3 minutos** (más la primera vez, porque minikube descarga las imágenes de Docker Hub).
Deberías ver las etapas una tras otra, cada una terminando en `successfully rolled out`:

```
==> Secret de las bases de datos
==> ConfigMaps (con la IP de minikube)
==> Bases de datos            -> mysql-vehicles, mysql-repair-types, mysql-repair-orders
==> Config Server
==> Eureka
==> Microservicios M1-M4      -> ms-vehicles, ms-repair-types, ms-repair-orders, ms-reports
==> API Gateway
==> Frontend
...
Frontend: http://<minikube-ip>:30000
Gateway:  http://<minikube-ip>:30080/api
```

*Qué pasa en cada etapa:*

1. **Secret** `autofix-db`: usuario y contraseña de MySQL. La contraseña se toma del archivo `.env` (si no existe, se genera y se guarda ahí; `.env` no se sube a GitHub).
2. **ConfigMaps**: configuración no sensible. El script inserta la IP de minikube en los del Gateway (CORS) y del frontend (`API_URL`).
3. **Bases de datos**: 3 MySQL, cada uno con su volumen (PVC) y su Service.
4. **Config Server**: clona `autoFix-config-repo` desde GitHub. Va antes que el resto porque todos le piden su configuración al arrancar.
5. **Eureka**: el registro de servicios.
6. **M1–M4**: cada uno pide su configuración al Config Server, se conecta a su BD y se registra en Eureka.
7. **Gateway**: único punto de entrada al backend (NodePort 30080).
8. **Frontend**: Nginx con la app React (NodePort 30000).

El script **espera** que cada etapa esté lista (`kubectl rollout status`) antes de seguir con la siguiente.

### Paso 5. Verificar

```powershell
kubectl get pods,svc
```

Deberías ver **11 pods** en `Running` con `1/1`, y solo dos Services `NodePort`: `frontend` (30000) y `gateway` (30080).

### Paso 6. Cargar datos de demostración (opcional)

Con las bases de datos vacías, el historial y los reportes no muestran nada. Este script carga
6 vehículos, 3 bonos y 10 ingresos (agosto a octubre de 2026) **a través del Gateway**:

```powershell
& "C:\Program Files\Git\bin\bash.exe" ./scripts/seed-demo.sh
```

Solo carga datos si no hay vehículos registrados. Al final muestra una verificación de HU4, HU5 y HU6.

### Paso 7. Abrir la aplicación

En el navegador: **`http://<minikube-ip>:30000`** (la IP del paso 2).

Para ver los reportes con datos, elegir **Octubre 2026**.

### Paso 8 (opcional). Mirar el dashboard de Eureka

Eureka es ClusterIP (no se expone fuera del clúster). Solo para mirarlo, en **otra** terminal:

```powershell
kubectl port-forward svc/eureka-server 8761:8761
```

y abrir `http://localhost:8761`. Se detiene con `Ctrl+C`. (El port-forward es solo para mirar; la aplicación se usa siempre por los NodePort.)

---

## Apagar

Hay tres niveles, de menos a más:

| Quiero… | Comando | Qué se conserva |
|---|---|---|
| Pausar (la próxima vez sigue igual) | `minikube stop` | Todo: la app y los datos |
| Quitar la app | `& "C:\Program Files\Git\bin\bash.exe" ./scripts/undeploy.sh` | Los datos de las BD (PVC) |
| Quitar la app **y** los datos | `& "C:\Program Files\Git\bin\bash.exe" ./scripts/undeploy.sh --all`, luego `minikube stop` | Nada (la VM queda apagada) |
| Borrar la VM completa | `minikube delete` | Nada |

Después de `minikube stop`, al volver con `minikube start` los pods se levantan solos (no hace falta `deploy.sh`), **salvo que haya cambiado la IP** (ver abajo). Pueden tardar un par de minutos y algunos reiniciarse una vez mientras el Config Server arranca.

---

## Problemas frecuentes

| Síntoma | Causa y solución |
|---|---|
| `minikube start` pide permisos o falla con Hyper-V | La terminal no es de administrador (paso 1) |
| La app carga pero no muestra datos / error de conexión | Cambió la IP de minikube (pasa al reiniciar Windows). Volver a ejecutar `deploy.sh`: actualiza los ConfigMaps. Luego `kubectl rollout restart deployment/gateway deployment/frontend` |
| `bash: minikube: command not found` | Se usó el bash de WSL. Usar `& "C:\Program Files\Git\bin\bash.exe" ...` |
| Un pod en `CrashLoopBackOff` | `kubectl logs <pod> --previous` muestra por qué se cae al arrancar |
| Un pod en `ImagePullBackOff` | No pudo descargar la imagen: revisar la conexión a internet o el tag |
| Un pod `Running` pero `0/1` | Todavía está arrancando (Java tarda); su readiness aún no responde |
| Un microservicio no conecta a su BD tras redesplegar | La contraseña del Secret cambió y la BD tiene la antigua. No borrar `.env`; si se borró, `undeploy.sh --all` y desplegar de nuevo |

## Comandos útiles

```powershell
kubectl get pods -o wide                      # estado de los pods (y en qué IP)
kubectl logs deployment/ms-repair-orders      # logs de un servicio
kubectl describe pod <pod>                    # eventos del pod (imagen, probes)
kubectl rollout restart deployment/<nombre>   # reiniciar un servicio (ej. tras cambiar el config-repo)
minikube dashboard                            # vista gráfica de Kubernetes
```
