-- 1. TABLA DE OBJETIVOS
CREATE TABLE IF NOT EXISTS public.objetivos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT false,
    "IDEmpresa" TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.objetivos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura propia y admin de objetivos" ON public.objetivos;
CREATE POLICY "Lectura propia y admin de objetivos" ON public.objetivos 
    FOR SELECT USING (
        auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND (is_admin = TRUE OR "superAdmin" = TRUE))
    );

DROP POLICY IF EXISTS "Admin puede gestionar objetivos" ON public.objetivos;
CREATE POLICY "Admin puede gestionar objetivos" ON public.objetivos 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND (is_admin = TRUE OR "superAdmin" = TRUE))
    );

DROP POLICY IF EXISTS "Usuario puede actualizar sus objetivos" ON public.objetivos;
CREATE POLICY "Usuario puede actualizar sus objetivos" ON public.objetivos
    FOR UPDATE USING (
        auth.uid() = user_id
    );


-- 2. TABLA DE RUTINAS ASIGNADAS
CREATE TABLE IF NOT EXISTS public.rutinas_asignadas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    routine_id UUID NOT NULL,
    routine_name TEXT NOT NULL,
    assigned_date TIMESTAMP WITH TIME ZONE NOT NULL,
    exercise_id UUID,
    exercise_name TEXT NOT NULL,
    exercise_gif_url TEXT,
    series INTEGER,
    reps INTEGER,
    completed BOOLEAN DEFAULT false,
    "IDEmpresa" TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.rutinas_asignadas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura propia y admin de rutinas asignadas" ON public.rutinas_asignadas;
CREATE POLICY "Lectura propia y admin de rutinas asignadas" ON public.rutinas_asignadas 
    FOR SELECT USING (
        auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND (is_admin = TRUE OR "superAdmin" = TRUE))
    );

DROP POLICY IF EXISTS "Admin puede gestionar rutinas asignadas" ON public.rutinas_asignadas;
CREATE POLICY "Admin puede gestionar rutinas asignadas" ON public.rutinas_asignadas 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND (is_admin = TRUE OR "superAdmin" = TRUE))
    );

DROP POLICY IF EXISTS "Usuario puede actualizar sus rutinas asignadas" ON public.rutinas_asignadas;
CREATE POLICY "Usuario puede actualizar sus rutinas asignadas" ON public.rutinas_asignadas
    FOR UPDATE USING (
        auth.uid() = user_id
    );
