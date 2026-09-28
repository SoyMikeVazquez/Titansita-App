-- ============================================================================
-- SCRIPT PARA CREAR EL PRIMER SUPER ADMINISTRADOR
-- Ejecútalo en el SQL Editor de tu Supabase.
-- ============================================================================

-- 1. Habilitar pgcrypto si no está habilitado (necesario para encriptar la contraseña)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Insertar el usuario en la tabla auth.users (Autenticación de Supabase)
DO $$
DECLARE
    new_user_id UUID := gen_random_uuid();
BEGIN
    -- Verificar si ya existe el usuario para no duplicarlo
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@titansita.com') THEN
        INSERT INTO auth.users (
            id,
            instance_id,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            email_change,
            email_change_token_new,
            recovery_token,
            aud,
            role
        ) VALUES (
            new_user_id,
            '00000000-0000-0000-0000-000000000000',
            'admin@titansita.com',
            crypt('Titansita2026', gen_salt('bf')), -- Contraseña: Titansita2026
            now(), -- Confirma el correo automáticamente
            '{"provider": "email", "providers": ["email"]}',
            '{"name": "Super Admin Titansita"}',
            now(),
            now(),
            '',
            '',
            '',
            '',
            'authenticated',
            'authenticated'
        );

        -- NOTA: El trigger handle_new_user() que creamos en el script 00 
        -- automáticamente insertará este usuario en public.users.
        -- Pero ahora le damos explícitamente los permisos de superAdmin:
        
        UPDATE public.users 
        SET 
            is_admin = true, 
            "superAdmin" = true 
        WHERE email = 'admin@titansita.com';
        
    END IF;
END $$;
