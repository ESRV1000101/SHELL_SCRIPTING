# SHELL_SCRIPTING
Este repositorio contiene tres herramientas en Shell Scripting desarrolladas en Bash para automatizar tareas críticas de administración de TI: monitoreo de hardware, depuración programada de almacenamiento temporal y auditoría de seguridad en tiempo real.

---

## Prerrequisitos:
* Privilegios: Acceso con un usuario del grupo -sudo- para las consultas avanzadas de servicios.

---

## 🚀 Guía de Implementación Paso a Paso

### Paso 1: Copiar los archivos de Script
Copiar los tres archivos ejecutando:
sistema.sh gestor_temporales.sh reporte_servicios.sh

### Paso 2: Otorgar permisos de ejecución
Por defecto, Linux crea los archivos sin permisos para ejecutarse como programas binarios. Ejecuta el siguiente comando para asignarle privilegios globales de ejecución al usuario propietario:
chmod 744 sistema.sh gestor_temporales.sh reporte_servicios.sh

### Paso 3: Automatización de procesos (Crontab)
Para que los scripts 2 y 3 se ejecuten de forma autónoma sin intervención del administrador, utilizaremos el planificador de tareas nativo de Linux.

Abre el editor de configuraciones de tareas:
crontab -e

Desplázate hasta el final de la página y pega las siguientes dos líneas de programación (asegúrate de cambiar /home/elias/ por la ruta absoluta real donde guardaste tus archivos):
# Limpieza de temporales: Todos los Domingos a las 11:31 PM
31 23 * * 0 /home/elias/gestor_temporales.sh

# Reporte de Auditoría de Servicios/Usuarios: Todos los Lunes a las 02:00 AM
00 02 * * 1 /home/elias/reporte_servicios.sh
Guarda los cambios. El demonio de cron aplicará la automatización de forma invisible e inmediata.

### Paso 4: Verificación de resultados
Puedes revisar el estado de tus reportes generados en cualquier momento utilizando el comando de visualización:
cat reporte_sistema.txt
cat reporte_limpieza.txt
cat reporte_servicios.txt
cat reporte_usuarios.txt
