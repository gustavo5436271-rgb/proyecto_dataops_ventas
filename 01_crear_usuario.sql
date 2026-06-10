-- =====================================================================
-- PASO 1: CONFIGURACIÓN DE INFRAESTRUCTURA Y PERMISOS (ADMIN)
-- =====================================================================
ALTER SESSION SET "_ORACLE_SCRIPT"=true;

CREATE USER &1 IDENTIFIED BY &2;
GRANT CONNECT, RESOURCE, CREATE VIEW TO &1;
ALTER USER &1 QUOTA UNLIMITED ON USERS;

EXIT;