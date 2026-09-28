-- ============================================================================
-- SCRIPT DE MIGRACIÓN: GESTIÓN DE FINANZAS Y SUSCRIPCIONES MULTI-TENANT
-- ============================================================================

-- 1. Tabla de Configuración de Pagos por Empresa/Entrenador
CREATE TABLE IF NOT EXISTS public.config_pagos_empresa (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "IDEmpresa" TEXT UNIQUE NOT NULL,
    pasarela TEXT DEFAULT 'manual' NOT NULL, -- 'manual', 'stripe', 'mercadopago'
    public_key TEXT,
    secret_key_encrypted TEXT,
    stripe_account_id TEXT,
    openai_api_key TEXT,
    whatsapp_api_key TEXT,
    mercadopago_access_token TEXT,
    stripe_secret_key TEXT,
    moneda TEXT DEFAULT 'MXN' NOT NULL,
    monto_default NUMERIC(10, 2) DEFAULT 499.00 NOT NULL,
    instrucciones_transferencia TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Asegurar columnas si la tabla ya existía
ALTER TABLE public.config_pagos_empresa ADD COLUMN IF NOT EXISTS openai_api_key TEXT;
ALTER TABLE public.config_pagos_empresa ADD COLUMN IF NOT EXISTS whatsapp_api_key TEXT;
ALTER TABLE public.config_pagos_empresa ADD COLUMN IF NOT EXISTS mercadopago_access_token TEXT;
ALTER TABLE public.config_pagos_empresa ADD COLUMN IF NOT EXISTS stripe_secret_key TEXT;

ALTER TABLE public.config_pagos_empresa ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS para config_pagos_empresa
DROP POLICY IF EXISTS "Lectura y gestion de config_pagos_empresa" ON public.config_pagos_empresa;
CREATE POLICY "Lectura y gestion de config_pagos_empresa" ON public.config_pagos_empresa
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u."userID" = auth.uid() 
              AND (u."IDEmpresa" = config_pagos_empresa."IDEmpresa" OR u.is_admin = TRUE OR u."superAdmin" = TRUE)
        )
    );

-- Permitir inserción para admins
DROP POLICY IF EXISTS "Permitir insercion config_pagos_empresa" ON public.config_pagos_empresa;
CREATE POLICY "Permitir insercion config_pagos_empresa" ON public.config_pagos_empresa
    FOR INSERT WITH CHECK (true);


-- 2. Tabla de Suscripciones por Cliente
CREATE TABLE IF NOT EXISTS public.cliente_suscripciones (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cliente_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL UNIQUE,
    "IDEmpresa" TEXT NOT NULL,
    monto_mensualidad NUMERIC(10, 2) DEFAULT 499.00 NOT NULL,
    proxima_fecha_pago DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '30 days'),
    estatus TEXT DEFAULT 'al_corriente' NOT NULL, -- 'al_corriente', 'pendiente', 'atrasado', 'suspendido'
    dias_gracia INTEGER DEFAULT 3 NOT NULL,
    notas TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.cliente_suscripciones ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS para cliente_suscripciones
DROP POLICY IF EXISTS "Lectura propia de suscripcion" ON public.cliente_suscripciones;
CREATE POLICY "Lectura propia de suscripcion" ON public.cliente_suscripciones
    FOR SELECT USING (
        auth.uid() = cliente_id OR 
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u."userID" = auth.uid() 
              AND (u."IDEmpresa" = cliente_suscripciones."IDEmpresa" OR u.is_admin = TRUE OR u."superAdmin" = TRUE)
        )
    );

DROP POLICY IF EXISTS "Gestion de suscripciones por entrenador y admin" ON public.cliente_suscripciones;
CREATE POLICY "Gestion de suscripciones por entrenador y admin" ON public.cliente_suscripciones
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u."userID" = auth.uid() 
              AND (u."IDEmpresa" = cliente_suscripciones."IDEmpresa" OR u.is_admin = TRUE OR u."superAdmin" = TRUE)
        )
    );

DROP POLICY IF EXISTS "Permitir insercion de suscripciones" ON public.cliente_suscripciones;
CREATE POLICY "Permitir insercion de suscripciones" ON public.cliente_suscripciones
    FOR INSERT WITH CHECK (true);


-- 3. Asegurar columna next_payment_date en la tabla users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS next_payment_date TIMESTAMP WITH TIME ZONE;

-- Auto-insertar suscripciones por defecto para clientes existentes en users que no la tengan
INSERT INTO public.cliente_suscripciones (cliente_id, "IDEmpresa", monto_mensualidad, proxima_fecha_pago)
SELECT 
    u."userID", 
    COALESCE(u."IDEmpresa", 'GENERAL'), 
    499.00,
    COALESCE(u.next_payment_date::date, CURRENT_DATE + INTERVAL '30 days')
FROM public.users u
WHERE u.is_admin = FALSE AND (u."superAdmin" IS NOT TRUE OR u."superAdmin" IS NULL)
  AND NOT EXISTS (
      SELECT 1 FROM public.cliente_suscripciones s WHERE s.cliente_id = u."userID"
  )
ON CONFLICT (cliente_id) DO NOTHING;


-- 4. Tabla de Registro de Pagos e Historial de Clientes
CREATE TABLE IF NOT EXISTS public.registro_pagos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "IDEmpresa" TEXT NOT NULL,
    cliente_id UUID REFERENCES public.users("userID") ON DELETE SET NULL,
    monto DOUBLE PRECISION NOT NULL,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    tipo TEXT NOT NULL, -- 'cliente_a_entrenador' o 'entrenador_a_plataforma'
    concepto TEXT DEFAULT 'Mensualidad' NOT NULL
);

ALTER TABLE public.registro_pagos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Clientes leen sus propios pagos" ON public.registro_pagos;
CREATE POLICY "Clientes leen sus propios pagos" ON public.registro_pagos
    FOR SELECT USING (
        auth.uid() = cliente_id OR
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u."userID" = auth.uid() 
              AND (u."IDEmpresa" = registro_pagos."IDEmpresa" OR u.is_admin = TRUE OR u."superAdmin" = TRUE)
        )
    );

DROP POLICY IF EXISTS "Permitir insercion para admins y usuarios" ON public.registro_pagos;
CREATE POLICY "Permitir insercion para admins y usuarios" ON public.registro_pagos
    FOR INSERT WITH CHECK (true);

