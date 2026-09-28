-- ============================================================================
-- SCRIPT DE CONFIGURACIÓN DE BASE DE DATOS Y ALMACENAMIENTO DE SUPABASE
-- Pega este script completo en el Editor SQL de tu consola de Supabase y ejecútalo.
-- ============================================================================

-- 1. Asegurar la existencia del bucket público 'general' para imágenes/GIFs
INSERT INTO storage.buckets (id, name, public)
VALUES ('general', 'general', true)
ON CONFLICT (id) DO NOTHING;

-- Configurar políticas de almacenamiento para el bucket general
-- Permitir acceso de lectura público a todo
DROP POLICY IF EXISTS "Permitir lectura publica de almacenamiento" ON storage.objects;
CREATE POLICY "Permitir lectura publica de almacenamiento" ON storage.objects
    FOR SELECT USING (bucket_id = 'general');

-- Permitir inserción de archivos a usuarios autenticados
DROP POLICY IF EXISTS "Permitir insercion de archivos autenticados" ON storage.objects;
CREATE POLICY "Permitir insercion de archivos autenticados" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'general');

-- Permitir eliminación y actualización a usuarios autenticados
DROP POLICY IF EXISTS "Permitir gestion de archivos autenticados" ON storage.objects;
CREATE POLICY "Permitir gestion de archivos autenticados" ON storage.objects
    FOR UPDATE USING (bucket_id = 'general');

DROP POLICY IF EXISTS "Permitir eliminacion de archivos autenticados" ON storage.objects;
CREATE POLICY "Permitir eliminacion de archivos autenticados" ON storage.objects
    FOR DELETE USING (bucket_id = 'general');


-- 2. Tabla del Catálogo Global de Ejercicios
CREATE TABLE IF NOT EXISTS public.ejercicios (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    image_url TEXT
);

ALTER TABLE public.ejercicios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura publica de ejercicios" ON public.ejercicios;
CREATE POLICY "Lectura publica de ejercicios" ON public.ejercicios 
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin puede gestionar ejercicios" ON public.ejercicios;
CREATE POLICY "Admin puede gestionar ejercicios" ON public.ejercicios 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );


-- 3. Tabla de Rutinas Asignadas a Clientes
CREATE TABLE IF NOT EXISTS public.rutinas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    assigned_date DATE,
    share_code TEXT UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.rutinas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura propia y admin de rutinas" ON public.rutinas;
CREATE POLICY "Lectura propia y admin de rutinas" ON public.rutinas 
    FOR SELECT USING (
        auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

DROP POLICY IF EXISTS "Admin puede gestionar rutinas" ON public.rutinas;
CREATE POLICY "Admin puede gestionar rutinas" ON public.rutinas 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );


-- 4. Tabla de Relación Rutina-Ejercicios (Junction Table)
CREATE TABLE IF NOT EXISTS public.rutina_ejercicios (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    routine_id UUID REFERENCES public.rutinas(id) ON DELETE CASCADE NOT NULL,
    exercise_id UUID REFERENCES public.ejercicios(id) ON DELETE CASCADE NOT NULL,
    sets INTEGER NOT NULL DEFAULT 3,
    reps INTEGER NOT NULL DEFAULT 10,
    series_weights DOUBLE PRECISION[] NOT NULL,
    series_type TEXT DEFAULT 'Normal' NOT NULL, -- 'Normal', 'Biserie', 'Triserie', 'Superset'
    sort_order INTEGER DEFAULT 0 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.rutina_ejercicios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura propia y admin de rutina_ejercicios" ON public.rutina_ejercicios;
CREATE POLICY "Lectura propia y admin de rutina_ejercicios" ON public.rutina_ejercicios 
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.rutinas r 
            WHERE r.id = routine_id 
              AND (r.user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.users u WHERE u."userID" = auth.uid() AND u.is_admin = TRUE))
        )
    );

DROP POLICY IF EXISTS "Admin puede gestionar rutina_ejercicios" ON public.rutina_ejercicios;
CREATE POLICY "Admin puede gestionar rutina_ejercicios" ON public.rutina_ejercicios 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );


