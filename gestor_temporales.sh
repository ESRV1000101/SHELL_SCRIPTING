#!/bin/bash

DIR_LOGS_SUITE="/var/log/suite_ti"

FECHA_HORA=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_OPERACION="$DIR_LOGS_SUITE/${FECHA_HORA}_depuracion_temporales.log"
LOG_ERROR_CRITICO="$DIR_LOGS_SUITE/${FECHA_HORA}_ERROR_DEPURACION.log"

REPORT_LIMPIEZA="/home/elias/Reportes/reporte_limpieza.txt"
DIAS_RETENCION=30
MAX_REINTENTOS=3

capturar_error() {
    local comando_fallido="$1"
    echo "==================================================" > "$LOG_ERROR_CRITICO"
    echo "[FALLO CRÍTICO - $FECHA_HORA]" >> "$LOG_ERROR_CRITICO"
    echo "Script: gestor_temporales.sh" >> "$LOG_ERROR_CRITICO"
    echo "Acción fallida: $comando_fallido" >> "$LOG_ERROR_CRITICO"
    echo "==================================================" >> "$LOG_ERROR_CRITICO"
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando escaneo en /var/log, /var/tmp y /tmp..." > "$LOG_OPERACION"

if [ ! -f "$REPORT_LIMPIEZA" ]; then
    echo "==================================================" > "$REPORT_LIMPIEZA"
    echo "       NUEVO REPORTE DE LIMPIEZA DE ARCHIVOS       " >> "$REPORT_LIMPIEZA"
    echo "==================================================" >> "$REPORT_LIMPIEZA"
else
    echo -e "\n--------------------------------------------------" >> "$REPORT_LIMPIEZA"
fi
echo "Fecha de ejecución: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_LIMPIEZA"
echo "--------------------------------------------------" >> "$REPORT_LIMPIEZA"

# BÚSQUEDA MULTI-DIRECTORIO (Protegiendo los logs nuevos de nuestra suite)
ARCHIVOS_A_ELIMINAR=$(find /var/log/suite_ti /var/tmp /tmp -type f \( -name "*.tmp" -o -name "*.log" \) -mtime +$DIAS_RETENCION 2>"$LOG_OPERACION")

if [ $? -ne 0 ]; then
    capturar_error "Búsqueda find en directorios del sistema"
    exit 1
fi

if [ -z "$ARCHIVOS_A_ELIMINAR" ]; then
    echo "[OK] No se encontraron archivos que superen los $DIAS_RETENCION días." >> "$REPORT_LIMPIEZA"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Escaneo finalizado. Sin archivos obsoletos." >> "$LOG_OPERACION"
    exit 0
else
    for archivo in $ARCHIVOS_A_ELIMINAR; do
        intento=1
        borrado_exitoso=false

        while [ $intento -le $MAX_REINTENTOS ] && [ "$borrado_exitoso" = false ]; do
                if [ -f "$archivo" ]; then
                        fecha_modificacion=$(stat -c '%y' "$archivo" | cut -d' ' -f1)
                        rm -f "$archivo" 2>> "$REPORT_LIMPIEZA"
                        if [ $? -eq 0 ]; then
                                echo "[ELIMINADO] $(basename "$archivo") | Modificado por última vez: $fecha_modificacion" >> "$REPORT_LIMPIEZA"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Borrado con éxito: $archivo" >> "$LOG_OPERACION"
                                borrado_exitoso=true
                        else
                                intento=$((intento + 1))
                                capturar_error "No se pudo eliminar el archivo protegido o bloqueado: $archivo"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Imposible borrar $archivo" >> "$LOG_OPERACION"
                        fi
                else
                        borrado_exitoso=true
                fi
        done
    done
fi