#!/bin/bash

#===============================================================================
# SETEAR VARIABLES
#===============================================================================

# Detecta fallos en cualquier parte de un pipe (no solo el último comando)
set -euo pipefail

DIR_LOGS_SUITE="/var/log/suite_ti"
DIR_REPORTES_BASE="/home/elias/Reportes"
DIR_REPORTES_HISTORICO="$DIR_REPORTES_BASE/historico_sistema"

# Timestamp único para esta ejecución (garantiza archivos nuevos, no sobrescritos)
FECHA_HORA=$(date '+%Y-%m-%d_%H-%M-%S')

LOG_OPERACION="$DIR_LOGS_SUITE/${FECHA_HORA}_monitoreo_sistema.log"
LOG_ERROR_CRITICO="$DIR_LOGS_SUITE/${FECHA_HORA}_ERROR_MONITOREO.log"
REPORT_FILE="$DIR_REPORTES_HISTORICO/reporte_sistema_${FECHA_HORA}.txt"

# Umbral de disco: se puede pasar como primer argumento; por defecto 80
UMBRAL_DISCO=75

#===============================================================================
# FUNCIONES
#===============================================================================

# --- Captura y registro de errores críticos ---
capturar_error() {
    local comando_fallido="$1"
    local destino="$LOG_ERROR_CRITICO"

    {
        echo "=================================================="
        echo "[FALLO CRÍTICO - $FECHA_HORA]"
        echo "Script: sistema.sh"
        echo "Comando que falló: $comando_fallido"
        echo "=================================================="
    } >> "$destino" 2>/dev/null || true

    echo "[ERROR] El comando '$comando_fallido' falló. Detalle registrado en: $destino" >&2
}

# --- Valida que los directorios existan, en todo caso los crea o informa cualquier error
validar_entorno() {
    # Crear directorio de logs si no existe
    if ! mkdir -p "$DIR_LOGS_SUITE" 2>/dev/null; then
        capturar_error "mkdir -p $DIR_LOGS_SUITE (verifica permisos o ejecuta con sudo)"
        exit 1
    fi

    # Crear subcarpeta histórica de reportes si no existe
    if ! mkdir -p "$DIR_REPORTES_HISTORICO" 2>/dev/null; then
        capturar_error "mkdir -p $DIR_REPORTES_HISTORICO"
        exit 1
    fi

    # Validar permisos de escritura
    if [ ! -w "$DIR_LOGS_SUITE" ]; then
        capturar_error "verificación de permisos de escritura en $DIR_LOGS_SUITE"
        exit 1
    fi
    if [ ! -w "$DIR_REPORTES_HISTORICO" ]; then
        capturar_error "verificación de permisos de escritura en $DIR_REPORTES_HISTORICO"
        exit 1
    fi
}

# --- Recolecta las métricas del sistema, validando cada comando crítico ---
recolectar_metricas() {
    USUARIO_SESION=$(who | awk '{print $1}' | head -n 1) || { capturar_error "who"; USUARIO_SESION="N/D"; }
    VERSION_SO=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2) || { capturar_error "grep VERSION_SO"; VERSION_SO="N/D"; }
    IP_LOCAL=$(hostname -I | awk '{print $1}') || { capturar_error "hostname -I"; IP_LOCAL="N/D"; }
    UPTIME_SISTEMA=$(uptime -p) || { capturar_error "uptime -p"; UPTIME_SISTEMA="N/D"; }
    CARGA_CPU=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //') || { capturar_error "uptime carga cpu"; CARGA_CPU="N/D"; }
    TOTAL_PROCESOS=$(ps -ef | wc -l) || { capturar_error "ps -ef"; TOTAL_PROCESOS="N/D"; }

    MEMORIA_LIBRE=$(free -m | grep "Mem" | awk '{print $7}') || { capturar_error "free memoria"; MEMORIA_LIBRE="N/D"; }
    SWAP_USADA=$(free -m | grep "Swap" | awk '{print $3 " MB usados de " $2 " MB totales"}') || { capturar_error "free swap"; SWAP_USADA="N/D"; }

    # Captura de disco con validación estricta (pipefail activo detecta fallos reales del pipe)
    if ! USO_DISCO_PORCENTAJE=$(df / | grep -E '/$' | awk '{print $5}' | sed 's/%//'); then
        capturar_error "df / | grep | awk | sed"
        exit 1
    fi
    if [ -z "$USO_DISCO_PORCENTAJE" ]; then
        capturar_error "df / (resultado vacío)"
        exit 1
    fi

    if ! DISCO_DISPONIBLE=$(df -h / | grep -E '/$' | awk '{print $4}'); then
        capturar_error "df -h / | grep | awk"
        exit 1
    fi
}

# --- Genera el reporte con las métricas recolectadas ---
generar_reporte() {
    {
        echo "=================================================="
        echo "   REPORTE AVANZADO DE SALUD DEL SERVIDOR LINUX   "
        echo "=================================================="
        echo "Fecha de ejecución: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Archivo de log:     $LOG_OPERACION"
        echo "--------------------------------------------------"
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
        echo "Umbral configurado:     ${UMBRAL_DISCO}%"
    } >> "$REPORT_FILE"
}

# --- Evalúa el estado del disco y agrega la alerta correspondiente ---
evaluar_alertas() {
    echo -e "\n--- EVALUACIÓN DE ALERTAS DE TI ---" >> "$REPORT_FILE"

    if [ "$USO_DISCO_PORCENTAJE" -gt "$UMBRAL_DISCO" ]; then
        echo "[ALERTA CRÍTICA] El uso del disco (${USO_DISCO_PORCENTAJE}%) supera el umbral límite del ${UMBRAL_DISCO}%." >> "$REPORT_FILE"
        echo "Estado Final del Servidor: REVISIÓN INMEDIATA REQUERIDA" >> "$REPORT_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERTA: Umbral de almacenamiento sobrepasado." >> "$LOG_OPERACION"
    else
        echo "Estado Final del Servidor: SISTEMA ESTABLE y SALUDABLE" >> "$REPORT_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Análisis terminado. Servidor operando sin anomalías." >> "$LOG_OPERACION"
    fi
}

#===============================================================================
# FLUJO PRINCIPAL
#===============================================================================
main() {
    validar_entorno

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando análisis exhaustivo de hardware y red..." > "$LOG_OPERACION"

    recolectar_metricas
    generar_reporte
    evaluar_alertas

    echo "[OK] Nuevo reporte generado con éxito en: $REPORT_FILE"
    echo "[OK] Log de esta ejecución disponible en:  $LOG_OPERACION"
}

main