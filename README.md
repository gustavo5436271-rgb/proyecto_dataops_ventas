# 🚀 Pipeline DataOps: Automatización de Carga, Calidad de Datos e Inyección en Oracle XE

Este proyecto implementa un flujo de trabajo automatizado (**Pipeline ETL/DataOps**) diseñado y editado utilizando **Visual Studio Code (VS Code)**, y ejecutado en un entorno Linux mediante **WSL2 (Windows Subsystem for Linux 2 - Ubuntu)**. El sistema utiliza scripts de automatización de comandos de Linux (**Bash / `.sh`**) para procesar e ingestar dinámicamente archivos de datos **CSV** hacia un motor **Oracle**, aplicando validaciones en tiempo real con **PL/SQL**.

---

## 💻 Entorno Tecnológico y Arquitectura Híbrida

* **Entorno de Desarrollo (IDE):** Visual Studio Code (Windows) para la escritura y edición del código.
* **Capa de Sistema / Consola:** Windows Subsystem for Linux 2 (**WSL2** - Ubuntu) para la ejecución del entorno Linux.
* **Intérprete de Automatización:** **Bash**, encargado de orquestar los scripts de comandos de Linux (**`.sh`**).
* **Motor de Base de Datos:** **Oracle Database Express Edition (XE)**.
* **Estructura de Datos:** Archivos de texto plano delimitados por comas (**CSV**).

---

## 🛠️ Componentes del Sistema

El pipeline está segmentado en scripts modulares de Linux (`.sh`) y archivos estructurados SQL que garantizan un despliegue controlado:

* **`init_db.sh`**: Script de Bash (Linux) que actúa como asistente interactivo para inicializar la infraestructura en Oracle. Permite pasarle un parámetro numérico de días o, en su ausencia, procesa por defecto únicamente la actividad de la fecha actual.
* **`procesar_ventas.sh`**: Script de Bash orquestador diario encargado de leer el archivo fuente CSV, aplicar comandos de sanitización en Linux, inyectar fila por fila en Oracle y realizar auditorías de balance cero basadas en el parámetro de días.
* **`01_crear_usuario.sql` & `02_crear_tablas_procedimientos.sql`**: Scripts nativos para Oracle que contienen el DDL y el procedimiento almacenado `PROCESO_VALIDAR_VENTA`.
* **`ventas_del_dia.csv`**: Archivo de datos fuente estructurado en CSV utilizado para simular una carga diaria real de 1,000 registros.

---

## ⚙️ Configuración y Requisitos para la Ejecución Local

Para garantizar la seguridad, las contraseñas y accesos **están protegidos mediante variables de entorno** a través de un archivo local y nunca se suben al repositorio (están excluidas en el `.gitignore`).

Sigue estos pasos para replicar el pipeline en tu máquina WSL2:

### 1. Crear el archivo de configuración ambiental (`.env`)
Dado que la carpeta del proyecto se encuentra físicamente hospedada en el sistema de archivos de Windows pero se accede y ejecuta mediante un puente remoto en WSL2, debes ubicarte en dicha ruta y crear un archivo de texto llamado exactamente `.env`. Reemplaza los valores con tu usuario y contraseñas reales de Oracle:

```env
# ==============================================================================
# CONFIGURACIÓN DE CREDENCIALES - PIPELINE DATAOPS (WSL2 / ORACLE)
# ==============================================================================

# 1. Credenciales del Administrador Supremo (Se usa solo para crear la infraestructura)
DB_SYSTEM_PASS=tu_contraseña_system_aqui

# 2. Credenciales del Proyecto DataOps (Se usa para el procesamiento diario)
DB_USER=user_dataops
DB_PASS=tu_contraseña_usuario_aqui
```

### 2. Otorgar permisos de ejecución en Linux
Antes de lanzar el pipeline por primera vez, debes darle permisos de ejecución a los asistentes de Bash desde tu terminal de Ubuntu:
```bash
chmod +x init_db.sh procesar_ventas.sh

---

## 📸 Ejecución y Demostración en la Terminal de Ubuntu (WSL2)

### 1. Inicialización de la Infraestructura en Linux
El asistente interactivo `init_db.sh` se ejecuta en la consola de Bash acompañado de un **argumento numérico** opcional (por ejemplo, `./init_db.sh 2`). 

Este número le indica explícitamente al asistente **cuántos días hacia atrás** debe tomar en cuenta para configurar y preparar los reportes y las tablas de auditoría en Oracle **desde el momento de la última ejecución**. Si el script se ejecuta a secas sin ningún número (`./init_db.sh`), el sistema toma por defecto de forma automática **toda la información correspondiente al día de hoy**.

<img width="790" height="291" alt="{1F18E23A-C2D1-4DAE-B168-9CFABC65BBEE}" src="https://github.com/user-attachments/assets/b0740460-55ad-4104-8e06-dbc82137c377" />

Una vez iniciado, el asistente lanza una pregunta de control interactiva: **`¿Desea crear el usuario/esquema nuevo por primera vez? (s/n):`**, dividiendo el flujo del pipeline en dos caminos lógicos:
* **Si se responde `s` (Sí):** El script realiza una instalación desde cero. Se conecta a Oracle usando credenciales de administrador (`DB_SYSTEM_PASS`), crea el esquema (`user_dataops`), asigna privilegios y ejecuta las estructuras DDL iniciales.
* **Si se responde `n` (No):** El script detecta que la base ya existe. Omite la fase de creación de usuarios para evitar colisiones y procede directo a actualizar/recompilar la lógica de PL/SQL en Oracle y parametrizar la ventana de tiempo elegida.

### 2. Processing de Archivos CSV y Conciliación Incremental
El script orquestador diario toma el rango seleccionado, lee los registros del CSV en tiempo real mediante comandos de Linux e interactúa con Oracle. Al finalizar, ejecuta un algoritmo de balance cero que compara las filas leídas del archivo con el crecimiento neto real en las tablas de la base de datos para asegurar un **100% de integridad (Conciliación Exitosa)**.

<img width="1063" height="551" alt="{9A737F2B-13FB-4335-AD86-18F799D30CB6}" src="https://github.com/user-attachments/assets/86cf8eb2-590f-486d-ba24-25c22bc5b1f5" />

---

## 📊 Reportes y Auditoría de Balance Cero

Al finalizar el flujo en Bash, el sistema exporta automáticamente dos productos de control:
1.  **`pipeline_ventas.log`**: Archivo log histórico en Linux con marcas de tiempo, estados de auditoría y métricas de crecimiento en Oracle.
2.  **`reporte_operaciones_diarias.csv`**: Archivo de salida CSV consolidado con protección de comillas (`CHR(34)`) y formato regional adaptativo (`NLS_NUMERIC_CHARACTERS`) diseñado específicamente para abrirse de forma limpia en **Excel Web** sin romper las divisiones de columnas.

### 🧮 El Algoritmo de Balance Cero
Para garantizar que no se pierda ni un solo registro en el trayecto del CSV a Oracle, el script implementa una conciliación matemática estricta:

$$\text{Filas Finales en BD} - \text{Filas Iniciales en BD} - \text{Filas Totales en CSV} = 0$$

Si el resultado es exactamente $0$, el sistema valida la operation como exitosa. Cualquier desviación activa una alerta inmediata en los logs de auditoría.

