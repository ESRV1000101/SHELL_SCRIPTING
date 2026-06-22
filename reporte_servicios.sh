#!/bin/bash

# ==============================================================================
# Generar reportes en tiempo real de servicios y usuarios
# ==============================================================================

REP_SERVICIOS="reporte_servicios.txt"
REP_USUARIOS="reporte_usuarios.txt"

# --- AUDITORÍA DE SERVICIOS ---
auditar_servicios() {
    echo "[-] Analizando servicios del sistema..."

    echo "==================================================" > "$REP_SERVICIOS"
    echo "       ESTADO ACTUAL DE LOS SERVICIOS Linux       " >> "$REP_SERVICIOS"
    echo "==================================================" >> "$REP_SERVICIOS"
    echo "Última actualización: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REP_SERVICIOS"
    echo "--------------------------------------------------" >> "$REP_SERVICIOS"

    # Definimos los 4 archivos temporales por cada sub-estado
    local TMP_RUNNING="/tmp/srv_running.tmp"
    local TMP_EXITED="/tmp/srv_exited.tmp"
    local TMP_FAILED="/tmp/srv_failed.tmp"
    local TMP_DEAD="/tmp/srv_dead.tmp"

    # Asegurar existencia o limpiar temporales
    for f in "$TMP_RUNNING" "$TMP_EXITED" "$TMP_FAILED" "$TMP_DEAD"; do
        if [ ! -f "$f" ]; then > "$f"; else > "$f"; fi
    done

    # Conteo rápido de estados
    local activos=$(systemctl list-units --type=service --all --no-legend | awk '$3 == "active" {count++} END {print count+0}')
    local inactivos=$(systemctl list-units --type=service --all --no-legend | awk '$3 == "inactive" {count++} END {print count+0}')

    # Insertamos el resumen numérico
    echo "[RESUMEN DE CONTROL]" >> "$REP_SERVICIOS"
    echo "Servicios ACTIVOS:   $activos" >> "$REP_SERVICIOS"
    echo "Servicios INACTIVOS: $inactivos" >> "$REP_SERVICIOS"
    echo "--------------------------------------------------" >> "$REP_SERVICIOS"

    # Clasificación detallada e inyección en los 4 temporales usando AWK
    systemctl list-units --type=service --all --no-legend | awk -v trun="$TMP_RUNNING" -v texit="$TMP_EXITED" -v tfail="$TMP_FAILED" -v tdead="$TMP_DEAD" '{
        nombre = $1
        est_general = $3
        est_detalle = $4

        descripcion = ""
        for(i=5; i<=NF; i++) descripcion = descripcion " " $i

        linea = "Servicio: " nombre " | Estado: [" est_general "/" est_detalle "] | Desc:" descripcion

        # Clasificación estricta por sub-estado
        if (est_detalle == "running") {
            print "[OK] " linea >> trun
        } else if (est_detalle == "exited") {
            print "[OK] " linea >> texit
        } else if (est_detalle == "failed") {
            print "[CRÍTICO] " linea >> tfail
        } else {
            print "[DETENIDO] " linea >> tdead
        }
    }'

    # --- VOLCADO AL REPORTE FINAL ---
    # Servicios Activos
    echo -e "\n[DETALLE: SERVICIOS EN ESTADO SALUDABLE (OK)]" >> "$REP_SERVICIOS"
    echo "--> [SUB-ESTADO: RUNNING]" >> "$REP_SERVICIOS"
    cat "$TMP_RUNNING" >> "$REP_SERVICIOS"
    echo "--> [SUB-ESTADO: EXITED]" >> "$REP_SERVICIOS"
    cat "$TMP_EXITED" >> "$REP_SERVICIOS"

    # Servicios Inactivos
    echo -e "\n[DETALLE: SERVICIOS CON ALERTA O DETENIDOS]" >> "$REP_SERVICIOS"
    echo "--> [SUB-ESTADO: CRÍTICO / FAILED]" >> "$REP_SERVICIOS"
    cat "$TMP_FAILED" >> "$REP_SERVICIOS"
    echo "--> [SUB-ESTADO: DETENIDO / DEAD]" >> "$REP_SERVICIOS"
    cat "$TMP_DEAD" >> "$REP_SERVICIOS"

    # Limpieza absoluta de los rastros temporales
    rm -f "$TMP_RUNNING" "$TMP_EXITED" "$TMP_FAILED" "$TMP_DEAD"
    echo "[OK] Reporte de servicios listo en: $REP_SERVICIOS"
}

# --- AUDITORÍA DE USUARIOS ---
auditar_usuarios() {
    echo "[-] Analizando cuentas de usuario y permisos..."

    echo "==================================================" > "$REP_USUARIOS"
    echo "       AUDITORÍA DE USUARIOS Y PRIVILEGIOS        " >> "$REP_USUARIOS"
    echo "==================================================" >> "$REP_USUARIOS"
    echo "Última actualización: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REP_USUARIOS"
    echo "--------------------------------------------------" >> "$REP_USUARIOS"

    # Filtramos usuarios humanos reales
    local usuarios_reales=$(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}')

    if [ -z "$usuarios_reales" ]; then
        echo "[INFO] No se encontraron usuarios humanos adicionales en el sistema." >> "$REP_USUARIOS"
        return
    fi

    # Listamos cada usuario encontrado junto con sus grupos de permisos
    for usuario in $usuarios_reales; do
        local pertenencia_grupos=$(groups "$usuario")
        echo "-> Usuario: $usuario | Permisos (Grupos): $pertenencia_grupos" >> "$REP_USUARIOS"
    done

    echo "[OK] Reporte de usuarios listo en: $REP_USUARIOS"
}

# --- FLUJO PRINCIPAL ---
auditar_servicios
auditar_usuarios