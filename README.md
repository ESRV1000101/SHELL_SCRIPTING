Suite de Automatización de Administración de Sistemas Linux

Conjunto de scripts en Bash para automatizar tareas básicas de administración de servidores Linux: monitoreo del sistema, gestión de archivos y permisos, backups, limpieza de temporales, y automatización con cron y awk.

Proyecto desarrollado para la Unidad Didáctica de Shell Scripting.


📁 Estructura del repositorio

Los scripts generan, además, estas carpetas en el servidor (se crean solas en la primera ejecución):

/var/log/suite_ti/                       # Logs de operación y de error de cada ejecución
/home/elias/Reportes/
    historico_sistema/                   # Reportes de sistema.sh (uno por ejecución)
    historico_gestor/                    # Reportes de gestor_archivos.sh (uno por ejecución)
    historico_automatizacion/            # Reportes de automatizacion.sh (uno por ejecución)
/home/elias/Backups/<fecha>/             # Backups diarios generados por gestor_archivos.sh


Importante: las rutas /home/elias/Reportes y /home/elias/Backups están definidas como variables al inicio de cada script (DIR_REPORTES, DIR_BACKUP_BASE). Si tu usuario no se llama elias, edita esas líneas antes de ejecutar.


⚠️ Requisito obligatorio: ejecutar todo con sudo

Todos los scripts de esta suite deben ejecutarse con sudo. Esto es necesario porque:


Escriben logs en /var/log/suite_ti/ (carpeta del sistema, fuera del home del usuario).
gestor_archivos.sh respalda archivos de /etc/ (hostname, os-release, fstab, crontab), que solo root puede leer sin restricciones.
automatizacion.sh modifica el crontab del usuario que ejecuta el script.


Si ejecutas cualquier script sin sudo, es probable que falle al crear /var/log/suite_ti/ o al leer algún archivo de /etc/, y el error quedará registrado en el log correspondiente.

bashsudo ./sistema.sh
sudo ./gestor_archivos.sh
sudo ./automatizacion.sh
sudo ./menu.sh


🔧 Instalación / Preparación


Clona el repositorio en el servidor Linux:


bash   git clone <URL-del-repositorio> suite-ti
   cd suite-ti


Da permisos de ejecución a los 4 scripts:


bash   sudo chmod +x sistema.sh gestor_archivos.sh automatizacion.sh menu.sh


Verifica que tengas instalados los paquetes necesarios (normalmente ya vienen en Ubuntu/Debian):


bash   sudo apt update
   sudo apt install -y cron gawk


(Opcional) Ajusta las rutas de DIR_REPORTES y DIR_BACKUP_BASE en sistema.sh y gestor_archivos.sh si tu usuario no es elias.



1️⃣ sistema.sh — Script de entorno del sistema

Qué hace: recolecta y reporta el estado del servidor (usuario, IP, sistema operativo, uptime, CPU, memoria, uso de disco) y evalúa si el uso de disco supera un umbral, generando una alerta.

Uso

bashsudo ./sistema.sh [umbral_disco]

ParámetroObligatorioDescripciónValor por defectoumbral_discoNoPorcentaje de uso de disco a partir del cual se genera una alerta crítica80

Ejemplos

bashsudo ./sistema.sh          # Usa el umbral por defecto (80%)
sudo ./sistema.sh 90       # Genera alerta solo si el disco supera el 90%

Salida


Reporte nuevo en /home/elias/Reportes/historico_sistema/reporte_sistema_<fecha_hora>.txt (uno distinto por cada ejecución, para poder comparar).
Log de operación en /var/log/suite_ti/<fecha_hora>_monitoreo_sistema.log.
Si algo falla, log de error en /var/log/suite_ti/<fecha_hora>_ERROR_MONITOREO.log.



2️⃣ gestor_archivos.sh — Gestión de archivos, permisos y backup

Qué hace: en una sola ejecución automatiza 4 acciones:


Crea la carpeta de backup del día (/home/elias/Backups/<fecha-de-hoy>/).
Copia archivos críticos de configuración (/etc/hostname, /etc/os-release, /etc/fstab, /etc/crontab) a esa carpeta.
Aplica permisos restrictivos al backup (700 a la carpeta, 600 a los archivos, por seguridad).
Limpia archivos .tmp, .log y .txt antiguos en /var/log, /var/tmp, /tmp y en la carpeta de Reportes (incluyendo sus subcarpetas históricas).


Uso

bashsudo ./gestor_archivos.sh [dias_retencion]

