-- =====================================================================
-- Proyecto 2: Sistema distribuido para cadena de farmacias
-- NODO 2 | Base: sucursal_centro | Sucursal id = 2 (Centro)
-- Basado en el Diagrama Entidad-Relacion del equipo.
-- Script re-ejecutable (borra y recrea los objetos). Ejecutar en la base
-- del nodo correspondiente.
-- =====================================================================

-- ---------- 0. LIMPIEZA ----------
DROP TABLE IF EXISTS auditoria, detalle_venta, ventas, recetas, inventarios,
    empleados, clientes, medicamentos, proveedores, categorias_medicamento,
    sucursales CASCADE;
DROP SEQUENCE IF EXISTS seq_cliente, seq_receta, seq_venta, seq_inventario, seq_empleado;
DROP FUNCTION IF EXISTS fn_auditar() CASCADE;

-- ---------- 1. SECUENCIAS POR RANGO (evita choques de ID entre nodos) ----------
-- Norte: 1-9999 | Centro: 10000-19999 | Sur: 20000-29999
CREATE SEQUENCE seq_cliente    START 10000 MINVALUE 10000 MAXVALUE 19999;
CREATE SEQUENCE seq_receta     START 10000 MINVALUE 10000 MAXVALUE 19999;
CREATE SEQUENCE seq_venta      START 10000 MINVALUE 10000 MAXVALUE 19999;
CREATE SEQUENCE seq_inventario START 10000 MINVALUE 10000 MAXVALUE 19999;
CREATE SEQUENCE seq_empleado   START 10000 MINVALUE 10000 MAXVALUE 19999;

-- =====================================================================
-- 2. CATALOGOS GLOBALES (mismos datos en los 3 nodos - replicables)
-- =====================================================================
CREATE TABLE sucursales (
    id_sucursal  SMALLINT     PRIMARY KEY CHECK (id_sucursal BETWEEN 1 AND 3),
    nombre       VARCHAR(60)  NOT NULL UNIQUE,
    direccion    VARCHAR(120) NOT NULL,
    telefono     VARCHAR(20),
    ciudad       VARCHAR(60)  NOT NULL
);

CREATE TABLE categorias_medicamento (
    id_categoria SERIAL       PRIMARY KEY,
    nombre       VARCHAR(60)  NOT NULL UNIQUE,
    descripcion  VARCHAR(200)
);

CREATE TABLE proveedores (
    id_proveedor     SERIAL       PRIMARY KEY,
    nombre_proveedor VARCHAR(100) NOT NULL UNIQUE,
    telefono         VARCHAR(20),
    correo           VARCHAR(100) CHECK (correo IS NULL OR correo LIKE '%_@_%.__%'),
    direccion        VARCHAR(150)
);

CREATE TABLE medicamentos (
    id_medicamento   SERIAL        PRIMARY KEY,
    id_categoria     INT           NOT NULL REFERENCES categorias_medicamento(id_categoria),
    id_proveedor     INT           NOT NULL REFERENCES proveedores(id_proveedor),
    nombre           VARCHAR(100)  NOT NULL,          -- nombre generico / sustancia
    nombre_comercial VARCHAR(100)  NOT NULL,
    precio_unitario  NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
    requiere_receta  BOOLEAN       NOT NULL DEFAULT FALSE,
    stock_minimo     INT           NOT NULL DEFAULT 10 CHECK (stock_minimo >= 0),
    UNIQUE (nombre, nombre_comercial)
);

-- =====================================================================
-- 3. TABLAS LOCALES (fragmentacion horizontal por sucursal)
--    El CHECK (id_sucursal = 2) garantiza que cada nodo solo
--    almacene datos de su propia sucursal.
-- =====================================================================
CREATE TABLE clientes (
    id_cliente     BIGINT       PRIMARY KEY DEFAULT nextval('seq_cliente'),
    nombre         VARCHAR(100) NOT NULL,
    correo         VARCHAR(100) UNIQUE CHECK (correo IS NULL OR correo LIKE '%_@_%.__%'),
    telefono       VARCHAR(20),
    direccion      VARCHAR(150),
    fecha_registro DATE         NOT NULL DEFAULT CURRENT_DATE,
    curp           VARCHAR(18)  UNIQUE CHECK (curp IS NULL OR char_length(curp) = 18)
);

