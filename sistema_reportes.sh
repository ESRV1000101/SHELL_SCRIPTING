#!/bin/bash

# Directorios de la Suite
DIR_LOGS_SUITE="/var/log/suite_ti"

DIR_SCRIPTS="/home/elias/Scripts"

# Rutas exactas de tus scripts independientes
SCRIPT_1="$DIR_SCRIPTS/sistema.sh"
SCRIPT_2="$DIR_SCRIPTS/gestor_temporales.sh"
SCRIPT_3="$DIR_SCRIPTS/reporte_servicios.sh"

# Ruta de reportes
REP_SISTEMA="/home/elias/Reportes/reporte_sistema.txt"
REP_LIMPIEZA="/home/elias/Reportes/reporte_limpieza.txt"
REP_SERVICIOS="/home/elias/Reportes/reporte_servicios.txt"
REP_USUARIOS="/home/elias/Reportes/reporte_usuarios.txt"

# --- OPCIÓN 1: SUBMENÚ PARA REVISAR EL CÓDIGO DE LOS SCRIPTS ---
revisar_codigo_scripts() {
    local opc_sc=0
    while [ "$opc_sc" -ne 4 ]; do
        echo -e "\n=================================================="
        echo "          INSPECTOR DE CÓDIGO FUENTE              "
        echo "=================================================="
        echo "1. Inspeccionar: sistema.sh"
        echo "2. Inspeccionar: gestor_temporales.sh"
        echo "3. Inspeccionar: reporte_servicios.sh"
        echo "4. Volver al Menú Principal"
        echo "--------------------------------------------------"
        read -p "Seleccione el script a revisar [1-4]: " opc_sc

        case $opc_sc in
            1)
                echo -e "\n=================================================="
                echo "UBICACIÓN ABSOLUTA: $SCRIPT_1"
                echo "=================================================="
                if [ -f "$SCRIPT_1" ]; then cat "$SCRIPT_1"; else echo "[ERROR] Archivo no encontrado."; fi
                ;;
            2)
                echo -e "\n=================================================="
                echo "UBICACIÓN ABSOLUTA: $SCRIPT_2"
                echo "=================================================="
                if [ -f "$SCRIPT_2" ]; then cat "$SCRIPT_2"; else echo "[ERROR] Archivo no encontrado."; fi
                ;;
            3)
                echo -e "\n=================================================="
                echo "UBICACIÓN ABSOLUTA: $SCRIPT_3"
                echo "=================================================="
                if [ -f "$SCRIPT_3" ]; then cat "$SCRIPT_3"; else echo "[ERROR] Archivo no encontrado."; fi
                ;;
            4) echo "Regresando..." ;;
            *) echo "[ALERTA] Opción incorrecta." ;;
        esac
    done
}

# --- OPCIÓN 2: SUBMENÚ PARA REVISAR REPORTES TEXTO ---
mostrar_submenu_reportes() {
    local opc_rep=0
    while [ "$opc_rep" -ne 5 ]; do
        echo -e "\n=================================================="
        echo "         VISUALIZADOR DE REPORTES (.TXT)          "
        echo "=================================================="
        echo "1. Ver Reporte de Estado del Sistema"
        echo "2. Ver Reporte de Historial de Limpiezas"
        echo "3. Ver Reporte del Estado de Servicios"
        echo "4. Ver Reporte de Permisos de Usuarios"
        echo "5. Volver al Menú Principal"
        echo "--------------------------------------------------"
        read -p "Seleccione una opción [1-5]: " opc_rep

        case $opc_rep in
            1) if [ -f "$REP_SISTEMA" ]; then cat "$REP_SISTEMA"; else echo "[INFO] Aún no se genera."; fi ;;
            2) if [ -f "$REP_LIMPIEZA" ]; then cat "$REP_LIMPIEZA"; else echo "[INFO] Aún no se genera."; fi ;;
            3) if [ -f "$REP_SERVICIOS" ]; then cat "$REP_SERVICIOS"; else echo "[INFO] Aún no se genera."; fi ;;
            4) if [ -f "$REP_USUARIOS" ]; then cat "$REP_USUARIOS"; else echo "[INFO] Aún no se genera."; fi ;;
            5) echo "Regresando..." ;;
            *) echo "[ALERTA] Opción inválida." ;;
        esac
    done
}

