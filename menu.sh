#!/bin/bash

DIR_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_REPORTES="/home/elias/Reportes"
DIR_LOGS="/var/log/suite_ti"

# --- Submenú 1: elegir y ejecutar un script de la carpeta ---
submenu_ejecutar_scripts() {
    mapfile -t scripts < <(find "$DIR_SCRIPTS" -maxdepth 1 -name "*.sh" \
                            ! -name "$(basename "${BASH_SOURCE[0]}")" -printf '%f\n' | sort)

    if [ "${#scripts[@]}" -eq 0 ]; then
        echo "[INFO] No hay scripts .sh en $DIR_SCRIPTS"
        return
    fi

    PS3="Elige el script a ejecutar (o 'Volver'): "
    select elegido in "${scripts[@]}" "Volver"; do
        case "$elegido" in
            "Volver") break ;;
            "")       echo "Opción inválida." ;;
            *)        echo "--- Ejecutando $elegido ---"
                      bash "$DIR_SCRIPTS/$elegido"
                      break ;;
        esac
    done
}

# --- Submenú 2: elegir y visualizar un reporte de la carpeta ---
submenu_ver_reportes() {
    mapfile -t reportes < <(find "$DIR_REPORTES" -type f -printf '%P\n' 2>/dev/null | sort)

    if [ "${#reportes[@]}" -eq 0 ]; then
        echo "[INFO] No hay reportes en $DIR_REPORTES"
        return
    fi

    PS3="Elige el reporte a visualizar (o 'Volver'): "
    select elegido in "${reportes[@]}" "Volver"; do
        case "$elegido" in
            "Volver") break ;;
            "")       echo "Opción inválida." ;;
            *)        echo "--- Contenido de $elegido ---"
                      cat "$DIR_REPORTES/$elegido"
                      break ;;
        esac
    done
}

# --- Opción 3: resumen general del estado de la suite ---
mostrar_resumen_general() {
    local total_scripts total_reportes total_logs automatizados ultima_ejecucion

    total_scripts=$(find "$DIR_SCRIPTS" -maxdepth 1 -name "*.sh" ! -name "$(basename "${BASH_SOURCE[0]}")" | wc -l)
    total_reportes=$(find "$DIR_REPORTES" -maxdepth 1 -type f 2>/dev/null | wc -l)
    total_logs=$(find "$DIR_LOGS" -maxdepth 1 -type f -name "*.log" 2>/dev/null | wc -l)
    automatizados=$(crontab -l 2>/dev/null | grep -cF "$DIR_SCRIPTS")
    ultima_ejecucion=$(find "$DIR_LOGS" -maxdepth 1 -type f -name "*.log" -printf '%T@ %f\n' 2>/dev/null \
                        | sort -rn | head -1 | cut -d' ' -f2-)

    echo "=================================================="
    echo "         RESUMEN GENERAL DE LA SUITE DE TI         "
    echo "=================================================="
    echo "Scripts disponibles:          $total_scripts"
    echo "Scripts automatizados (cron): $automatizados"
    echo "Reportes generados:           $total_reportes"
    echo "Logs generados:               $total_logs"
    echo "Última ejecución registrada:  ${ultima_ejecucion:-N/D}"
    echo "=================================================="
}

# --- Menú principal ---
main() {
    while true; do
        echo ""
        echo "========== MENÚ PRINCIPAL - SUITE DE TI =========="
        echo "1) Ejecutar un script"
        echo "2) Ver un reporte"
        echo "3) Resumen general de la suite"
        echo "4) Salir"
        read -rp "Elige una opción: " opcion || { echo; echo "Entrada finalizada. Saliendo..."; exit 0; }

        case "$opcion" in
            1) submenu_ejecutar_scripts ;;
            2) submenu_ver_reportes ;;
            3) mostrar_resumen_general ;;
            4) echo "Saliendo..."; exit 0 ;;
            *) echo "[ERROR] Opción inválida, elige del 1 al 4." ;;
        esac
    done
}

main