CREATE TABLE empleados (
    id_empleado   BIGINT       PRIMARY KEY DEFAULT nextval('seq_empleado'),
    id_sucursal   SMALLINT     NOT NULL DEFAULT 2
                               CHECK (id_sucursal = 2)
                               REFERENCES sucursales(id_sucursal),
    nombre        VARCHAR(100) NOT NULL,
    correo        VARCHAR(100) UNIQUE CHECK (correo IS NULL OR correo LIKE '%_@_%.__%'),
    telefono      VARCHAR(20),
    puesto        VARCHAR(30)  NOT NULL
                               CHECK (puesto IN ('Gerente','Farmaceutico','Cajero','Almacenista')),
    fecha_ingreso DATE         NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE inventarios (
    id_inventario       BIGINT   PRIMARY KEY DEFAULT nextval('seq_inventario'),
    id_sucursal         SMALLINT NOT NULL DEFAULT 2
                                 CHECK (id_sucursal = 2)
                                 REFERENCES sucursales(id_sucursal),
    id_medicamento      INT      NOT NULL REFERENCES medicamentos(id_medicamento),
    existencia          INT      NOT NULL CHECK (existencia >= 0),
    stock_minimo        INT      NOT NULL DEFAULT 10 CHECK (stock_minimo >= 0),
    fecha_actualizacion DATE     NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (id_sucursal, id_medicamento)
);

CREATE TABLE recetas (
    id_receta      BIGINT       PRIMARY KEY DEFAULT nextval('seq_receta'),
    id_cliente     BIGINT       NOT NULL REFERENCES clientes(id_cliente),
    id_medicamento INT          NOT NULL REFERENCES medicamentos(id_medicamento),
    id_sucursal    SMALLINT     NOT NULL DEFAULT 2
                                CHECK (id_sucursal = 2)
                                REFERENCES sucursales(id_sucursal),
    nombre_medico  VARCHAR(100) NOT NULL,
    cedula_medico  VARCHAR(20)  NOT NULL,
    fecha_emision  DATE         NOT NULL DEFAULT CURRENT_DATE
                                CHECK (fecha_emision <= CURRENT_DATE)
);

CREATE TABLE ventas (
    id_venta    BIGINT        PRIMARY KEY DEFAULT nextval('seq_venta'),
    id_sucursal SMALLINT      NOT NULL DEFAULT 2
                              CHECK (id_sucursal = 2)
                              REFERENCES sucursales(id_sucursal),
    id_empleado BIGINT        NOT NULL REFERENCES empleados(id_empleado),
    id_cliente  BIGINT        REFERENCES clientes(id_cliente),  -- relacion Cliente-Ventas del diagrama (opcional)
    id_receta   BIGINT        REFERENCES recetas(id_receta),    -- solo si el medicamento requiere receta
    fecha_hora  TIMESTAMP     NOT NULL DEFAULT now(),
    total       NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0)
);

