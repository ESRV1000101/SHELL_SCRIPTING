#!/bin/bash
#===============================================================================
# Activamos el pipefail para verificar los errores de los comandos en un pipe
set -euo pipefail

#===============================================================================
# CONFIGURACIÓN GENERAL
#===============================================================================

DIR_LOGS_SUITE="/var/log/suite_ti"
DIR_REPORTES="/home/elias/Reportes"
DIR_REPORTES_HISTORICO="$DIR_REPORTES/historico_gestor"

FECHA_HORA=$(date '+%Y-%m-%d_%H-%M-%S')
REPORT_GESTION="$DIR_REPORTES_HISTORICO/reporte_gestion_archivos_${FECHA_HORA}.txt"
LOG_OPERACION="$DIR_LOGS_SUITE/${FECHA_HORA}_gestor_archivos.log"
LOG_ERROR_CRITICO="$DIR_LOGS_SUITE/${FECHA_HORA}_ERROR_GESTOR.log"

# Carpeta de backup del día (una subcarpeta distinta por cada fecha de ejecución)
DIR_BACKUP_BASE="/home/elias/Backups"
DIR_BACKUP_HOY="$DIR_BACKUP_BASE/$(date '+%Y-%m-%d')"

# Archivos críticos de configuración que se respaldan en cada ejecución.
# Se pueden agregar o quitar rutas según lo que necesite el servidor.
ARCHIVOS_BACKUP=(
    "/etc/hostname"
    "/etc/os-release"
    "/etc/fstab"
    "/etc/crontab"
)

# Permisos que se aplican al backup, ya que puede contener configuración sensible
PERMISOS_DIR_BACKUP="700"
PERMISOS_ARCHIVOS_BACKUP="600"

DIAS_RETENCION="30"
MAX_REINTENTOS=3
SEGUNDOS_ENTRE_REINTENTOS=2

#===============================================================================
# FUNCIONES DE UTILIDAD (log, errores, validaciones, reporte)
#===============================================================================

registrar_operacion() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_OPERACION"
}

# --- Captura y registra errores críticos, con respaldo si el log principal no está disponible ---
capturar_error() {
    local descripcion="$1"
    local destino="$LOG_ERROR_CRITICO"

    {
        echo "=================================================="
        echo "[FALLO CRÍTICO - $(date '+%Y-%m-%d %H:%M:%S')]"
        echo "Script: gestor_archivos.sh"
        echo "Acción fallida: $descripcion"
        echo "=================================================="
    } >> "$destino" 2>/dev/null || true

    echo "[ERROR] $descripcion. Detalle registrado en: $destino" >&2
}

validar_entorno() {
    if ! mkdir -p "$DIR_LOGS_SUITE" 2>/dev/null; then
        capturar_error "No se pudo crear el directorio de logs: $DIR_LOGS_SUITE (verifica permisos o usa sudo)"
        exit 1
    fi
    if [ ! -w "$DIR_LOGS_SUITE" ]; then
        capturar_error "Sin permisos de escritura en $DIR_LOGS_SUITE"
        exit 1
    fi
    if ! mkdir -p "$DIR_REPORTES_HISTORICO" 2>/dev/null; then
        capturar_error "No se pudo crear el directorio de reportes: $DIR_REPORTES_HISTORICO"
        exit 1
    fi
    if ! [[ "$DIAS_RETENCION" =~ ^[0-9]+$ ]]; then
        capturar_error "Días de retención inválidos: '$DIAS_RETENCION' (debe ser un entero)"
        exit 1
    fi
}

# --- Agrega una sección al reporte legible, con encabezado si es la primera vez ---
escribir_reporte() {
    local titulo="$1"
    local cuerpo="$2"

    if [ ! -f "$REPORT_GESTION" ]; then
        {
            echo "=================================================="
            echo "     REPORTE DE GESTIÓN DE ARCHIVOS Y PERMISOS     "
            echo "=================================================="
        } >> "$REPORT_GESTION"
    else
        echo -e "\n--------------------------------------------------" >> "$REPORT_GESTION"
    fi

    {
        echo "Fecha de ejecución: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Acción: $titulo"
        echo "--------------------------------------------------"
        echo -e "$cuerpo"
    } >> "$REPORT_GESTION"
}

