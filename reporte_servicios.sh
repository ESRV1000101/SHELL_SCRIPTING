#!/bin/bash

DIR_LOGS_SUITE="/var/log/suite_ti"

FECHA_HORA=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_OPERACION="$DIR_LOGS_SUITE/${FECHA_HORA}_auditoria_seguridad.log"
LOG_ERROR_CRITICO="$DIR_LOGS_SUITE/${FECHA_HORA}_ERROR_AUDITORIA.log"

REP_SERVICIOS="/home/elias/Reportes/reporte_servicios.txt"
REP_USUARIOS="/home/elias/Reportes/reporte_usuarios.txt"

capturar_error() {
    local comando_fallido="$1"
    echo "==================================================" > "$LOG_ERROR_CRITICO"
    echo "[FALLO CRÍTICO - $FECHA_HORA]" >> "$LOG_ERROR_CRITICO"
    echo "Script: reporte_servicios.sh" >> "$LOG_ERROR_CRITICO"
    echo "Comando con error: $comando_fallido" >> "$LOG_ERROR_CRITICO"
    echo "==================================================" >> "$LOG_ERROR_CRITICO"
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generando mapas estructurados de servicios..." > "$LOG_OPERACION"

# --- AUDITORÍA DE SERVICIOS ---
echo "==================================================" > "$REP_SERVICIOS"
echo "       ESTADO ACTUAL DE LOS SERVICIOS Linux       " >> "$REP_SERVICIOS"
echo "==================================================" >> "$REP_SERVICIOS"
echo "Última actualización: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REP_SERVICIOS"
echo "--------------------------------------------------" >> "$REP_SERVICIOS"

TMP_RUNNING="/tmp/srv_running.tmp"
TMP_EXITED="/tmp/srv_exited.tmp"
TMP_FAILED="/tmp/srv_failed.tmp"
TMP_DEAD="/tmp/srv_dead.tmp"

for f in "$TMP_RUNNING" "$TMP_EXITED" "$TMP_FAILED" "$TMP_DEAD"; do
    > "$f"
done

activos=$(systemctl list-units --type=service --all --no-legend | awk '$3 == "active" {count++} END {print count+0}')
inactivos=$(systemctl list-units --type=service --all --no-legend | awk '$3 == "inactive" {count++} END {print count+0}')

if [ $? -ne 0 ]; then
    capturar_error "systemctl list-units con awk filtrado de estado"
    exit 1
fi

echo "[RESUMEN DE CONTROL]" >> "$REP_SERVICIOS"
echo "Servicios ACTIVOS:   $activos" >> "$REP_SERVICIOS"
echo "Servicios INACTIVOS: $inactivos" >> "$REP_SERVICIOS"
echo "--------------------------------------------------" >> "$REP_SERVICIOS"

systemctl list-units --type=service --all --no-legend 2> /dev/null | \
awk -v trun="$TMP_RUNNING" -v texit="$TMP_EXITED" -v tfail="$TMP_FAILED" -v tdead="$TMP_DEAD" '
{
    nombre = $1; est_general = $3; est_detail = $4;
    descripcion = ""
    for(i=5; i<=NF; i++) descripcion = descripcion " " $i
    linea = "Servicio: " nombre " | Estado: [" est_general "/" est_detail "] | Desc:" descripcion

    if (est_detail == "running") print "[OK] " linea >> trun
    else if (est_detail == "exited") print "[OK] " linea >> texit
    else if (est_detail == "failed") print "[CRÍTICO] " linea >> tfail
    else print "[DETENIDO] " linea >> tdead
}'

if [ $? -ne 0 ]; then
    capturar_error "systemctl list-units con awk filtrado de sub-estados"
    exit 1
fi

{
    echo -e "\n[DETALLE: SERVICIOS EN ESTADO SALUDABLE (OK)]"
    echo "--> [SUB-ESTADO: RUNNING]"
    cat "$TMP_RUNNING"
    echo "--> [SUB-ESTADO: EXITED]"
    cat "$TMP_EXITED"
    echo -e "\n[DETALLE: SERVICIOS CON ALERTA O DETENIDOS]"
    echo "--> [SUB-ESTADO: CRÍTICO / FAILED]"
    cat "$TMP_FAILED"
    echo "--> [SUB-ESTADO: DETENIDO / DEAD]"
    cat "$TMP_DEAD"
} >> "$REP_SERVICIOS"

rm -f "$TMP_RUNNING" "$TMP_EXITED" "$TMP_FAILED" "$TMP_DEAD"

# --- AUDITORÍA DE USUARIOS ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Extrayendo información de cuentas reales..." >> "$LOG_OPERACION"

echo "==================================================" > "$REP_USUARIOS"
echo "       AUDITORÍA DE USUARIOS Y PRIVILEGIOS        " >> "$REP_USUARIOS"
echo "==================================================" >> "$REP_USUARIOS"
echo "Última actualización: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REP_USUARIOS"
echo "--------------------------------------------------" >> "$REP_USUARIOS"

usuarios_reales=$(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}')

for usuario in $usuarios_reales; do
    pertenencia_grupos=$(groups "$usuario")
    echo "-> Usuario: $usuario | Permisos (Grupos): $pertenencia_grupos" >> "$REP_USUARIOS"
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auditoría finalizada correctamente." >> "$LOG_OPERACION"
echo "[OK] Reportes de seguridad listos."