-- 5. Insertar Ejercicios Semilla por defecto (Si no existen)
INSERT INTO public.ejercicios (name, description, image_url) VALUES
('Sentadilla libre con barra', 'Coloca la barra sobre los trapecios, desciende rompiendo el paralelo de la cadera y sube extendiendo rodillas.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/barbell-full-squat.gif'),
('Prensa de piernas inclinada', 'Empuja la plataforma con los pies separados al ancho de hombros, flexionando a 90 grados y extendiendo con fuerza.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/sled-45-leg-press.gif'),
('Zancadas búlgaras con mancuerna', 'Apoya un pie atrás sobre un banco, desciende la cadera de forma vertical controlando con el cuádriceps delantero.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/quads/dumbbell-single-leg-split-squat.gif'),
('Extensión de cuádriceps en máquina', 'Extiende por completo las piernas apretando los muslos en la parte alta de la contracción en la máquina.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/quads/lever-leg-extension.gif'),
('Peso Muerto Rumano', 'Mantén espalda recta y realiza bisagra de cadera descendiendo la barra pegada a los muslos.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/hamstrings/barbell-romanian-deadlift.gif'),
('Press de banca plano', 'Desciende la barra rozando el pectoral y empuja verticalmente de manera explosiva.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/chest/barbell-bench-press.gif'),
('Calentamiento General', 'Movilidad articular activa o caminata ligera inclinada durante 5 a 10 minutos.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/cardio/walking-on-incline-treadmill.gif')
ON CONFLICT (name) DO UPDATE SET 
    description = EXCLUDED.description,
    image_url = EXCLUDED.image_url;


-- ============================================================================
-- 6. TABLA DE PREGUNTAS DE REGISTRO (Cuestionario inicial)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.registration_questions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    question_text TEXT NOT NULL,
    is_required BOOLEAN DEFAULT TRUE NOT NULL,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_by UUID REFERENCES public.users("userID") ON DELETE SET NULL
);

ALTER TABLE public.registration_questions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura publica de preguntas" ON public.registration_questions;
CREATE POLICY "Lectura publica de preguntas" ON public.registration_questions 
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin puede gestionar preguntas" ON public.registration_questions;
CREATE POLICY "Admin puede gestionar preguntas" ON public.registration_questions 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

-- Añadir columna JSONB en la tabla de usuarios para guardar las respuestas del cuestionario
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS questionnaire_answers JSONB DEFAULT '[]'::jsonb;

-- Insertar preguntas de registro iniciales de forma segura
INSERT INTO public.registration_questions (question_text, is_required, sort_order)
SELECT q_text, is_req, s_ord
FROM (VALUES
    ('¿Cuál es tu objetivo principal? (Perder peso, ganar masa muscular, mejorar resistencia, etc.)', TRUE, 1),
    ('¿Tienes alguna lesión o condición médica que debamos considerar?', TRUE, 2),
    ('¿Con qué frecuencia haces ejercicio actualmente? (Días por semana)', TRUE, 3),
    ('¿Tienes alguna alergia o restricción alimentaria?', FALSE, 4)
) AS seed(q_text, is_req, s_ord)
WHERE NOT EXISTS (
    SELECT 1 FROM public.registration_questions WHERE question_text = seed.q_text
);


-- ============================================================================
-- 7. TABLA DE NOVEDADES (News y tips del Coach)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.news (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    author_name TEXT DEFAULT 'Entrenador' NOT NULL
);

ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura publica de novedades" ON public.news;
CREATE POLICY "Lectura publica de novedades" ON public.news 
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin puede gestionar novedades" ON public.news;
CREATE POLICY "Admin puede gestionar novedades" ON public.news 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