CREATE TABLE detalle_venta (
    id_venta        BIGINT        NOT NULL REFERENCES ventas(id_venta) ON DELETE CASCADE,
    id_medicamento  INT           NOT NULL REFERENCES medicamentos(id_medicamento),
    cantidad        INT           NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
    subtotal        NUMERIC(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    PRIMARY KEY (id_venta, id_medicamento)
);

-- =====================================================================
-- 4. AUDITORIA
-- =====================================================================
CREATE TABLE auditoria (
    id_auditoria      BIGSERIAL    PRIMARY KEY,
    usuario           VARCHAR(60)  NOT NULL DEFAULT current_user,
    fecha_hora        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    operacion         VARCHAR(10)  NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    tabla_afectada    VARCHAR(60)  NOT NULL,
    registro_afectado VARCHAR(60),
    valor_anterior    JSONB,
    valor_nuevo       JSONB
);

-- Trigger generico: recibe como argumentos la(s) columna(s) de la llave primaria
CREATE OR REPLACE FUNCTION fn_auditar() RETURNS TRIGGER AS $$
DECLARE
    v_reg  JSONB := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
    v_pk   TEXT  := '';
    v_col  TEXT;
BEGIN
    FOREACH v_col IN ARRAY TG_ARGV LOOP
        v_pk := v_pk || CASE WHEN v_pk = '' THEN '' ELSE '-' END || COALESCE(v_reg->>v_col, '');
    END LOOP;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria(operacion, tabla_afectada, registro_afectado, valor_nuevo)
        VALUES (TG_OP, TG_TABLE_NAME, v_pk, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria(operacion, tabla_afectada, registro_afectado, valor_anterior, valor_nuevo)
        VALUES (TG_OP, TG_TABLE_NAME, v_pk, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSE
        INSERT INTO auditoria(operacion, tabla_afectada, registro_afectado, valor_anterior)
        VALUES (TG_OP, TG_TABLE_NAME, v_pk, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_aud_inventarios AFTER INSERT OR UPDATE OR DELETE ON inventarios
    FOR EACH ROW EXECUTE FUNCTION fn_auditar('id_inventario');
CREATE TRIGGER trg_aud_ventas AFTER INSERT OR UPDATE OR DELETE ON ventas
    FOR EACH ROW EXECUTE FUNCTION fn_auditar('id_venta');
CREATE TRIGGER trg_aud_detalle_venta AFTER INSERT OR UPDATE OR DELETE ON detalle_venta
    FOR EACH ROW EXECUTE FUNCTION fn_auditar('id_venta','id_medicamento');
CREATE TRIGGER trg_aud_recetas AFTER INSERT OR UPDATE OR DELETE ON recetas
    FOR EACH ROW EXECUTE FUNCTION fn_auditar('id_receta');
CREATE TRIGGER trg_aud_clientes AFTER INSERT OR UPDATE OR DELETE ON clientes
    FOR EACH ROW EXECUTE FUNCTION fn_auditar('id_cliente');

-- =====================================================================
-- 5. INDICES (para consultas relevantes)
-- =====================================================================
CREATE INDEX idx_inventarios_medicamento ON inventarios(id_medicamento);          -- existencia por medicamento
CREATE INDEX idx_inventarios_stock       ON inventarios(existencia, stock_minimo); -- cercanos al minimo
CREATE INDEX idx_ventas_sucursal_fecha   ON ventas(id_sucursal, fecha_hora);       -- ventas por periodo
CREATE INDEX idx_detalle_medicamento     ON detalle_venta(id_medicamento);
CREATE INDEX idx_medicamentos_nombre     ON medicamentos(nombre);
CREATE INDEX idx_recetas_cliente         ON recetas(id_cliente);
CREATE INDEX idx_auditoria_fecha         ON auditoria(fecha_hora, tabla_afectada);

-- =====================================================================
-- 6. DATOS DE CATALOGOS GLOBALES (IDENTICOS EN LOS 3 NODOS)
-- =====================================================================
INSERT INTO sucursales(id_sucursal, nombre, direccion, telefono, ciudad) VALUES
 (1,'Sucursal Norte' ,'Av. Gregorio Méndez 110'  ,'993-100-0001','Teapa'),
 (2,'Sucursal Centro','Po. Tapijulapa 270' ,'993-200-0002','Tacotalpa'),
 (3,'Sucursal Sur'   ,'Av. Sur 355'    ,'993-300-0003','Jalapa');


INSERT INTO categorias_medicamento(nombre, descripcion) VALUES
 ('Analgesicos'       ,'Alivio del dolor y la fiebre'),
 ('Antibioticos'      ,'Tratamiento de infecciones bacterianas'),
 ('Antiinflamatorios' ,'Reduccion de la inflamacion'),
 ('Antihistaminicos'  ,'Tratamiento de alergias'),
 ('Gastrointestinales','Acidez, gastritis y digestion'),
 ('Vitaminas'         ,'Suplementos vitaminicos');

INSERT INTO proveedores(nombre_proveedor, telefono, correo, direccion) VALUES
 ('Distribuidora Farma del Sureste','993-111-1111','ventas@farmasureste.com','Calle Industria 10, Villahermosa'),
 ('Laboratorios Medix'             ,'993-222-2222','contacto@medix.com'     ,'Blvd. Ruiz Cortines 55, Villahermosa'),
 ('Geomed'             ,'993-333-3333','pedidos@drogueria.com'  ,'Av. Universidad 80, Villahermosa');

INSERT INTO medicamentos(id_categoria,id_proveedor,nombre,nombre_comercial,precio_unitario,requiere_receta,stock_minimo) VALUES
 (1,1,'Paracetamol 500 mg'   ,'Tempra'        , 35.00,FALSE,20),
 (3,1,'Ibuprofeno 400 mg'    ,'Advil'         , 52.50,FALSE,15),
 (2,2,'Amoxicilina 500 mg'   ,'Amoxil'        , 98.00,TRUE ,10),
 (2,2,'Azitromicina 500 mg'  ,'Zitromax'      ,145.00,TRUE , 8),
 (4,3,'Loratadina 10 mg'     ,'Clarityne'     , 42.00,FALSE,12),
 (5,3,'Omeprazol 20 mg'      ,'Losec'         , 60.00,FALSE,15),
 (3,1,'Naproxeno 250 mg'     ,'Flanax'        , 75.00,FALSE,10),
 (6,3,'Vitamina C 1 g'       ,'Redoxon'       , 89.00,FALSE,10),
 (2,2,'Ciprofloxacino 500 mg','Ciproxina'     ,120.00,TRUE , 8),
 (1,2,'Metformina 850 mg'    ,'Glucophage'    , 68.00,TRUE ,10);

-- =====================================================================
-- 7. VERIFICACION
-- =====================================================================
SELECT 'Nodo 2 listo: sucursal_centro' AS estado,
       (SELECT count(*) FROM sucursales)   AS sucursales,
       (SELECT count(*) FROM medicamentos) AS medicamentos;