#===============================================================================
# CREAR ESTRUCTURA DE BACKUP
#===============================================================================
crear_estructura_backup() {
    if [ -d "$DIR_BACKUP_HOY" ]; then
        registrar_operacion "La carpeta de backup de hoy ya existía: $DIR_BACKUP_HOY"
        echo "[INFO] Carpeta de backup ya existente: $DIR_BACKUP_HOY"
        return 0
    fi

    if mkdir -p "$DIR_BACKUP_HOY" 2>/dev/null; then
        registrar_operacion "Carpeta de backup creada: $DIR_BACKUP_HOY"
        echo "[OK] Carpeta de backup creada: $DIR_BACKUP_HOY"
        return 0
    else
        capturar_error "No se pudo crear la carpeta de backup: $DIR_BACKUP_HOY"
        escribir_reporte "Creación de estructura" "[FALLÓ] No se pudo crear $DIR_BACKUP_HOY"
        return 1
    fi
}

#===============================================================================
# COPIAR ARCHIVOS CRÍTICOS PARA BACKUP
#===============================================================================
copiar_archivos_backup() {
    local total_copiados=0
    local total_omitidos=0
    local detalle=""

    for archivo in "${ARCHIVOS_BACKUP[@]}"; do
        if [ ! -e "$archivo" ]; then
            detalle+="[OMITIDO] $archivo (no existe en este servidor)\n"
            registrar_operacion "Omitido en backup, no existe: $archivo"
            total_omitidos=$((total_omitidos + 1))
            continue
        fi

        if cp -p "$archivo" "$DIR_BACKUP_HOY/" 2>>"$LOG_OPERACION"; then
            detalle+="[COPIADO] $archivo -> $DIR_BACKUP_HOY/\n"
            registrar_operacion "Copiado a backup: $archivo"
            total_copiados=$((total_copiados + 1))
        else
            capturar_error "No se pudo copiar al backup: $archivo (verifica permisos de lectura)"
            detalle+="[FALLÓ] $archivo\n"
        fi
    done

    detalle+="\nResumen: $total_copiados copiados, $total_omitidos omitidos de ${#ARCHIVOS_BACKUP[@]} archivos definidos."
    escribir_reporte "Copia de archivos críticos a backup" "$detalle"
    echo "[OK] Backup de archivos: $total_copiados copiados, $total_omitidos omitidos."
}

