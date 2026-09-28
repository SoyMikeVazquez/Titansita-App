-- ============================================================================
-- 00. SCRIPT DE CREACIÓN DE TABLAS BASE Y USUARIOS (Ejecutar ANTES que cualquier otro script)
-- ============================================================================

-- 1. Crear tabla de USUARIOS (Perfiles ligados a auth.users de Supabase Auth)
CREATE TABLE IF NOT EXISTS public.users (
    "userID" UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    email TEXT,
    name TEXT NOT NULL,
    weight DOUBLE PRECISION,
    initial_weight DOUBLE PRECISION,
    target_weight DOUBLE PRECISION,
    height DOUBLE PRECISION,
    age INTEGER,
    is_admin BOOLEAN DEFAULT FALSE NOT NULL,
    "IDEmpresa" TEXT,
    "superAdmin" BOOLEAN DEFAULT FALSE,
    inhabilitado BOOLEAN DEFAULT FALSE NOT NULL,
    next_payment_date TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW() + INTERVAL '30 days'),
    questionnaire_answers JSONB DEFAULT '[]'::jsonb
);

-- 2. Crear tabla de EJERCICIOS ESTABLECIDOS (Rutinas asignadas)
CREATE TABLE IF NOT EXISTS public.ejercicios_establecidos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    sets INTEGER NOT NULL,
    reps INTEGER NOT NULL,
    weight DOUBLE PRECISION,
    day_of_week TEXT DEFAULT 'Lunes' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. Crear tabla de COMIDAS (Registros de comida del cliente)
CREATE TABLE IF NOT EXISTS public.comidas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    consumed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    name TEXT NOT NULL,
    calories INTEGER NOT NULL,
    protein DOUBLE PRECISION NOT NULL,
    carbs DOUBLE PRECISION NOT NULL,
    fat DOUBLE PRECISION NOT NULL,
    image_url TEXT
);

-- 4. Crear tabla de RESULTADOS DESTACADOS (Transformaciones)
CREATE TABLE IF NOT EXISTS public.featured_results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    client_name TEXT NOT NULL,
    achievement TEXT NOT NULL,
    before_image_url TEXT,
    after_image_url TEXT
);

-- 5. Crear tabla de RECETAS (Recetario)
CREATE TABLE IF NOT EXISTS public.recipes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    title TEXT NOT NULL,
    calories INTEGER NOT NULL,
    protein DOUBLE PRECISION NOT NULL,
    carbs DOUBLE PRECISION NOT NULL,
    fat DOUBLE PRECISION NOT NULL,
    time TEXT NOT NULL,
    difficulty TEXT NOT NULL,
    image_url TEXT,
    ingredients TEXT[] NOT NULL,
    steps TEXT[] NOT NULL
);

-- Habilitar RLS para seguridad de datos básica
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir lectura publica" ON public.users;
CREATE POLICY "Permitir lectura publica" ON public.users FOR SELECT USING (true);
DROP POLICY IF EXISTS "Permitir modificacion propia" ON public.users;
CREATE POLICY "Permitir modificacion propia" ON public.users FOR UPDATE USING (auth.uid() = "userID");

ALTER TABLE public.ejercicios_establecidos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir lectura publica" ON public.ejercicios_establecidos;
CREATE POLICY "Permitir lectura publica" ON public.ejercicios_establecidos FOR SELECT USING (true);

ALTER TABLE public.comidas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir lectura publica" ON public.comidas;
CREATE POLICY "Permitir lectura publica" ON public.comidas FOR SELECT USING (true);
DROP POLICY IF EXISTS "Permitir insercion propia" ON public.comidas;
CREATE POLICY "Permitir insercion propia" ON public.comidas FOR INSERT WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.featured_results ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir lectura publica" ON public.featured_results;
CREATE POLICY "Permitir lectura publica" ON public.featured_results FOR SELECT USING (true);
DROP POLICY IF EXISTS "Permitir insercion publica" ON public.featured_results;
CREATE POLICY "Permitir insercion publica" ON public.featured_results FOR INSERT WITH CHECK (true);

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir lectura publica" ON public.recipes;
CREATE POLICY "Permitir lectura publica" ON public.recipes FOR SELECT USING (true);
DROP POLICY IF EXISTS "Permitir insercion publica" ON public.recipes;
CREATE POLICY "Permitir insercion publica" ON public.recipes FOR INSERT WITH CHECK (true);

-- Función y trigger para creación automática de perfiles en public.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users ("userID", email, name, is_admin, weight, initial_weight, target_weight, height, age)
    VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'name', 'Nuevo Usuario'),
        COALESCE((new.raw_user_meta_data->>'is_admin')::boolean, FALSE),
        COALESCE((new.raw_user_meta_data->>'weight')::numeric::double precision, 70.0),
        COALESCE((new.raw_user_meta_data->>'initial_weight')::numeric::double precision, 70.0),
        COALESCE((new.raw_user_meta_data->>'target_weight')::numeric::double precision, 65.0),
        COALESCE((new.raw_user_meta_data->>'height')::numeric::double precision, 170.0),
        COALESCE((new.raw_user_meta_data->>'age')::integer, 25)
    );
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Insertar datos iniciales de demostración
INSERT INTO public.featured_results (client_name, achievement) VALUES
('Sofía G.', 'Bajó 12 kg en 3 meses y duplicó su fuerza en sentadillas.'),
('Alejandro M.', 'Aumentó 6 kg de masa muscular magra y redujo grasa al 10%.'),
('Natalia P.', 'Completó su primer medio maratón reduciendo dolores articulares.');
