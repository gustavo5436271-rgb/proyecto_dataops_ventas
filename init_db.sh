#!/bin/bash
# =====================================================================
# init_db.sh - Despliegue Inteligente e Interactivo de Base de Datos
# PROYECTO: CONTROL DE CALIDAD DE DATOS (DataOps)
# =====================================================================

# 1. Cargar las variables seguras del entorno
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "✅ Variables de entorno cargadas correctamente."
else
    echo "❌ ERROR: No se encontró el archivo .env"
    exit 1
fi

echo "===================================================="
echo "   🔄 ASISTENTE DE DESPLIEGUE ORACLE (DataOps)      "
echo "===================================================="
echo ""

# 2. Preguntar de forma interactiva al ingeniero
read -p "❓ ¿Desea crear el usuario/esquema nuevo por primera vez? (s/n): " respuesta

# Convertir la respuesta a minúscula para evitar errores si escriben 'S' o 'N'
respuesta=$(echo "$respuesta" | tr '[:upper:]' '[:lower:]')

echo ""
echo "----------------------------------------------------"

if [ "$respuesta" = "s" ] || [ "$respuesta" = "si" ] || [ "$respuesta" = "sí" ]; then
    echo "👤 [Fase A] Creando usuario nuevo con privilegios de Administrador..."
    # 🌟 Aquí usamos DB_SYSTEM_PASS para conectarnos como ADMIN, y pasamos DB_USER y DB_PASS para el nuevo esquema
    sqlplus.exe -S system/"$DB_SYSTEM_PASS"@//localhost:1521/XE @01_crear_usuario.sql "$DB_USER" "$DB_PASS"
    echo "✅ Usuario creado correctamente."
    echo "----------------------------------------------------"
else
    echo "ℹ️ Saltando creación de usuario. Se usará el esquema existente: $DB_USER"
    echo "----------------------------------------------------"
fi

# 3. Esta fase se ejecuta SIEMPRE (Crea o limpia las tablas)
echo "📊 [Fase B] Desplegando tablas y lógica de negocio en el esquema..."
# Ejecuta el archivo 02 usando directamente la cuenta del proyecto recién creada o existente
sqlplus.exe -S "$DB_USER"/"$DB_PASS"@//localhost:1521/XE @02_crear_tablas_procedimientos.sql

echo "----------------------------------------------------"
echo "🎉 ¡PROCESO FINALIZADO CON ÉXITO!"
echo "===================================================="


echo "🚀 Iniciando inyección de datos y generación de reportes automáticamente..."
./procesar_ventas.sh "$1"