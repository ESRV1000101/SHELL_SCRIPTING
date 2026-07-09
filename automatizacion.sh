#!/bin/bash

set -euo pipefail

#===============================================================================
# CONFIGURACIÓN GENERAL
#===============================================================================

DIR_LOGS_SUITE="/var/log/suite_ti"
DIR_REPORTES="/home/elias/Reportes"

# Carpeta donde vive este propio script: ahí se buscan los candidatos a programar.
DIR_SCRIPT_ACTUAL="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

FECHA_HORA=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_OPERACION="$DIR_LOGS_SUITE/${FECHA_HORA}_automatizacion.log"
LOG_ERROR_CRITICO="$DIR_LOGS_SUITE/${FECHA_HORA}_ERROR_AUTOMATIZACION.log"

# --- Configuración de la tarea CRON (se completa en seleccionar_script_a_programar) ---
EXPRESION_CRON="0 2 * * *"   # Todos los días a las 2:00 a.m.
RESPALDO_CRONTAB="$DIR_LOGS_SUITE/${FECHA_HORA}_crontab_respaldo.bak"
SCRIPT_A_PROGRAMAR=""
LINEA_CRON=""

# --- Configuración del reporte AWK (histórico: un reporte nuevo por ejecución) ---
DIR_REPORTES_HISTORICO="$DIR_REPORTES/historico_automatizacion"
REPORTE_CONSOLIDADO="$DIR_REPORTES_HISTORICO/reporte_consolidado_automatizacion_${FECHA_HORA}.txt"

#===============================================================================
# FUNCIONES DE UTILIDAD (log, errores, validaciones)
#===============================================================================

registrar_operacion() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_OPERACION"
}

# Requiere que $DIR_LOGS_SUITE ya exista (lo garantiza validar_entorno antes
# de que se llame a esta función en cualquier otro punto del script).
capturar_error() {
    local descripcion="$1"
    {
        echo "=================================================="
        echo "[FALLO CRÍTICO - $(date '+%Y-%m-%d %H:%M:%S')]"
        echo "Script: automatizacion.sh"
        echo "Acción fallida: $descripcion"
        echo "=================================================="
    } >> "$LOG_ERROR_CRITICO" 2>/dev/null || true

    echo "[ERROR] $descripcion. Detalle registrado en: $LOG_ERROR_CRITICO" >&2
}

validar_entorno() {
    if ! mkdir -p "$DIR_LOGS_SUITE" 2>/dev/null; then
        echo "[ERROR] No se pudo crear el directorio de logs: $DIR_LOGS_SUITE (verifica permisos o usa sudo)" >&2
        exit 1
    fi
    if [ ! -w "$DIR_LOGS_SUITE" ]; then
        echo "[ERROR] Sin permisos de escritura en $DIR_LOGS_SUITE" >&2
        exit 1
    fi
    if ! mkdir -p "$DIR_REPORTES_HISTORICO" 2>/dev/null; then
        capturar_error "No se pudo crear el directorio de reportes: $DIR_REPORTES_HISTORICO"
        exit 1
    fi
}

#===============================================================================
# ELEGIR QUÉ SCRIPT SE VA A PROGRAMAR EN CRON
#===============================================================================
seleccionar_script_a_programar() {
    local scripts_disponibles=()
    while IFS= read -r -d '' archivo; do
        scripts_disponibles+=("$archivo")
    done < <(find "$DIR_SCRIPT_ACTUAL" -maxdepth 1 -type f -name "*.sh" \
                ! -name "$(basename "${BASH_SOURCE[0]:-$0}")" -print0 | sort -z)

    if [ "${#scripts_disponibles[@]}" -eq 0 ]; then
        capturar_error "No se encontraron scripts .sh en $DIR_SCRIPT_ACTUAL para programar"
        return 1
    fi

    local elegido=""

    echo ""
    echo "Scripts disponibles en $DIR_SCRIPT_ACTUAL:"
    local PS3="Selecciona el número del script a programar en cron: "
    select opcion in "${scripts_disponibles[@]}"; do
        if [ -n "$opcion" ]; then
            elegido="$opcion"
            break
        fi
        echo "Opción inválida, intenta de nuevo."
    done

    SCRIPT_A_PROGRAMAR="$elegido"
    local nombre_script
    nombre_script="$(basename "$SCRIPT_A_PROGRAMAR")"
    local log_salida_cron="$DIR_LOGS_SUITE/cron_${nombre_script%.sh}.log"
    LINEA_CRON="$EXPRESION_CRON /bin/bash $SCRIPT_A_PROGRAMAR >> $log_salida_cron 2>&1"

    echo "[INFO] Script seleccionado para automatizar: $SCRIPT_A_PROGRAMAR"
    registrar_operacion "Script seleccionado para cron: $SCRIPT_A_PROGRAMAR"
}