ParámetroObligatorioDescripciónValor por defectodias_retencionNoAntigüedad (en días) a partir de la cual un archivo temporal/log/reporte se elimina30

Ejemplos

bashsudo ./gestor_archivos.sh          # Retención por defecto (30 días)
sudo ./gestor_archivos.sh 15       # Elimina archivos con más de 15 días

Salida


Reporte nuevo en /home/elias/Reportes/historico_gestor/reporte_gestion_archivos_<fecha_hora>.txt.
Backup del día en /home/elias/Backups/<fecha>/.
Log de operación en /var/log/suite_ti/<fecha_hora>_gestor_archivos.log.
Si algo falla, log de error en /var/log/suite_ti/<fecha_hora>_ERROR_GESTOR.log.



Nota: si la creación del backup falla (por ejemplo, por permisos), la limpieza de temporales se ejecuta igual — son pasos independientes.




3️⃣ automatizacion.sh — Automatización con cron y awk

Qué hace:


Muestra un menú con los demás scripts .sh de la carpeta y programa en cron la ejecución diaria (2:00 a.m.) del que elijas — sin duplicar la tarea si ya estaba programada.
Genera un reporte consolidado analizando con awk todos los logs de operación que ha generado la suite (ejecuciones totales, alertas detectadas, última actividad).


Uso

bashsudo ./automatizacion.sh

No recibe parámetros — siempre te mostrará el menú para elegir qué script programar:

Scripts disponibles en /ruta/a/suite-ti:
1) gestor_archivos.sh
2) sistema.sh
Selecciona el número del script a programar en cron:

Salida


Tarea agregada al crontab de root (ya que se ejecuta con sudo). Verifícalo con:


bash  sudo crontab -l


Respaldo del crontab anterior en /var/log/suite_ti/<fecha_hora>_crontab_respaldo.bak.
Reporte nuevo en /home/elias/Reportes/historico_automatizacion/reporte_consolidado_automatizacion_<fecha_hora>.txt.
Log de operación en /var/log/suite_ti/<fecha_hora>_automatizacion.log.



Importante: como se ejecuta con sudo, la tarea se programa en el crontab de root, no en el de tu usuario normal. Esto es intencional: así la tarea programada también tendrá permisos para escribir en /var/log/suite_ti/ y leer archivos de /etc/ cuando se ejecute automáticamente de madrugada.




4️⃣ menu.sh — Panel central de la suite

Qué hace: punto de entrada único e interactivo para no tener que recordar los comandos anteriores. Permite:


Ejecutar cualquier script de la carpeta.
Ver el contenido de cualquier reporte generado (incluye los de las subcarpetas históricas).
Ver un resumen general: cuántos scripts hay, cuáles están programados en cron, cuántos reportes/logs existen, y la fecha de la última ejecución.
Salir.


Uso

bashsudo ./menu.sh

========== MENÚ PRINCIPAL - SUITE DE TI ==========
1) Ejecutar un script
2) Ver un reporte
3) Resumen general de la suite
4) Salir
Elige una opción:

En los submenús, puedes escribir el número de la opción o la palabra volver (en cualquier combinación de mayúsculas/minúsculas) para regresar al menú principal.


🔁 Flujo de trabajo recomendado

bash# 1. Primera vez: preparar el entorno
sudo chmod +x sistema.sh gestor_archivos.sh automatizacion.sh menu.sh

# 2. Ejecutar el diagnóstico del sistema
sudo ./sistema.sh

# 3. Ejecutar la gestión de archivos y backup
sudo ./gestor_archivos.sh

# 4. Programar la automatización diaria (elige uno o ambos scripts en el menú)
sudo ./automatizacion.sh

# 5. Desde ahora, usar el menú para todo lo demás
sudo ./menu.sh


🐞 Problemas conocidos y soluciones aplicadas

ProblemaSolución aplicadaNombres de archivo con espacios se cortaban al limpiar temporalesSe reemplazó for archivo in $lista por while IFS= read -rLos logs de error se sobrescribían en cada ejecuciónSe cambió la redirección de > a >> en capturar_error()Los reportes se sobrescribían entre ejecucionesCada reporte ahora incluye la fecha y hora exacta en el nombre del archivo, dentro de una carpeta historico_<script>/Un fallo en el backup detenía toda la limpieza de temporalesSe separó la lógica para que limpiar_temporales se ejecute siempre, sin depender de los demás pasosEl menú se quedaba en bucle si la entrada terminaba inesperadamente (EOF)Se agregó manejo explícito de fin de entrada para salir limpiamente