-- Insertar novedades iniciales semilla
INSERT INTO public.news (title, content, author_name, image_url)
SELECT title_val, content_val, author_val, image_val
FROM (VALUES
    ('Rutina HIIT Quema Grasa', 'Nueva rutina de 20 minutos de alta intensidad disponible. ¡Ideal para complementar tu cardio diario!', 'Coach Carlos', 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=600'),
    ('La Importancia de la Proteína', 'Consumir suficiente proteína post-entrenamiento ayuda a reparar las fibras musculares. Intenta consumir 20-30g de proteína en las primeras 2 horas.', 'Nutri. Sofía', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=600'),
    ('¡Evita lesiones! Calentamiento dinámico', 'Nunca olvides el calentamiento. Dedica al menos 8-10 minutos a la movilidad articular antes de comenzar a levantar peso pesado.', 'Coach Carlos', 'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&q=80&w=600')
) AS seed(title_val, content_val, author_val, image_val)
WHERE NOT EXISTS (
    SELECT 1 FROM public.news WHERE title = seed.title_val
);


-- ============================================================================
-- 8. TABLA DE RECETAS ASIGNADAS (Plan dietético diario)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.assigned_recipes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    recipe_id UUID REFERENCES public.recipes(id) ON DELETE CASCADE NOT NULL,
    assigned_date DATE NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE (user_id, recipe_id, assigned_date)
);

ALTER TABLE public.assigned_recipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura propia y admin de recetas asignadas" ON public.assigned_recipes;
CREATE POLICY "Lectura propia y admin de recetas asignadas" ON public.assigned_recipes 
    FOR SELECT USING (
        auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

DROP POLICY IF EXISTS "Admin puede gestionar recetas asignadas" ON public.assigned_recipes;
CREATE POLICY "Admin puede gestionar recetas asignadas" ON public.assigned_recipes 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );
-- Migración para añadir columna de fecha asignada a rutinas existentes
ALTER TABLE public.rutinas ADD COLUMN IF NOT EXISTS assigned_date DATE;

-- ============================================================================
-- 9. TABLA DE REGISTROS DE MEDIDAS (Progreso de Clientes)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.registros_medidas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    weight DOUBLE PRECISION NOT NULL,
    abdomen DOUBLE PRECISION NOT NULL,
    waist DOUBLE PRECISION NOT NULL,
    leg DOUBLE PRECISION NOT NULL,
    chest DOUBLE PRECISION NOT NULL,
    arm DOUBLE PRECISION NOT NULL,
    calf DOUBLE PRECISION NOT NULL,
    cuello DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    photo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.registros_medidas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura propia y admin de registros_medidas" ON public.registros_medidas;
CREATE POLICY "Lectura propia y admin de registros_medidas" ON public.registros_medidas 
    FOR SELECT USING (
        auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

DROP POLICY IF EXISTS "Usuarios pueden insertar sus propios registros" ON public.registros_medidas;
CREATE POLICY "Usuarios pueden insertar sus propios registros" ON public.registros_medidas 
    FOR INSERT WITH CHECK (
        auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

DROP POLICY IF EXISTS "Usuarios pueden eliminar sus propios registros" ON public.registros_medidas;
CREATE POLICY "Usuarios pueden eliminar sus propios registros" ON public.registros_medidas 
    FOR DELETE USING (
        auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

-- Migración por si la tabla ya existía pero le faltaban columnas:
ALTER TABLE public.registros_medidas ADD COLUMN IF NOT EXISTS cuello DOUBLE PRECISION DEFAULT 0.0 NOT NULL;
ALTER TABLE public.registros_medidas ADD COLUMN IF NOT EXISTS weight DOUBLE PRECISION;
ALTER TABLE public.registros_medidas ADD COLUMN IF NOT EXISTS abdomen DOUBLE PRECISION;
ALTER TABLE public.registros_medidas ADD COLUMN IF NOT EXISTS waist DOUBLE PRECISION;
ALTER TABLE public.registros_medidas ADD COLUMN IF NOT EXISTS leg DOUBLE PRECISION;
ALTER TABLE public.registros_medidas ADD COLUMN IF NOT EXISTS chest DOUBLE PRECISION;
ALTER TABLE public.registros_medidas ADD COLUMN IF NOT EXISTS arm DOUBLE PRECISION;
ALTER TABLE public.registros_medidas ADD COLUMN IF NOT EXISTS calf DOUBLE PRECISION;
ALTER TABLE public.registros_medidas ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Migración para añadir share_code a rutinas existentes:
ALTER TABLE public.rutinas ADD COLUMN IF NOT EXISTS share_code TEXT UNIQUE;

-- 10. Tabla de Chat/Análisis con I.A. para Clientes
CREATE TABLE IF NOT EXISTS public.chat_ia_clientes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    coach_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.chat_ia_clientes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura propia y coach de chat ia" ON public.chat_ia_clientes;
CREATE POLICY "Lectura propia y coach de chat ia" ON public.chat_ia_clientes
    FOR SELECT USING (
        auth.uid() = client_id OR auth.uid() = coach_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

DROP POLICY IF EXISTS "Cualquier usuario autenticado puede insertar en chat ia" ON public.chat_ia_clientes;
CREATE POLICY "Cualquier usuario autenticado puede insertar en chat ia" ON public.chat_ia_clientes
    FOR INSERT WITH CHECK (
        auth.uid() = client_id OR auth.uid() = coach_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );


-- ============================================================================
-- 11. TABLA DE LOGROS DE LA COMUNIDAD (community_posts) & FUNCIONES RPC
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.community_posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    image_url TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    id_user UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    visualizaciones INTEGER DEFAULT 0 NOT NULL,
    likes INTEGER DEFAULT 0 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura publica de logros de comunidad" ON public.community_posts;
CREATE POLICY "Lectura publica de logros de comunidad" ON public.community_posts
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar sus logros" ON public.community_posts;
CREATE POLICY "Usuarios autenticados pueden insertar sus logros" ON public.community_posts
    FOR INSERT WITH CHECK (auth.uid() = id_user);

DROP POLICY IF EXISTS "Usuarios pueden actualizar sus propios logros o admin" ON public.community_posts;
CREATE POLICY "Usuarios pueden actualizar sus propios logros o admin" ON public.community_posts
    FOR UPDATE USING (
        auth.uid() = id_user OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

DROP POLICY IF EXISTS "Usuarios pueden eliminar sus propios logros o admin" ON public.community_posts;
CREATE POLICY "Usuarios pueden eliminar sus propios logros o admin" ON public.community_posts
    FOR DELETE USING (
        auth.uid() = id_user OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

-- Función para incrementar vistas de post de comunidad
CREATE OR REPLACE FUNCTION public.increment_community_post_views(post_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.community_posts
    SET visualizaciones = visualizaciones + 1
    WHERE id = post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para incrementar likes de post de comunidad
CREATE OR REPLACE FUNCTION public.increment_community_post_likes(post_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.community_posts
    SET likes = likes + 1
    WHERE id = post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 12. TABLA DE HISTORIAL DE ENTRENAMIENTOS (historial_entrenamientos)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.historial_entrenamientos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    routine_id UUID, -- Guarda el ID de la rutina asignada o plantilla sin restricción de FK para evitar conflictos
    routine_name TEXT NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    duration_seconds INTEGER NOT NULL,
    total_volume DOUBLE PRECISION NOT NULL,
    total_sets INTEGER NOT NULL,
    logged_exercises JSONB NOT NULL
);

ALTER TABLE public.historial_entrenamientos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura propia y admin de historial" ON public.historial_entrenamientos;
CREATE POLICY "Lectura propia y admin de historial" ON public.historial_entrenamientos
    FOR SELECT USING (
        auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

DROP POLICY IF EXISTS "Insercion propia de historial" ON public.historial_entrenamientos;
CREATE POLICY "Insercion propia de historial" ON public.historial_entrenamientos
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
    );

DROP POLICY IF EXISTS "Admin puede actualizar o borrar historial" ON public.historial_entrenamientos;
CREATE POLICY "Admin puede actualizar o borrar historial" ON public.historial_entrenamientos
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );


-- ============================================================================
-- 13. TABLA DE ENTRENADORES REGISTRADOS (EmpresasEntrenadores) & FACTURACIÓN
-- ============================================================================
CREATE TABLE IF NOT EXISTS public."EmpresasEntrenadores" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "userID" UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    correo_electronico TEXT NOT NULL,
    telefono NUMERIC NOT NULL,
    especialidad TEXT DEFAULT '' NOT NULL,
    bio TEXT DEFAULT '' NOT NULL,
    estado TEXT DEFAULT 'activo' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Asegurar existencia de nuevas columnas de cobro y empresa
ALTER TABLE public."EmpresasEntrenadores" ADD COLUMN IF NOT EXISTS "IDEmpresa" UUID;
ALTER TABLE public."EmpresasEntrenadores" ADD COLUMN IF NOT EXISTS "foto perfil" TEXT;
ALTER TABLE public."EmpresasEntrenadores" ADD COLUMN IF NOT EXISTS fecha_pago TIMESTAMP WITH TIME ZONE;
ALTER TABLE public."EmpresasEntrenadores" ADD COLUMN IF NOT EXISTS modalidad_pago TEXT;
ALTER TABLE public."EmpresasEntrenadores" ADD COLUMN IF NOT EXISTS proximo_pago TIMESTAMP WITH TIME ZONE;
ALTER TABLE public."EmpresasEntrenadores" ADD COLUMN IF NOT EXISTS montodecobro_mensual DOUBLE PRECISION;

ALTER TABLE public."EmpresasEntrenadores" ENABLE ROW LEVEL SECURITY;

-- Limpieza y creación de políticas
DROP POLICY IF EXISTS "Lectura publica de entrenadores" ON public."EmpresasEntrenadores";
DROP POLICY IF EXISTS "Admin puede gestionar entrenadores" ON public."EmpresasEntrenadores";

DROP POLICY IF EXISTS "Lectura publica de entrenadores" ON public."EmpresasEntrenadores";
CREATE POLICY "Lectura publica de entrenadores" ON public."EmpresasEntrenadores"
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin puede gestionar entrenadores" ON public."EmpresasEntrenadores";
CREATE POLICY "Admin puede gestionar entrenadores" ON public."EmpresasEntrenadores"
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
    );

-- ============================================================================
-- 14. INHABILITACIÓN DE USUARIOS
-- ============================================================================
-- Asegurar existencia de columna inhabilitado en la tabla de usuarios
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS inhabilitado BOOLEAN DEFAULT FALSE NOT NULL;


-- ============================================================================
-- 15. TABLA DE REGISTRO DE PAGOS (Para finanzas de entrenadores y plataforma)
-- ============================================================================
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

DROP POLICY IF EXISTS "Permitir lectura para admins y superAdmins" ON public.registro_pagos;
CREATE POLICY "Permitir lectura para admins y superAdmins" ON public.registro_pagos
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE "userID" = auth.uid() 
              AND (is_admin = TRUE OR "superAdmin" = TRUE)
        )
    );

DROP POLICY IF EXISTS "Permitir insercion para admins" ON public.registro_pagos;
CREATE POLICY "Permitir insercion para admins" ON public.registro_pagos
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE "userID" = auth.uid() 
              AND is_admin = TRUE
        )
    );





