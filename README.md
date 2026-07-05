# SHELL_SCRIPTING
Este repositorio contiene tres herramientas en Shell Scripting desarrolladas en Bash para automatizar tareas críticas de administración de TI: monitoreo de hardware, depuración programada de almacenamiento temporal y auditoría de seguridad en tiempo real.

---

## Prerrequisitos:
* Privilegios: Acceso con un usuario del grupo -sudo- para las consultas avanzadas de servicios.

---

## 🚀 Guía de Implementación Paso a Paso

### Paso 1: Copiar los archivos de Script
Copiar los tres archivos al directorio /Scripts:
sistema.sh gestor_temporales.sh reporte_servicios.sh sistema_reportes.sh

### Paso 2: Crear directorio Reportes
Crear el directorio Reportes para que se guarden los resultados de los scripts

### Paso 3: Otorgar permisos de ejecución
Por defecto, Linux crea los archivos sin permisos para ejecutarse como programas binarios. Ejecuta el siguiente comando para asignarle privilegios globales de ejecución al usuario propietario:
chmod 744 sistema.sh gestor_temporales.sh reporte_servicios.sh sistema_reportes.sh

### Paso 4: Automatización de procesos (Crontab)
Para que los scripts, excepto el reporte_servicios.sh porque actua de menú de opciones de nuestro sistema automatizado, se ejecuten de forma autónoma sin intervención del administrador, utilizaremos el planificador de tareas nativo de Linux.

Abre el editor de configuraciones de tareas con sudo para no tener problemas cuando se tengan que ejecutar en segundo plano:
sudo crontab -e

Desplázate hasta el final de la página y pega las siguientes dos líneas de programación (asegúrate de cambiar /home/elias/Scripts/ por la ruta absoluta real donde guardaste tus archivos):
# Limpieza de temporales: Usamos una prueba de 5 minutos para ver como reaccionan los scripts
*/5 * * * * /home/elias/Scripts/gestor_temporales.sh

### Paso 5: Verificación de resultados
Puedes revisar el estado de tus reportes generados en cualquier momento ejecutando el script sistema_reportes.sh como root y revisar los reportes o el reporte general del funcionamiento de la automatización.
