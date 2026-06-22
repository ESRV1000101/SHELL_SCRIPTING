#!/bin/bash

# ==============================================================================
# SCRIPT 2
# OBJETIVO: Limpieza automatizada y manejo inteligente de un reporte propio.
# ==============================================================================

# --- CONFIGURACIÓN DE VARIABLES ---
DIRECTORIO_TARGET="/var/tmp/temporales_ti"
REPORT_LIMPIEZA="reporte_limpieza.txt"  # Nuevo archivo de texto exclusivo
DIAS_RETENCION=7
MAX_REINTENTOS=3

# --- CONDICIONAL: MANEJO DEL ARCHIVO DE REPORTE ---
# Comprobamos si no existe el archivo usando
if [ ! -f "$REPORT_LIMPIEZA" ]; then
    # Si no existe, lo crea
    echo "==================================================" > "$REPORT_LIMPIEZA"
    echo "       NUEVO REPORTE DE LIMPIEZA DE ARCHIVOS       " >> "$REPORT_LIMPIEZA"
    echo "==================================================" >> "$REPORT_LIMPIEZA"
else
    # Si ya existe, no lo borra; solo añade una marca de separación por fecha de reporte
    echo -e "\n--------------------------------------------------" >> "$REPORT_LIMPIEZA"
fi

# Añadimos la fecha exacta de esta ejecución al reporte
echo "Fecha de ejecución: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_LIMPIEZA"
echo "--------------------------------------------------" >> "$REPORT_LIMPIEZA"

# --- SIMULACIÓN DE ENTORNO ---
if [ ! -d "$DIRECTORIO_TARGET" ]; then
    mkdir -p "$DIRECTORIO_TARGET"
    touch "$DIRECTORIO_TARGET/reciente.tmp"
    touch -d "10 days ago" "$DIRECTORIO_TARGET/basura_antigua.tmp"
    touch -d "15 days ago" "$DIRECTORIO_TARGET/error_viejo.log"
fi

# Ajustamos permisos del directorio objetivo
chmod 755 "$DIRECTORIO_TARGET"

# --- BUSQUEDA FILTRADA POR TIEMPO ---
echo "[-] Buscando archivos temporales obsoletos..."
ARCHIVOS_A_ELIMINAR=$(find "$DIRECTORIO_TARGET" -type f \( -name "*.tmp" -o -name "*.log" \) -mtime +$DIAS_RETENCION)

if [ -z "$ARCHIVOS_A_ELIMINAR" ]; then
    echo "[OK] No se encontraron archivos que superen los $DIAS_RETENCION días." >> "$REPORT_LIMPIEZA"
    echo "[-] No hay archivos antiguos para limpiar."
    exit 0
fi


# --- PASO 3: BUCLE DE ELIMINACIÓN CON REINTENTOS ---
for archivo in $ARCHIVOS_A_ELIMINAR; do
    echo "Evaluando para eliminación: $(basename "$archivo")"

    intento=1
    borrado_exitoso=false

    while [ $intento -le $MAX_REINTENTOS ] && [ "$borrado_exitoso" = false ]; do
        if [ -f "$archivo" ]; then
            # Intentamos borrar y redirigimos errores al nuevo txt
            rm -f "$archivo" 2>> "$REPORT_LIMPIEZA"

            if [ $? -eq 0 ]; then
                echo "[ELIMINADO] $(basename "$archivo") (Antigüedad > $DIAS_RETENCION días)" >> "$REPORT_LIMPIEZA"
                borrado_exitoso=true
            else
                echo "[REINTENTO $intento] Error al borrar $(basename "$archivo")" >> "$REPORT_LIMPIEZA"
                intento=$((intento + 1))
                sleep 1
            fi
        else
            borrado_exitoso=true
        fi
    done
done

echo "[-] Limpieza concluida. Historial registrado en: $REPORT_LIMPIEZA"