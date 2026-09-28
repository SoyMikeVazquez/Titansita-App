-- ============================================================================
-- SCRIPT PARA INSERTAR DATOS DE PRUEBA (CONTENIDO DE LA APP)
-- Ejecútalo en el SQL Editor de tu Supabase.
-- ============================================================================

-- 1. Limpiar datos anteriores (opcional, por si lo corres múltiples veces)
DELETE FROM public.featured_results;
DELETE FROM public.recipes;
DELETE FROM public.news;

-- 2. Insertar Transformaciones Destacadas (Usando fotos de assets/fotoslogin)
INSERT INTO public.featured_results (client_name, achievement, before_image_url, after_image_url) VALUES 
('Carlos M.', 'Ganó 5kg de masa muscular en 3 meses.', NULL, 'https://ffbjqwvadxnqrbxnysjl.supabase.co/storage/v1/object/public/general/fotoslogin/385035913_18294447586193915_236877727834713594_n.jpg'),
('Ana L.', 'Redujo 10% grasa corporal y tonificó todo el cuerpo.', NULL, 'https://ffbjqwvadxnqrbxnysjl.supabase.co/storage/v1/object/public/general/fotoslogin/410652433_18305924488193915_1129043350412617051_n.jpg'),
('Diego S.', 'Mejoró su resistencia cardiovascular para correr un maratón.', NULL, 'https://ffbjqwvadxnqrbxnysjl.supabase.co/storage/v1/object/public/general/fotoslogin/417844490_18309237490193915_6435129336545725501_n.jpg');

-- 3. Insertar Recetario Saludable (Usando fotos de assets/fotoslogin)
INSERT INTO public.recipes (title, calories, protein, carbs, fat, time, difficulty, image_url, ingredients, steps) VALUES
('Bowl Proteico de Avena', 450, 30.5, 40.0, 15.0, '15 min', 'Fácil', 'https://ffbjqwvadxnqrbxnysjl.supabase.co/storage/v1/object/public/general/fotoslogin/622448595_18077963861362876_536681444998067018_n.jpg', ARRAY['Avena', 'Huevos', 'Plátano', 'Crema de maní'], ARRAY['Mezclar la avena', 'Cocinar los huevos', 'Servir con frutas']),
('Almuerzo Fit de Pollo y Arroz', 600, 45.0, 50.0, 20.0, '30 min', 'Medio', 'https://ffbjqwvadxnqrbxnysjl.supabase.co/storage/v1/object/public/general/fotoslogin/626155270_18106313023809488_8954044703489099676_n.jpg', ARRAY['Pechuga de Pollo', 'Arroz integral', 'Brócoli'], ARRAY['Sazonar el pollo', 'Hervir el arroz', 'Servir con vegetales']),
('Cena Ligera de Salmón', 300, 25.0, 10.0, 10.0, '20 min', 'Fácil', 'https://ffbjqwvadxnqrbxnysjl.supabase.co/storage/v1/object/public/general/fotoslogin/629882963_18398874685183708_9194550262749528527_n.jpg', ARRAY['Filete de Salmón', 'Espárragos', 'Limón'], ARRAY['Marinar salmón', 'Hornear a 200°C por 15 min', 'Servir']);

-- 4. Insertar Novedades / Noticias (Usando fotos de assets/fotoslogin)
INSERT INTO public.news (title, content, image_url, author_name) VALUES
('¡Nueva Rutina de Verano!', 'Prepárate para la playa con esta rutina extrema enfocada en core y piernas. Entra a tus rutinas asignadas para verla.', 'https://ffbjqwvadxnqrbxnysjl.supabase.co/storage/v1/object/public/general/fotoslogin/637748682_18560329423009209_2138153405911386858_n.jpg', 'Titansita'),
('Desafío de 30 Días', 'Únete al nuevo desafío grupal y transforma tu cuerpo en solo un mes con nuestro acompañamiento.', 'https://ffbjqwvadxnqrbxnysjl.supabase.co/storage/v1/object/public/general/fotoslogin/640382323_18573634759056247_5441525226785008867_n.jpg', 'Titansita');
