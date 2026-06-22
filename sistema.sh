#!/bin/bash

# --- CONFIGURACIÓN DE VARIABLES Y ARCHIVOS ---
REPORT_FILE="reporte_sistema.txt"
UMBRAL_DISCO=80

# --- INICIO DEL REPORTE ---
echo "==================================================" > $REPORT_FILE
echo "       REPORTE DE ESTADO DEL SISTEMA Linux        " >> $REPORT_FILE
echo "==================================================" >> $REPORT_FILE
echo "Fecha de ejecución: $(date '+%Y-%m-%d %H:%M:%S')" >> $REPORT_FILE
echo "--------------------------------------------------" >> $REPORT_FILE

# --- RECOLECCIÓN DE INFORMACIÓN ---

echo "[-] Recolectando información del entorno en Ubuntu Server..."

# 1. Usuario actual
USUARIO_ACTUAL=$(whoami)

# 2. Versión del Sistema Operativo
VERSION_SO=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)

# 3. Memoria Libre
MEMORIA_LIBRE=$(free -m | grep "Mem" | awk '{print $7}')

# 4. Espacio en disco de la partición raíz (/)
USO_DISCO_PORCENTAJE=$(df -x squashfs / | grep -E '/$' | awk '{print $5}' | sed 's/%//')
DISCO_DISPONIBLE=$(df -h -x squashfs / | grep -E '/$' | awk '{print $4}')

# --- ESCRIBIR DATOS EN EL REPORTE ---
{
    echo "Usuario Actual:         $USUARIO_ACTUAL"
    echo "Sistema Operativo:      $VERSION_SO"
    echo "Memoria Libre:          ${MEMORIA_LIBRE} MB"
    echo "Espacio Disponible (/): $DISCO_DISPONIBLE"
    echo "Porcentaje de Uso (/):  ${USO_DISCO_PORCENTAJE}%"
} >> $REPORT_FILE

# --- ESTRUCTURAS DE CONTROL: VALIDACIÓN DE UMBRAL ---
echo "[-] Validando alertas de almacenamiento..."

echo -e "\n--- ALERTAS Y ESTADO FINAL ---" >> $REPORT_FILE

if [ "$USO_DISCO_PORCENTAJE" -gt "$UMBRAL_DISCO" ]; then
    echo "[ALERTA CRÍTICA] El uso del disco ($USO_DISCO_PORCENTAJE%) supera el umbral del $UMBRAL_DISCO%." >> $REPORT_FILE
    echo "Estado Final: REVISIÓN REQUERIDA" >> $REPORT_FILE

    echo "¡ALERTA! El espacio en disco es crítico (${USO_DISCO_PORCENTAJE}%). Se requiere limpieza."
else
    echo "[OK] El uso del disco ($USO_DISCO_PORCENTAJE%) está dentro de los límites seguros." >> $REPORT_FILE
    echo "Estado Final: SISTEMA ESTABLE" >> $REPORT_FILE

    echo "Sustentación completada con éxito. El sistema está estable."
fi

echo "--------------------------------------------------" >> $REPORT_FILE
echo "[-] Proceso terminado. Reporte guardado en: $REPORT_FILE"

cat $REPORT_FILE