#===============================================================================
# PROGRAMAR TAREA EN CRON
#===============================================================================
programar_cron() {
    if ! command -v crontab >/dev/null 2>&1; then
        capturar_error "El comando 'crontab' no está disponible en este sistema. Instala el paquete 'cron'/'cronie'."
        return 1
    fi

    local crontab_actual
    crontab_actual=$(crontab -l 2>/dev/null || true)

    # Idempotencia: si ese script ya está programado, no se duplica.
    if echo "$crontab_actual" | grep -Fq "$SCRIPT_A_PROGRAMAR"; then
        echo "[INFO] La tarea cron para $SCRIPT_A_PROGRAMAR ya estaba programada. No se duplica."
        registrar_operacion "Tarea cron ya existente, sin cambios."
        return 0
    fi

    # Respaldo del crontab previo antes de modificarlo.
    echo "$crontab_actual" > "$RESPALDO_CRONTAB" 2>/dev/null || true

    if { echo "$crontab_actual"; echo "$LINEA_CRON"; } | crontab - 2>/dev/null; then
        echo "[OK] Tarea cron programada: se ejecutará '$SCRIPT_A_PROGRAMAR' todos los días a las 2:00 a.m."
        registrar_operacion "Tarea cron agregada: $LINEA_CRON"
    else
        capturar_error "No se pudo instalar la tarea cron (verifica permisos de crontab del usuario)"
        return 1
    fi
}

#===============================================================================
# GENERAR REPORTE CONSOLIDADO
#===============================================================================
generar_reporte() {
    local archivos_log=()
    while IFS= read -r -d '' archivo; do
        archivos_log+=("$archivo")
    done < <(find "$DIR_LOGS_SUITE" -maxdepth 1 -type f -name "*.log" -print0 2>/dev/null)

    if [ "${#archivos_log[@]}" -eq 0 ]; then
        echo "[INFO] No hay logs previos en $DIR_LOGS_SUITE todavía para consolidar."
        registrar_operacion "Sin logs disponibles para el reporte."
        return 0
    fi

    # AWK recorre todos los logs de la suite y calcula:
    {
        echo "=================================================="
        echo "   REPORTE CONSOLIDADO DE AUTOMATIZACIÓN          "
        echo "=================================================="
        echo "Generado el: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Archivos de log analizados: ${#archivos_log[@]}"
        echo "--------------------------------------------------"
        awk '
            /Iniciando/ { ejecuciones++ }
            /ALERTA/    { alertas++ }
            { ultima_linea = $0 }
            END {
                print "Ejecuciones registradas: " (ejecuciones + 0)
                print "Alertas detectadas:       " (alertas + 0)
                print "Última línea registrada:  " ultima_linea
            }
        ' "${archivos_log[@]}"
        echo "--------------------------------------------------"
    } > "$REPORTE_CONSOLIDADO" 2>>"$LOG_OPERACION"

    if [ -s "$REPORTE_CONSOLIDADO" ]; then
        echo "[OK] Reporte consolidado generado en: $REPORTE_CONSOLIDADO"
        registrar_operacion "Reporte awk generado a partir de ${#archivos_log[@]} archivos de log."
    else
        capturar_error "El reporte consolidado quedó vacío tras ejecutar awk"
        return 1
    fi
}

#===============================================================================
# FLUJO PRINCIPAL
#===============================================================================
main() {
    validar_entorno
    registrar_operacion "Iniciando automatización (cron + awk)..."

    if seleccionar_script_a_programar; then
        programar_cron || capturar_error "Paso de cron finalizado con errores (ver detalle arriba)"
    else
        capturar_error "No se programó ninguna tarea cron: no se seleccionó un script válido"
    fi

    generar_reporte || capturar_error "Paso de awk finalizado con errores (ver detalle arriba)"

    registrar_operacion "Automatización finalizada."
    echo "[OK] Automatización completa. Log de esta ejecución: $LOG_OPERACION"
}

main