#===============================================================================
# ASIGNAR PERMISOS AL BACKUP RECIÉN CREADO
#===============================================================================
aplicar_permisos_backup() {
    local detalle=""

    if chmod "$PERMISOS_DIR_BACKUP" "$DIR_BACKUP_HOY" 2>/dev/null; then
        detalle+="Directorio $DIR_BACKUP_HOY -> permisos $PERMISOS_DIR_BACKUP\n"
        registrar_operacion "Permisos $PERMISOS_DIR_BACKUP aplicados a $DIR_BACKUP_HOY"
    else
        capturar_error "No se pudieron aplicar permisos $PERMISOS_DIR_BACKUP a $DIR_BACKUP_HOY"
        detalle+="[FALLÓ] No se pudo asignar permisos a $DIR_BACKUP_HOY\n"
    fi

    # Aplica permisos restrictivos a cada archivo copiado, ya que puede
    # contener configuración sensible del servidor.
    local archivo_bkp
    for archivo_bkp in "$DIR_BACKUP_HOY"/*; do
        [ -e "$archivo_bkp" ] || continue
        if chmod "$PERMISOS_ARCHIVOS_BACKUP" "$archivo_bkp" 2>/dev/null; then
            detalle+="Archivo $(basename "$archivo_bkp") -> permisos $PERMISOS_ARCHIVOS_BACKUP\n"
        else
            capturar_error "No se pudieron aplicar permisos a $archivo_bkp"
            detalle+="[FALLÓ] $(basename "$archivo_bkp")\n"
        fi
    done

    escribir_reporte "Asignación de permisos al backup" "$detalle"
    echo "[OK] Permisos aplicados a la carpeta y archivos de backup."
}

#===============================================================================
# LIMPIAR ARCHIVOS TEMPORALES Y LOGS ANTIGUOS
#===============================================================================
limpiar_temporales() {
    registrar_operacion "Iniciando escaneo en /var/log, /var/tmp y /tmp (retención: ${DIAS_RETENCION} días)..."

    # Búsqueda multi-directorio. mtime +N filtra por antigüedad, así que los
    # logs de esta misma ejecución (recién creados) nunca son candidatos.
    local archivos_encontrados
    if ! archivos_encontrados=$(find /var/log/suite_ti /var/tmp /tmp "$DIR_REPORTES" -type f \
            \( -name "*.tmp" -o -name "*.log" -o -name "*.txt" \) -mtime +"$DIAS_RETENCION" 2>>"$LOG_OPERACION"); then
        capturar_error "Falló la búsqueda 'find' en los directorios del sistema"
        exit 1
    fi

    if [ -z "$archivos_encontrados" ]; then
        echo "[OK] No se encontraron archivos temporales/log que superen los ${DIAS_RETENCION} días."
        escribir_reporte "Limpieza de temporales" "No se encontraron archivos que superen los ${DIAS_RETENCION} días."
        registrar_operacion "Escaneo finalizado. Sin archivos obsoletos."
        return 0
    fi

    local total_eliminados=0
    local total_fallidos=0
    local detalle=""

    # 'while read' en vez de 'for' para soportar nombres de archivo con espacios.
    while IFS= read -r archivo; do
        [ -z "$archivo" ] && continue

        local intento=1
        local borrado_exitoso=false

        while [ "$intento" -le "$MAX_REINTENTOS" ] && [ "$borrado_exitoso" = false ]; do
            if [ ! -f "$archivo" ]; then
                borrado_exitoso=true
                break
            fi

            local fecha_modificacion
            fecha_modificacion=$(stat -c '%y' "$archivo" | cut -d' ' -f1)

            if rm -f "$archivo" 2>>"$LOG_OPERACION"; then
                detalle+="[ELIMINADO] $(basename "$archivo") | Modificado por última vez: $fecha_modificacion\n"
                registrar_operacion "Borrado con éxito (intento $intento): $archivo"
                borrado_exitoso=true
                total_eliminados=$((total_eliminados + 1))
            else
                capturar_error "No se pudo eliminar el archivo protegido o bloqueado (intento $intento/$MAX_REINTENTOS): $archivo"
                registrar_operacion "ERROR al borrar (intento $intento/$MAX_REINTENTOS): $archivo"
                intento=$((intento + 1))
                [ "$intento" -le "$MAX_REINTENTOS" ] && sleep "$SEGUNDOS_ENTRE_REINTENTOS"
            fi
        done

        if [ "$borrado_exitoso" = false ]; then
            detalle+="[NO ELIMINADO] $(basename "$archivo") | Se agotaron los $MAX_REINTENTOS reintentos\n"
            total_fallidos=$((total_fallidos + 1))
        fi
    done <<< "$archivos_encontrados"

    detalle+="\n--- RESUMEN ---\nArchivos eliminados: $total_eliminados\nArchivos no eliminados: $total_fallidos\n"

    escribir_reporte "Limpieza de temporales (retención: ${DIAS_RETENCION} días)" "$detalle"
    registrar_operacion "Escaneo finalizado. Eliminados: $total_eliminados | Fallidos: $total_fallidos"
    echo "[OK] Limpieza finalizada. Eliminados: $total_eliminados | Fallidos: $total_fallidos"
}

#===============================================================================
# FLUJO PRINCIPAL
#===============================================================================
main() {
    validar_entorno
    registrar_operacion "Iniciando rutina de gestión de archivos y permisos..."

    # se verifica si funciona las funciones para backups
    if crear_estructura_backup; then
        copiar_archivos_backup
        aplicar_permisos_backup
    else
        capturar_error "Se omitieron 'copiar_archivos_backup' y 'aplicar_permisos_backup' porque no se pudo preparar la carpeta de backup"
    fi

    # limpiar_temporales es independiente de las funciones de backup: se
    # ejecuta siempre, incluso si crear/copiar/permisos fallaron arriba.
    limpiar_temporales

    registrar_operacion "Rutina de gestión de archivos finalizada."
    echo "[OK] Rutina completa. Reporte disponible en: $REPORT_GESTION"
    echo "[OK] Log de esta ejecución disponible en:  $LOG_OPERACION"
}

# Se ejecuta la funcion principal
main