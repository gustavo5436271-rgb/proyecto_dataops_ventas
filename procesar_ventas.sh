#!/bin/bash

# =====================================================================
# SCRIPT DE AUTOMATIZACIÓN DE CARGA Y CALIDAD DE DATOS (VERSION INCREMENTAL)
# PROYECTO: CONTROL DE CALIDAD DE DATOS (DataOps)
# =====================================================================

# Configuración de codificación universal (Corrige tildes y caracteres extraños)
export LANG=C.UTF-8
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

# ---------------------------------------------------------------------
# FASE 1: CARGAR LAS VARIABLES DE ENTORNO
# ---------------------------------------------------------------------
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "===================================================="
    echo "✅ Variables de entorno cargadas correctamente."
    echo "===================================================="
else
    echo "❌ ERROR: No se encontró el archivo .env con las credenciales."
    exit 1
fi


# ---------------------------------------------------------------------
# FASE 2: VERIFICACIÓN DEL ARCHIVO DE DATOS (CSV)
# ---------------------------------------------------------------------
ARCHIVO_CSV="ventas_del_dia.csv"

if [ -f "$ARCHIVO_CSV" ]; then
    echo ""
    echo "📊 Archivo $ARCHIVO_CSV detectado. Iniciando procesamiento..."
    echo "----------------------------------------------------"
else
    echo "❌ ERROR: No se encuentra el archivo $ARCHIVO_CSV in esta carpeta."
    exit 1
fi


# ---------------------------------------------------------------------
# FASE 3: CAPTURAR EL ESTADO INICIAL DE LA BASE DE DATOS (FOTOS)
# ---------------------------------------------------------------------
echo "📸 Tomando captura del conteo inicial en la base de datos..."

INICIAL_LIMPIOS=$(sqlplus.exe -S "${DB_USER}/${DB_PASS}"@//localhost:1521/XE <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0;
ALTER SESSION SET CURRENT_SCHEMA = USER_DATAOPS;
SELECT COUNT(*) FROM DATOS_VENTAS_LIMPIAS;
EXIT;
EOF
)

INICIAL_ERRORES=$(sqlplus.exe -S "${DB_USER}/${DB_PASS}"@//localhost:1521/XE <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0;
ALTER SESSION SET CURRENT_SCHEMA = USER_DATAOPS;
SELECT COUNT(*) FROM REGISTRO_DE_ERRORES;
EXIT;
EOF
)

# Sanitizar conteos iniciales
INICIAL_LIMPIOS=$(echo "$INICIAL_LIMPIOS" | tr -d '\r\n' | xargs)
INICIAL_ERRORES=$(echo "$INICIAL_ERRORES" | tr -d '\r\n' | xargs)
TOTAL_INICIAL_BD=$((INICIAL_LIMPIOS + INICIAL_ERRORES))

echo "📊 La base de datos tiene actualmente: $TOTAL_INICIAL_BD registros ($INICIAL_LIMPIOS limpios y $INICIAL_ERRORES errores)."
echo "----------------------------------------------------"


# ---------------------------------------------------------------------
# FASE 4: PROCESAMIENTO E INYECCIÓN EN TIEMPO REAL A ORACLE
# ---------------------------------------------------------------------
TOTAL_PROCESADOS=0

echo "⏳ Iniciando inyección y control de calidad en Oracle..."
echo ""

