-- =====================================================================
-- PASO 2: CREACIÓN DE ESTRUCTURAS DE DATOS Y LOGICA DE NEGOCIO
-- PROYECTO: CONTROL DE CALIDAD DE DATOS (DataOps)
-- INSTRUCCIÓN: Se ejecuta automáticamente conectado como el usuario del proyecto
-- =====================================================================

-- 1. CREACIÓN SEGURA DE TABLAS (No borra datos, respeta el historial)
DECLARE
    v_existe NUMBER;
BEGIN
    -- Verificar si ya existe la tabla de ventas limpias
    SELECT COUNT(*) INTO v_existe FROM user_tables WHERE table_name = 'DATOS_VENTAS_LIMPIAS';
    IF v_existe = 0 THEN
        EXECUTE IMMEDIATE '
        CREATE TABLE DATOS_VENTAS_LIMPIAS (
            id_registro NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            id_factura VARCHAR2(50),
            categoria_producto VARCHAR2(100),
            cantidad_unidades NUMBER,
            precio_unitario NUMBER(10,2),
            fecha_procesado DATE DEFAULT SYSDATE
        )';
    END IF;

    -- Verificar si ya existe la tabla de errores
    SELECT COUNT(*) INTO v_existe FROM user_tables WHERE table_name = 'REGISTRO_DE_ERRORES';
    IF v_existe = 0 THEN
        EXECUTE IMMEDIATE '
        CREATE TABLE REGISTRO_DE_ERRORES (
            id_error NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            nombre_archivo VARCHAR2(50),
            id_factura VARCHAR2(50),
            detalle_del_error VARCHAR2(200),
            hora_del_error TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )';
    END IF;
END;
/

-- 2. RECREACIÓN DEL PROCEDIMIENTO ALMACENADO (PL/SQL)
-- El procedimiento sí se puede "REPLACE" siempre, porque no guarda datos, solo lógica.
CREATE OR REPLACE PROCEDURE PROCESO_VALIDAR_VENTA (
    p_archivo IN VARCHAR2,
    p_factura_id IN VARCHAR2,
    p_categoria IN VARCHAR2,
    p_cantidad IN NUMBER,
    p_precio IN NUMBER
) AS
BEGIN
    -- REGLA DE ORO EXPANDIDA
    IF p_factura_id IS NULL OR p_categoria IS NULL OR p_cantidad IS NULL OR p_precio IS NULL OR p_cantidad <= 0 OR p_precio <= 0 THEN
        
        INSERT INTO REGISTRO_DE_ERRORES (nombre_archivo, id_factura, detalle_del_error)
        VALUES (
            p_archivo, 
            NVL(p_factura_id, 'SIN ENCONTRAR'), 
            'ERROR: Datos inválidos o faltantes. Factura: ' || NVL(p_factura_id, 'Vacío') || 
            ' | Categoría: ' || NVL(p_categoria, 'Vacío') || 
            ' | Cantidad: ' || NVL(TO_CHAR(p_cantidad), 'Vacío') || 
            ' | Precio: ' || NVL(TO_CHAR(p_precio), 'Vacío')
        );
        COMMIT;
        
    ELSE
        INSERT INTO DATOS_VENTAS_LIMPIAS (id_factura, categoria_producto, cantidad_unidades, precio_unitario)
        VALUES (p_factura_id, p_categoria, p_cantidad, p_precio);
        COMMIT;
    END IF;
END;
/

EXIT;