# --- OPCIÓN 3: REPORTE GENERAL EXTENDIDO ---
mostrar_reporte_general_control() {
    # Definimos la ruta del nuevo reporte de control unificado
    local REP_GENERAL_MAESTRO="/home/elias/Reportes/reporte_general_maestro.txt"

    # Envolvemos todo el bloque de impresión dentro de una función interna
    {
        echo "=================================================="
        echo "   REPORTE MAESTRO DE CONFIGURACIÓN Y AUDITORÍA   "
        echo "=================================================="
        echo "Fecha de Consulta:     $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Directorio de Logs:     $DIR_LOGS_SUITE"
        echo "Ubicación Controlador:  $DIR_SCRIPTS"
        echo "Ubicación de Reporte:   $REP_GENERAL_MAESTRO"
        echo "--------------------------------------------------"
        echo "ANÁLISIS DINÁMICO DE AUTOMATIZACIONES (CRONTAB ROOT):"

        local tareas_cron=$(crontab -l 2>/dev/null | grep -v '^#')
        if [ -z "$tareas_cron" ]; then
            echo " [ADVERTENCIA] No hay automatizaciones programadas en Crontab de Root."
        else
            echo "$tareas_cron" | while read -r linea_cron; do
                echo " -> Programación: $linea_cron"
            done
        fi

        echo "--------------------------------------------------"
        echo "AUDITORÍA EXTENDIDA DE BITÁCORAS INDIVIDUALEŚ (.LOG):"

        if [ -d "$DIR_LOGS_SUITE" ] && [ "$(ls -A "$DIR_LOGS_SUITE")" ]; then
            ls -1rt "$DIR_LOGS_SUITE"/*.log 2>/dev/null | while read -r ruta_log; do
                local nombre_log=$(basename "$ruta_log")
                local fecha_creacion=$(stat -c '%y' "$ruta_log" | cut -d'.' -f1)
                echo " -> Log Detectado:"
                echo "    • Nombre:    $nombre_log"
                echo "    • Creado el: $fecha_creacion"
                echo "    • Ubicación: $ruta_log"
                echo "    --------------------------------------------"
            done
        else
            echo " [INFO] No se han registrado archivos de log individuales aún en la carpeta."
        fi
        echo "=================================================="
    } | tee "$REP_GENERAL_MAESTRO" # <--- Aquí ocurre la magia: escribe el .txt y muestra en pantalla

    echo -e "\n[OK] Copia física guardada exitosamente en: $REP_GENERAL_MAESTRO"
}

# --- MENÚ PRINCIPAL ---
opcion_principal=0
while [ "$opcion_principal" -ne 4 ]; do
    echo -e "\n=================================================="
    echo "      TABLERO DE CONTROL - ADMINISTRACIÓN TI      "
    echo "=================================================="
    echo "1. Revisar Código Fuente de los Scripts"
    echo "2. Revisar los Reportes Scripts (.txt)"
    echo "3. Ver Reporte General (Metadatos, Cron y Historial Logs)"
    echo "4. Salir del Panel"
    echo "=================================================="
    read -p "Seleccione una opción [1-4]: " opcion_principal

    case $opcion_principal in
        1) revisar_codigo_scripts ;;
        2) mostrar_submenu_reportes ;;
        3) mostrar_reporte_general_control ;;
        4) echo -e "\nCerrando Panel de Control de manera segura.\n" ;;
        *) echo -e "\n[ALERTA] Opción incorrecta." ;;
    esac
done