while IFS=, read -r ID_FACTURA BRANCH CITY CUSTOMER GENDER CATEGORIA PRECIO CANTIDAD TAX SALES DATE TIME PAYMENT COGS MARGEN INCOME RATING || [ -n "$ID_FACTURA" ]
do
    # Ignorar la cabecera del CSV
    if [ "$ID_FACTURA" = "id_factura" ] || [ "$ID_FACTURA" = "Invoice ID" ] || [ "$ID_FACTURA" = "ID_FACTURA" ]; then
        continue
    fi

    TOTAL_PROCESADOS=$((TOTAL_PROCESADOS + 1))
    
    # Limpiar retornos de carro invisibles (\r) de Windows y espacios vacíos
    CANTIDAD=$(echo "$CANTIDAD" | tr -d '\r' | xargs)
    PRECIO=$(echo "$PRECIO" | tr -d '\r' | xargs)
    ID_FACTURA=$(echo "$ID_FACTURA" | xargs)
    CATEGORIA=$(echo "$CATEGORIA" | xargs)

    # TRADUCCIÓN PARA ORACLE: Si viene vacío, le mandamos NULL para que Oracle NUMBER lo lea bien
    if [ -z "$CANTIDAD" ]; then
        VALOR_CANTIDAD="NULL"
    else
        VALOR_CANTIDAD="$CANTIDAD"
    fi

    if [ -z "$PRECIO" ]; then
        VALOR_PRECIO="NULL"
    else
        VALOR_PRECIO="$PRECIO"
    fi

    echo "⚙️ Enviando fila #$TOTAL_PROCESADOS -> Factura: $ID_FACTURA"

    # LLAMADA A ORACLE SQL*Plus
    sqlplus.exe -S "${DB_USER}/${DB_PASS}"@//localhost:1521/XE <<EOF
    SET FEEDBACK OFF;
    SET SERVEROUTPUT ON;
    ALTER SESSION SET CURRENT_SCHEMA = USER_DATAOPS;
    
    -- Ejecutamos el procedimiento pasando las variables traducidas
    EXEC PROCESO_VALIDAR_VENTA('$ARCHIVO_CSV', '$ID_FACTURA', '$CATEGORIA', $VALOR_CANTIDAD, $VALOR_PRECIO);
    
    EXIT;
EOF

done < "$ARCHIVO_CSV"

echo ""
echo "----------------------------------------------------"
echo "🏁 Fin de la inyección. Filas leídas del archivo: $TOTAL_PROCESADOS"
echo "----------------------------------------------------"


# ---------------------------------------------------------------------
# FASE 5: FASE DE AUDITORÍA Y GENERACIÓN DE BITÁCORA (.LOG)
# ---------------------------------------------------------------------
echo "📉 Consultando conciliación final en la base de datos..."

# Nombre del archivo donde se guardará el histórico
ARCHIVO_LOG="pipeline_ventas.log"
FECHA_ACTUAL=$(date "+%Y-%m-%d %H:%M:%S")

# Consultamos los totales absolutos finales en Oracle
FINAL_LIMPIOS=$(sqlplus.exe -S "${DB_USER}/${DB_PASS}"@//localhost:1521/XE <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0;
ALTER SESSION SET CURRENT_SCHEMA = USER_DATAOPS;
SELECT COUNT(*) FROM DATOS_VENTAS_LIMPIAS;
EXIT;
EOF
)

FINAL_ERRORES=$(sqlplus.exe -S "${DB_USER}/${DB_PASS}"@//localhost:1521/XE <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0;
ALTER SESSION SET CURRENT_SCHEMA = USER_DATAOPS;
SELECT COUNT(*) FROM REGISTRO_DE_ERRORES;
EXIT;
EOF
)

# Sanitización absoluta final
FINAL_LIMPIOS=$(echo "$FINAL_LIMPIOS" | tr -d '\r\n' | xargs)
FINAL_ERRORES=$(echo "$FINAL_ERRORES" | tr -d '\r\n' | xargs)
TOTAL_FINAL_BD=$((FINAL_LIMPIOS + FINAL_ERRORES))

# --- LA MATEMÁTICA: CÁLCULO DEL CRECIMIENTO NETO ---
NUEVOS_LIMPIOS=$((FINAL_LIMPIOS - INICIAL_LIMPIOS))
NUEVOS_ERRORES=$((FINAL_ERRORES - INICIAL_ERRORES))
TOTAL_CRECIMIENTO_NETO=$((TOTAL_FINAL_BD - TOTAL_INICIAL_BD))

# --- VERIFICACIÓN DE BALANCE CERO INCREMENTAL ---
if [ "$TOTAL_PROCESADOS" -eq "$TOTAL_CRECIMIENTO_NETO" ]; then
    MENSAJE_VALIDACION="CONCILIACIÓN EXITOSA: Crecimiento incremental coincide al 100% con el archivo diario."
    ICONO_RESULTADO="✅ PROCESO_INTEGRO"
    TEXTO_PANTALLA="🎉 ¡Pipeline terminado con éxito! Conciliación incremental perfecta. Reporte guardado en: $ARCHIVO_LOG"
