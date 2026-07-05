#!/bin/bash

# Directorio central de logs de la suite
DIR_LOGS_SUITE="/var/log/suite_ti"

# Configuración de nombres dinámicos con Fecha y Hora
FECHA_HORA=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_OPERACION="$DIR_LOGS_SUITE/${FECHA_HORA}_monitoreo_sistema.log"
LOG_ERROR_CRITICO="$DIR_LOGS_SUITE/${FECHA_HORA}_ERROR_MONITOREO.log"

REPORT_FILE="/home/elias/Reportes/reporte_sistema.txt"
UMBRAL_DISCO=80

# Función Catch para capturar fallos
capturar_error() {
    local comando_fallido="$1"
    echo "==================================================" > "$LOG_ERROR_CRITICO"
    echo "[FALLO CRÍTICO - $FECHA_HORA]" >> "$LOG_ERROR_CRITICO"
    echo "Script: sistema.sh" >> "$LOG_ERROR_CRITICO"
    echo "Comando que falló: $comando_fallido" >> "$LOG_ERROR_CRITICO"
    echo "==================================================" >> "$LOG_ERROR_CRITICO"
    echo "[ERROR] El comando '$comando_fallido' falló. Detalle en $LOG_ERROR_CRITICO"
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando análisis exhaustivo de hardware y red..." > "$LOG_OPERACION"

echo "==================================================" > $REPORT_FILE
echo "   REPORTE AVANZADO DE SALUD DEL SERVIDOR LINUX   " >> $REPORT_FILE
echo "==================================================" >> $REPORT_FILE
echo "Fecha de ejecución: $(date '+%Y-%m-%d %H:%M:%S')" >> $REPORT_FILE
echo "--------------------------------------------------" >> $REPORT_FILE

# --- RECOLECCIÓN DE INFORMACIÓN MEDIANTE METRICAS AVANZADAS ---
USUARIO_SESION=$(who | awk '{print $1}' | head -n 1)
VERSION_SO=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
IP_LOCAL=$(hostname -I | awk '{print $1}')
UPTIME_SISTEMA=$(uptime -p)
CARGA_CPU=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')
TOTAL_PROCESOS=$(ps -ef | wc -l)

MEMORIA_LIBRE=$(free -m | grep "Mem" | awk '{print $7}')
SWAP_USADA=$(free -m | grep "Swap" | awk '{print $3 " MB usados de " $2 " MB totales"}')

# Captura de disco con validación de error (Catch)
USO_DISCO_PORCENTAJE=$(df / | grep -E '/$' | awk '{print $5}' | sed 's/%//')
if [ $? -ne 0 ] || [ -z "$USO_DISCO_PORCENTAJE" ]; then
    capturar_error "df / | grep"
    exit 1
fi
DISCO_DISPONIBLE=$(df -h / | grep -E '/$' | awk '{print $4}')

# --- VOLCADO DE MÉTRICAS AL REPORTE ---
{
    echo "[INFORMACIÓN GENERAL]"
    echo "Usuario Ejecutor:       $USUARIO_SESION"
    echo "Dirección IP Nodo:      $IP_LOCAL"
    echo "Sistema Operativo:      $VERSION_SO"
    echo "Tiempo de Actividad:    $UPTIME_SISTEMA"
    echo "--------------------------------------------------"
    echo "[RENDIMIENTO DE CPU Y PROCESOS]"
    echo "Carga de CPU (1,5,15m): $CARGA_CPU"
    echo "Procesos en Ejecución:  $TOTAL_PROCESOS"
    echo "--------------------------------------------------"
    echo "[RENDIMIENTO DE MEMORIA]"
    echo "Memoria RAM Libre:      ${MEMORIA_LIBRE} MB"
    echo "Uso de Memoria Swap:    $SWAP_USADA"
    echo "--------------------------------------------------"
    echo "[ALMACENAMIENTO PARTICIÓN RAÍZ]"
    echo "Espacio Disponible (/): $DISCO_DISPONIBLE"
    echo "Porcentaje de Uso (/):  ${USO_DISCO_PORCENTAJE}%"
} >> $REPORT_FILE

echo -e "\n--- EVALUACIÓN DE ALERTAS DE TI ---" >> $REPORT_FILE

if [ "$USO_DISCO_PORCENTAJE" -gt "$UMBRAL_DISCO" ]; then
    echo "[ALERTA CRÍTICA] El uso del disco ($USO_DISCO_PORCENTAJE%) supera el umbral límite del $UMBRAL_DISCO%." >> $REPORT_FILE
    echo "Estado Final del Servidor: REVISIÓN INMEDIATA REQUERIDA" >> $REPORT_FILE
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERTA: Umbral de almacenamiento sobrepasado." >> "$LOG_OPERACION"
else
    echo "Estado Final del Servidor: SISTEMA ESTABLE y SALUDABLE" >> $REPORT_FILE
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Análisis terminado. Servidor operando sin anomalías." >> "$LOG_OPERACION"
fi

echo "[OK] Reporte corporativo actualizado con éxito en: $REPORT_FILE"