else
    MENSAJE_VALIDACION="ALERTA: Descuadre incremental. Filas leídas ($TOTAL_PROCESADOS) no coinciden con el crecimiento neto ($TOTAL_CRECIMIENTO_NETO)."
    ICONO_RESULTADO="🚨 ERROR_DESCUADRE"
    TEXTO_PANTALLA="⚠️ ¡Pipeline terminado pero hay un DESCUADRE DE DATOS! Revisa el archivo: $ARCHIVO_LOG"
fi

# Escribimos los resultados diarios estructurados basándonos en la diferencia neta
echo "==================================================" >> $ARCHIVO_LOG
echo "FECHA/HORA      : $FECHA_ACTUAL" >> $ARCHIVO_LOG
echo "ARCHIVO         : $ARCHIVO_CSV" >> $ARCHIVO_LOG
echo "LEÍDOS (CSV)    : $TOTAL_PROCESADOS filas" >> $ARCHIVO_LOG
echo "STATUS_OK (DÍA) : $NUEVOS_LIMPIOS registros inyectados" >> $ARCHIVO_LOG
echo "STATUS_ERR (DÍA): $NUEVOS_ERRORES alertas registradas" >> $ARCHIVO_LOG
echo "CRECIMIENTO NETO: $TOTAL_CRECIMIENTO_NETO registros nuevos" >> $ARCHIVO_LOG
echo "TOTAL ACUMULADO : $TOTAL_FINAL_BD registros totales en BD" >> $ARCHIVO_LOG
echo "AUDITORÍA       : $MENSAJE_VALIDACION" >> $ARCHIVO_LOG
echo "RESULTADO       : $ICONO_RESULTADO" >> $ARCHIVO_LOG
echo "==================================================" >> $ARCHIVO_LOG

echo "----------------------------------------------------"
echo "$TEXTO_PANTALLA"
echo "----------------------------------------------------"


# ---------------------------------------------------------------------
# FASE 6: GENERACIÓN DE REPORTE OPERATIVO PARA EXCEL (.CSV) DINÁMICO
# ---------------------------------------------------------------------
DIAS_A_REPORTAR=${1:-0}

# 1. Mensaje adaptativo de inicio y preparación de la variable de texto final
if [ "$DIAS_A_REPORTAR" -eq 0 ]; then
    echo ""
    echo "📊 Generando reporte consolidado para Excel con los datos de HOY..."
    echo "----------------------------------------------------"
    TEXTO_FINAL="📈 ¡Reporte operativo de HOY generado con éxito en: $REPORTE_EXCEL!"
else
    echo ""
    echo "📊 Generando reporte consolidado para Excel de los últimos $DIAS_A_REPORTAR días..."
    echo "----------------------------------------------------"
    TEXTO_FINAL="📈 ¡Reporte operativo de los últimos $DIAS_A_REPORTAR días generado con éxito en: $REPORTE_EXCEL!"
fi

REPORTE_EXCEL="reporte_operaciones_diarias.csv"

sqlplus.exe -S "${DB_USER}/${DB_PASS}"@//localhost:1521/XE <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 300 TRIMSPOOL ON;
ALTER SESSION SET CURRENT_SCHEMA = USER_DATAOPS;

-- Configuración Regional: Forzamos comas para delimitar decimales internos.
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';

SPOOL $REPORTE_EXCEL

-- Fila 1: Los encabezados limpios para Excel
SELECT 'CATEGORIA,TOTAL_VENTAS,UNIDADES_VENDIDAS,INGRESOS_TOTALES,PRECIO_PROMEDIO' FROM DUAL
UNION ALL
-- Filas de datos formateadas con protección de comillas dobles CHR(34) para los decimales
SELECT 
    categoria_producto || ',' ||
    TO_CHAR(COUNT(*)) || ',' ||
    TO_CHAR(SUM(cantidad_unidades)) || ',' ||
    CHR(34) || TO_CHAR(SUM(cantidad_unidades * precio_unitario), 'FM999999.99') || CHR(34) || ',' ||
    CHR(34) || TO_CHAR(ROUND(AVG(precio_unitario), 2), 'FM999.99') || CHR(34)
FROM 
    DATOS_VENTAS_LIMPIAS
WHERE 
    fecha_procesado >= TRUNC(SYSDATE) - $DIAS_A_REPORTAR 
GROUP BY 
    categoria_producto;

SPOOL OFF
EXIT;
EOF

# 2. Mostramos el mensaje final limpio y corregido 🌟
echo "----------------------------------------------------"
echo "$TEXTO_FINAL"
echo "===================================================="
echo ""