import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/news_item.dart';
import '../models/user_profile.dart';
import '../models/community_post.dart';
import '../models/meal_item.dart';
import '../models/established_exercise.dart';
import '../models/registration_question.dart';
import '../models/measurement_record.dart';
import '../models/exercise.dart';
import '../models/routine_exercise.dart';
import '../models/routine.dart';
import '../models/workout_log.dart';
import '../models/recipe.dart';
import '../models/assigned_recipe.dart';
import '../models/assigned_routine.dart';
import '../models/client_objective.dart';
import '../models/trainer.dart';
import '../models/client_subscription.dart';
import '../models/payment_config.dart';
import '../utils/exercise_gifs.dart';
import '../models/client_ai_chat.dart';
import '../models/notification.dart';
import '../screens/api_key_screen.dart';
import 'dart:convert';
import '../models/product.dart';


class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static String? pendingShareCode;

  bool _isInitialized = false;
  bool get _useMockData => false;
  set _useMockData(bool value) {}
  String? _errorMessage;
  List<EstablishedExercise>? _mockExercises;
  List<ClientAiChat>? _mockClientAiChats;
  Map<String, List<MealItem>>? _mockMealsByUser;
  List<Recipe>? _mockRecipes;
  List<UserProfile>? _mockClients;
  List<NewsItem>? _mockNews;
  List<AssignedRecipe>? _mockAssignedRecipes;

  final StreamController<UserProfile?> _authStreamController =
      StreamController<UserProfile?>.broadcast();
  UserProfile? _currentUserProfile;

  UserProfile? get loggedInUserProfile => _currentUserProfile;

  Stream<UserProfile?> get authStateChangesProfile async* {
    yield _currentUserProfile;
    yield* _authStreamController.stream;
  }

  bool get useMockData => _useMockData;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  // Supabase Credentials
  static const String supabaseUrl = 'https://ffbjqwvadxnqrbxnysjl.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmYmpxd3ZhZHhucXJieG55c2psIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEwODY5MzksImV4cCI6MjA3NjY2MjkzOX0.sH2yt0Yfi1z4sdUSlSi8LEcVbQHYw-N7bZqOQYjUIX0';

  Future<bool> _isUserSuspended(String userId) async {
    try {
      final userRow = await client
          .from('users')
          .select('IDEmpresa, inhabilitado')
          .eq('userID', userId)
          .maybeSingle();

      if (userRow != null && userRow['inhabilitado'] == true) {
        return true;
      }

      if (userRow != null && userRow['IDEmpresa'] != null) {
        final trainerRow = await client
            .from('EmpresasEntrenadores')
            .select('inhabilitado')
            .eq('IDEmpresa', userRow['IDEmpresa'])
            .maybeSingle();
        if (trainerRow != null && trainerRow['inhabilitado'] == true) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: true,
        ),
      );
      _isInitialized = true;
      // removed

      // Check if session exists initially
      final initialSession = client.auth.currentSession;
      if (initialSession != null) {
        try {
          final sessionUserId = client.auth.currentUser?.id;
          if (sessionUserId != null && await _isUserSuspended(sessionUserId)) {
            await client.auth.signOut();
            _currentUserProfile = null;
            _authStreamController.add(null);
            return;
          }

          final profile = await getUserProfile();
          _currentUserProfile = profile;
          _authStreamController.add(profile);
          _migrateUnsplashUrlsToGifs(); // Run migration!
        } catch (_) {
          _currentUserProfile = _getMockUserProfile();
          _authStreamController.add(_currentUserProfile);
        }
      } else {
        _currentUserProfile = null;
        _authStreamController.add(null);
      }

      // Listen to auth changes
      client.auth.onAuthStateChange.listen((data) async {
        final Session? session = data.session;
        if (session != null) {
          try {
            final userId = session.user.id;
            if (await _isUserSuspended(userId)) {
              await client.auth.signOut();
              _currentUserProfile = null;
              _authStreamController.add(null);
              return;
            }

            final profile = await getUserProfile();
            _currentUserProfile = profile;
            _authStreamController.add(profile);
            _migrateUnsplashUrlsToGifs(); // Run migration!
          } catch (_) {
            _currentUserProfile = _getMockUserProfile();
            _authStreamController.add(_currentUserProfile);
          }
        } else {
          _currentUserProfile = null;
          _authStreamController.add(null);
        }
      });
    } catch (e) {
      _isInitialized = false;
      // removed
      _errorMessage = e.toString();
      _currentUserProfile = null;
      _authStreamController.add(null);
    }
  }

  Future<void> _migrateUnsplashUrlsToGifs() async {
    if (_useMockData || !_isInitialized) return;
    try {
      final profile = _currentUserProfile;
      if (profile != null && profile.isAdmin) {
        final dbExercises = await client.from('ejercicios').select();
        for (final ex in dbExercises) {
          final name = ex['name']?.toString() ?? '';
          final imgUrl = ex['image_url']?.toString() ?? '';
          if (imgUrl.contains('unsplash.com')) {
            final gif = ExerciseGifs.getGifUrl(name);
            if (gif != null) {
              await client
                  .from('ejercicios')
                  .update({'image_url': gif})
                  .eq('id', ex['id']);
            }
          }
        }
      }
    } catch (_) {}
  }

  void setUseMockData(bool value) {
    _useMockData = value;
  }

  SupabaseClient get client => Supabase.instance.client;

  // SQL Script to create tables
  String get sqlSetupScript => '''
-- 1. Crear tabla de USUARIOS (Perfiles ligados a auth.users de Supabase Auth)
CREATE TABLE public.users (
    "userID" UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    email TEXT,
    name TEXT NOT NULL,
    weight DOUBLE PRECISION,
    initial_weight DOUBLE PRECISION,
    target_weight DOUBLE PRECISION,
    height DOUBLE PRECISION,
    age INTEGER,
    is_admin BOOLEAN DEFAULT FALSE NOT NULL
);
-- Añadir columna de fecha de corte de pago si no existe
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS next_payment_date TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW() + INTERVAL '30 days');

-- 2. Crear tabla de EJERCICIOS ESTABLECIDOS (Rutinas asignadas)
CREATE TABLE public.ejercicios_establecidos (
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
CREATE TABLE public.comidas (
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
-- Añadir columna si ya existe la tabla
ALTER TABLE public.comidas ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 4. Crear tabla de NOVEDADES (News y tips del Coach)
CREATE TABLE public.news (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    author_name TEXT DEFAULT 'Entrenador' NOT NULL
);

-- 5. Crear tabla de RESULTADOS DESTACADOS (Transformaciones)
CREATE TABLE public.featured_results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    client_name TEXT NOT NULL,
    achievement TEXT NOT NULL,
    before_image_url TEXT,
    after_image_url TEXT
);

-- 6. Crear tabla de RECETAS (Recetario)
CREATE TABLE public.recipes (
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
CREATE POLICY "Permitir lectura publica" ON public.users FOR SELECT USING (true);
CREATE POLICY "Permitir modificacion propia" ON public.users FOR UPDATE USING (auth.uid() = "userID");

ALTER TABLE public.ejercicios_establecidos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Permitir lectura publica" ON public.ejercicios_establecidos FOR SELECT USING (true);

ALTER TABLE public.comidas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Permitir lectura publica" ON public.comidas FOR SELECT USING (true);
CREATE POLICY "Permitir insercion propia" ON public.comidas FOR INSERT WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Permitir lectura publica" ON public.news FOR SELECT USING (true);

ALTER TABLE public.featured_results ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Permitir lectura publica" ON public.featured_results FOR SELECT USING (true);
CREATE POLICY "Permitir insercion publica" ON public.featured_results FOR INSERT WITH CHECK (true);

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Permitir lectura publica" ON public.recipes FOR SELECT USING (true);
CREATE POLICY "Permitir insercion publica" ON public.recipes FOR INSERT WITH CHECK (true);

-- Función y trigger para creación automática de perfiles en public.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS \$\$
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
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Insertar datos iniciales de demostración
INSERT INTO public.news (title, content, author_name) VALUES
('Rutina HIIT Quema Grasa', 'Nueva rutina de 20 minutos de alta intensidad disponible en tu sección de entrenamientos. ¡Ideal para complementar tu cardio diario!', 'Coach Carlos'),
('La Importancia de la Proteína', 'Consumir suficiente proteína post-entrenamiento ayuda a reparar las fibras musculares. Intenta consumir 20-30g de proteína en las primeras 2 horas.', 'Nutri. Sofía'),
('Nuevo Horario de Clases', 'A partir del lunes, abrimos clase de Power Lifting a las 6:00 AM. ¡Reserva tu lugar ya!', 'Staff');

INSERT INTO public.featured_results (client_name, achievement) VALUES
('Sofía G.', 'Bajó 12 kg en 3 meses y duplicó su fuerza en sentadillas.'),
('Alejandro M.', 'Aumentó 6 kg de masa muscular magra y redujo grasa al 10%.'),
('Natalia P.', 'Completó su primer medio maratón reduciendo dolores articulares.');

-- 6. Tabla de PREGUNTAS DE REGISTRO (Cuestionario inicial)
CREATE TABLE public.registration_questions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    question_text TEXT NOT NULL,
    is_required BOOLEAN DEFAULT TRUE NOT NULL,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_by UUID REFERENCES public.users("userID") ON DELETE SET NULL
);

ALTER TABLE public.registration_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Lectura publica de preguntas" ON public.registration_questions FOR SELECT USING (true);
CREATE POLICY "Admin puede insertar preguntas" ON public.registration_questions FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
);
CREATE POLICY "Admin puede actualizar preguntas" ON public.registration_questions FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
);
CREATE POLICY "Admin puede eliminar preguntas" ON public.registration_questions FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
);

-- 7. Columna JSONB en users para guardar respuestas del cuestionario
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS questionnaire_answers JSONB DEFAULT '[]'::jsonb;

-- Insertar preguntas de registro iniciales
INSERT INTO public.registration_questions (question_text, is_required, sort_order) VALUES
('¿Cuál es tu objetivo principal? (Perder peso, ganar masa muscular, mejorar resistencia, etc.)', TRUE, 1),
('¿Tienes alguna lesión o condición médica que debamos considerar?', TRUE, 2),
('¿Con qué frecuencia haces ejercicio actualmente? (Días por semana)', TRUE, 3),
('¿Tienes alguna alergia o restricción alimentaria?', FALSE, 4);

-- 8. Tabla de REGISTROS DE MEDIDAS CORPORALES
CREATE TABLE IF NOT EXISTS public.registros_medidas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    photo_url TEXT,
    weight DOUBLE PRECISION NOT NULL,
    abdomen DOUBLE PRECISION NOT NULL,
    waist DOUBLE PRECISION NOT NULL,
    leg DOUBLE PRECISION NOT NULL,
    chest DOUBLE PRECISION NOT NULL,
    arm DOUBLE PRECISION NOT NULL,
    calf DOUBLE PRECISION NOT NULL
);

ALTER TABLE public.registros_medidas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Permitir lectura propia y admin" ON public.registros_medidas FOR SELECT USING (
    auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
);
CREATE POLICY "Permitir insercion propia" ON public.registros_medidas FOR INSERT WITH CHECK (
    auth.uid() = user_id
);
CREATE POLICY "Permitir eliminacion propia" ON public.registros_medidas FOR DELETE USING (
    auth.uid() = user_id
);

-- 9. Tabla de CATALOGO GLOBAL DE EJERCICIOS
CREATE TABLE IF NOT EXISTS public.ejercicios (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT
);

ALTER TABLE public.ejercicios ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Lectura publica de ejercicios" ON public.ejercicios FOR SELECT USING (true);
CREATE POLICY "Admin puede gestionar ejercicios" ON public.ejercicios FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
);

-- 10. Tabla de RUTINAS ASIGNADAS
CREATE TABLE IF NOT EXISTS public.rutinas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.rutinas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Lectura propia y admin de rutinas" ON public.rutinas FOR SELECT USING (
    auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
);
CREATE POLICY "Admin puede gestionar rutinas" ON public.rutinas FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
);

-- 11. Tabla de RELACION RUTINA-EJERCICIOS
CREATE TABLE IF NOT EXISTS public.rutina_ejercicios (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    routine_id UUID REFERENCES public.rutinas(id) ON DELETE CASCADE NOT NULL,
    exercise_id UUID REFERENCES public.ejercicios(id) ON DELETE CASCADE NOT NULL,
    sets INTEGER NOT NULL,
    reps INTEGER NOT NULL,
    series_weights DOUBLE PRECISION[] NOT NULL,
    series_type TEXT DEFAULT 'Normal' NOT NULL, -- 'Normal', 'Biserie', 'Triserie', 'Superset'
    sort_order INTEGER DEFAULT 0 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.rutina_ejercicios ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Lectura propia y admin de rutina_ejercicios" ON public.rutina_ejercicios FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.rutinas r WHERE r.id = routine_id AND (r.user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.users u WHERE u."userID" = auth.uid() AND u.is_admin = TRUE)))
);
CREATE POLICY "Admin puede gestionar rutina_ejercicios" ON public.rutina_ejercicios FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
);

-- 12. Tabla de HISTORIAL DE ENTRENAMIENTOS
CREATE TABLE IF NOT EXISTS public.historial_entrenamientos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users("userID") ON DELETE CASCADE NOT NULL,
    routine_id UUID REFERENCES public.rutinas(id) ON DELETE SET NULL,
    routine_name TEXT NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    duration_seconds INTEGER NOT NULL,
    total_volume DOUBLE PRECISION NOT NULL,
    total_sets INTEGER NOT NULL,
    logged_exercises JSONB NOT NULL
);

ALTER TABLE public.historial_entrenamientos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Lectura propia y admin de historial" ON public.historial_entrenamientos FOR SELECT USING (
    auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
);
CREATE POLICY "Insercion propia de historial" ON public.historial_entrenamientos FOR INSERT WITH CHECK (
    auth.uid() = user_id
);

-- 13. Tabla de ENTRENADORES REGISTRADOS (EmpresasEntrenadores)
CREATE TABLE IF NOT EXISTS public.EmpresasEntrenadores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "userID" UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    correo_electronico TEXT NOT NULL,
    telefono TEXT NOT NULL,
    especialidad TEXT DEFAULT '' NOT NULL,
    bio TEXT DEFAULT '' NOT NULL,
    foto_perfil TEXT,
    estado TEXT DEFAULT 'activo' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.EmpresasEntrenadores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Lectura publica de entrenadores" ON public.EmpresasEntrenadores FOR SELECT USING (true);
CREATE POLICY "Admin puede gestionar entrenadores" ON public.EmpresasEntrenadores FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE "userID" = auth.uid() AND is_admin = TRUE)
);

-- Insertar ejercicios por defecto en el catálogo si la tabla está vacía
INSERT INTO public.ejercicios (name, description, image_url)
SELECT name, description, image_url FROM (
    VALUES
    ('Sentadilla libre con barra', 'Coloca la barra sobre los trapecios, desciende rompiendo el paralelo y sube con fuerza.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/barbell-full-squat.gif'),
    ('Peso Muerto Rumano', 'Mantén la espalda recta, bisagra de cadera descendiendo la barra pegada a los muslos y siente el estímulo en femorales.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/hamstrings/barbell-romanian-deadlift.gif'),
    ('Prensa de piernas', 'Empuja la plataforma con los pies separados al ancho de hombros, baja controlando el peso.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/sled-45-leg-press.gif'),
    ('Calentamiento General', 'Movilidad articular y activación general en caminadora o elíptica durante 5 a 10 minutos.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/cardio/walking-on-incline-treadmill.gif'),
    ('Press de banca plano', 'Acostado en el banco, baja la barra al pecho y empuja verticalmente hasta extender los codos.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/chest/barbell-bench-press.gif'),
    ('Abducción de Caderas', 'Sentado en la máquina, empuja las almohadillas hacia afuera controlando la apertura y mantén 2 segundos.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/seated-hip-abduction.gif'),
    ('Abdominal Corto', 'Acostado boca arriba, flexiona el abdomen levantando ligeramente las escápulas del suelo.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/abs/crunch.gif'),
    ('Extensión de Pierna', 'Sentado en la máquina, extiende las rodillas contrayendo los cuádriceps en la parte alta.', 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/quads/lever-leg-extension.gif')
) AS v(name, description, image_url)
WHERE NOT EXISTS (SELECT 1 FROM public.ejercicios);
''';

  // --- NOVEDADES ---
  Future<List<NewsItem>> getNews() async {
    if (_useMockData || !_isInitialized) {
      return _getMockNews();
    }
    try {
      final currentUserId = client.auth.currentUser?.id;
      String? currentEmpresaId;
      if (currentUserId != null) {
        final trainerUserRow = await client
            .from('users')
            .select('IDEmpresa')
            .eq('userID', currentUserId)
            .maybeSingle();
        if (trainerUserRow != null && trainerUserRow['IDEmpresa'] != null) {
          currentEmpresaId = trainerUserRow['IDEmpresa']?.toString();
        }
        if (currentEmpresaId == null || currentEmpresaId.trim().isEmpty) {
          final empresaRow = await client
              .from('EmpresasEntrenadores')
              .select('IDEmpresa')
              .eq('userID', currentUserId)
              .maybeSingle();
          if (empresaRow != null && empresaRow['IDEmpresa'] != null) {
            currentEmpresaId = empresaRow['IDEmpresa']?.toString();
          }
        }
      }

      var query = client.from('news').select();
      if (currentEmpresaId != null && currentEmpresaId.trim().isNotEmpty) {
        query = query.eq('IDEmpresa', currentEmpresaId);
      } else {
        return [];
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).map((json) => NewsItem.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  List<NewsItem> _getMockNews()  { return []; return [];
    return [];
  }

  Future<bool> addNews({
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    final author = _currentUserProfile?.name ?? 'Coach Carlos';
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      final currentUserId = client.auth.currentUser?.id;
      String? currentEmpresaId;
      if (currentUserId != null) {
        final trainerUserRow = await client
            .from('users')
            .select('IDEmpresa')
            .eq('userID', currentUserId)
            .maybeSingle();
        if (trainerUserRow != null && trainerUserRow['IDEmpresa'] != null) {
          currentEmpresaId = trainerUserRow['IDEmpresa']?.toString();
        }
        if (currentEmpresaId == null || currentEmpresaId.trim().isEmpty) {
          final empresaRow = await client
              .from('EmpresasEntrenadores')
              .select('IDEmpresa')
              .eq('userID', currentUserId)
              .maybeSingle();
          if (empresaRow != null && empresaRow['IDEmpresa'] != null) {
            currentEmpresaId = empresaRow['IDEmpresa']?.toString();
          }
        }
      }

      await client.from('news').insert({
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'author_name': author,
        'IDEmpresa': currentEmpresaId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateNews({
    required String id,
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      final updateData = {
        'title': title,
        'content': content,
      };
      if (imageUrl != null) {
        updateData['image_url'] = imageUrl;
      }
      await client.from('news').update(updateData).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteNews(String id) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      await client.from('news').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> uploadNewsPhoto(dynamic imageFile) async {
    final targetId = client.auth.currentUser?.id ?? 'mock-user-123';
    if (_useMockData || !_isInitialized || imageFile == null) {
      return 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=600';
    }
    try {
      final bytes = imageFile.path.startsWith('http')
          ? await http.readBytes(Uri.parse(imageFile.path))
          : await imageFile.readAsBytes();
      final fileName =
          'news/${targetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage
          .from('general')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      return client.storage.from('general').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  // --- PERFIL DE USUARIO ---
  Future<UserProfile> getUserProfile() async {
    if (_useMockData || !_isInitialized) {
      return _getMockUserProfile();
    }
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return _getMockUserProfile();
      }
      final userId = user.id;

      final response = await client
          .from('users')
          .select()
          .eq('userID', userId)
          .maybeSingle();
      if (response == null) {
        final meta = user.userMetadata ?? {};
        return UserProfile(
          userID: userId,
          email: user.email ?? '',
          name: meta['name']?.toString() ?? 'Nuevo Usuario',
          currentWeight: (meta['weight'] as num?)?.toDouble() ?? 70.0,
          targetWeight: (meta['target_weight'] as num?)?.toDouble() ?? 65.0,
          initialWeight: (meta['initial_weight'] as num?)?.toDouble() ?? 70.0,
          height: (meta['height'] as num?)?.toDouble() ?? 170.0,
          age: (meta['age'] as num?)?.toInt() ?? 25,
          isAdmin: meta['is_admin'] == true,
          updatedAt: DateTime.now(),
        );
      }
      return UserProfile.fromJson(response);
    } catch (e) {
      if (e.toString().contains('PGRST205') ||
          e.toString().contains('relation') ||
          e.toString().contains('does not exist')) {
        // removed
      }
      return _getMockUserProfile();
    }
  }

  Future<Trainer?> getTrainerProfile() async {
    if (_useMockData || !_isInitialized) {
      final mockTrainers = _getMockTrainers();
      return mockTrainers.isNotEmpty ? mockTrainers.first : null;
    }
    try {
      final currentUserId = client.auth.currentUser?.id;
      String? currentEmpresaId;
      if (currentUserId != null) {
        final trainerUserRow = await client
            .from('users')
            .select('IDEmpresa')
            .eq('userID', currentUserId)
            .maybeSingle();
        if (trainerUserRow != null && trainerUserRow['IDEmpresa'] != null) {
          currentEmpresaId = trainerUserRow['IDEmpresa']?.toString();
        }

        if (currentEmpresaId == null || currentEmpresaId.trim().isEmpty) {
          final empresaRow = await client
              .from('EmpresasEntrenadores')
              .select('IDEmpresa')
              .eq('userID', currentUserId)
              .maybeSingle();
          if (empresaRow != null && empresaRow['IDEmpresa'] != null) {
            currentEmpresaId = empresaRow['IDEmpresa']?.toString();
          }
        }
      }

      if (currentEmpresaId == null || currentEmpresaId.trim().isEmpty) {
        return null;
      }

      final response = await client
          .from('EmpresasEntrenadores')
          .select()
          .eq('IDEmpresa', currentEmpresaId)
          .maybeSingle();

      if (response == null) return null;

      final trainer = Trainer.fromJson(response);
      final enrichedList = await _enrichTrainersWithSuperAdmin([trainer]);
      return enrichedList.isNotEmpty ? enrichedList.first : trainer;
    } catch (e) {
      print('Error in getTrainerProfile: $e');
      return null;
    }
  }

  UserProfile _getMockUserProfile() {
    return UserProfile(
      userID: 'mock-user-123',
      email: 'mateo@gmail.com',
      name: 'Mateo Fernández',
      currentWeight: 78.5,
      targetWeight: 72.0,
      initialWeight: 85.0,
      height: 180.0,
      age: 28,
      isAdmin: false,
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      nextPaymentDate: DateTime.now().add(const Duration(days: 12)),
    );
  }

  // --- ACTUALIZAR PERFIL Y SUBIR FOTO ---
  Future<bool> updateUserProfile({
    required String name,
    double? weight,
    double? targetWeight,
    double? height,
    int? age,
    String? avatarUrl,
  }) async {
    if (_useMockData || !_isInitialized) {
      // In mock/demo mode, update the profile in memory
      if (_currentUserProfile != null) {
        _currentUserProfile = UserProfile(
          userID: _currentUserProfile!.userID,
          email: _currentUserProfile!.email,
          name: name,
          currentWeight: weight ?? _currentUserProfile!.currentWeight,
          targetWeight: targetWeight ?? _currentUserProfile!.targetWeight,
          initialWeight: _currentUserProfile!.initialWeight,
          height: height ?? _currentUserProfile!.height,
          age: age ?? _currentUserProfile!.age,
          isAdmin: _currentUserProfile!.isAdmin,
          updatedAt: DateTime.now(),
          nextPaymentDate: _currentUserProfile!.nextPaymentDate,
          questionnaireAnswers: _currentUserProfile!.questionnaireAnswers,
          avatarUrl: avatarUrl ?? _currentUserProfile!.avatarUrl,
        );
        _authStreamController.add(_currentUserProfile);
      }
      return true;
    }

    try {
      final targetId = client.auth.currentUser?.id;
      if (targetId == null) return false;

      final updateData = <String, dynamic>{
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (weight != null) updateData['weight'] = weight;
      if (targetWeight != null) updateData['target_weight'] = targetWeight;
      if (height != null) updateData['height'] = height;
      if (age != null) updateData['age'] = age;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

      await client.from('users').update(updateData).eq('userID', targetId);

      // Refresh current profile cache
      final updatedProfile = await getUserProfile();
      _currentUserProfile = updatedProfile;
      _authStreamController.add(updatedProfile);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> uploadProfilePhoto(dynamic imageFile) async {
    final targetId = client.auth.currentUser?.id ?? 'mock-user-123';
    if (_useMockData || !_isInitialized || imageFile == null) {
      return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';
    }
    try {
      final bytes = imageFile.path.startsWith('http')
          ? await http.readBytes(Uri.parse(imageFile.path))
          : await imageFile.readAsBytes();
      final fileName =
          'profiles/${targetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage
          .from('general')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      return client.storage.from('general').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadExerciseGif(dynamic imageFile) async {
    if (_useMockData || !_isInitialized || imageFile == null) {
      return 'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/barbell-full-squat.gif';
    }
    try {
      final bytes = imageFile.path.startsWith('http')
          ? await http.readBytes(Uri.parse(imageFile.path))
          : await imageFile.readAsBytes();

      final extension = imageFile.path.split('.').last.toLowerCase();
      final contentType = extension == 'gif' ? 'image/gif' : 'image/jpeg';
      final fileName =
          'exercises/${DateTime.now().millisecondsSinceEpoch}.$extension';

      await client.storage
          .from('general')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );

      return client.storage.from('general').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  String _generateRandomEmpresaId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(
      8,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  Future<bool> registerTrainer({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? specialty,
    String? bio,
    dynamic imageFile,
    bool isSuperAdmin = false,
    DateTime? fechaPago,
    String? modalidadPago,
    DateTime? proximoPago,
    double montodecobroMensual = 0.0,
  }) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      // 1. Crear usuario en auth.users mediante una petición HTTP directa para evitar desloguear al admin
      // y prevenir problemas con el PKCE flow y almacenamiento asíncrono
      final authResponse = await http.post(
        Uri.parse('$supabaseUrl/auth/v1/signup'),
        headers: {
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'data': {
            'name': name,
            'is_admin': true,
            'weight': 0.0,
            'height': 0.0,
            'age': 0,
            'initial_weight': 0.0,
            'target_weight': 0.0,
          },
        }),
      );

      if (authResponse.statusCode != 200 && authResponse.statusCode != 201) {
        final bodyJson = jsonDecode(authResponse.body);
        final errorMsg =
            bodyJson['msg'] ??
            bodyJson['error_description'] ??
            bodyJson['message'] ??
            'Error desconocido';
        throw Exception(errorMsg);
      }

      final responseData = jsonDecode(authResponse.body);
      final userId = responseData['id'] ?? responseData['user']?['id'];
      if (userId == null) return false;

      // 2. Subir foto si existe usando el cliente principal
      String? photoUrl;
      if (imageFile != null) {
        try {
          final bytes = imageFile.path.startsWith('http')
              ? await http.readBytes(Uri.parse(imageFile.path))
              : await imageFile.readAsBytes();
          final fileName =
              'trainers/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

          await client.storage
              .from('general')
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              );

          photoUrl = client.storage.from('general').getPublicUrl(fileName);
        } catch (_) {
          // Si falla la foto, continuar sin ella
        }
      }
      // Forzar IDEmpresa a TITANSITAUNICO para todos los usuarios y entrenadores por ahora
      final empresaId = 'TITANSITAUNICO';

      // 3. Crear entrada en users table con is_admin = true, superAdmin = false, avatar_url y IDEmpresa
      await client.from('users').upsert({
        'userID': userId,
        'email': email,
        'name': name,
        'is_admin': true,
        'superAdmin': isSuperAdmin,
        'avatar_url': photoUrl,
        'IDEmpresa': empresaId,
        'password': password,
        'weight': 0.0,
        'height': 0.0,
        'age': 0,
        'initial_weight': 0.0,
        'target_weight': 0.0,
      });

      // Convertir el teléfono a valor numérico ya que la columna es de tipo numeric
      final phoneDigitsOnly = phone.replaceAll(RegExp(r'\D'), '');
      final numericPhone = num.tryParse(phoneDigitsOnly) ?? 0;

      // 4. Insertar en EmpresasEntrenadores (con foto perfil con espacio y telefono numeric)
      await client.from('EmpresasEntrenadores').insert({
        'userID': userId,
        'IDEmpresa': empresaId,
        'nombre': name,
        'correo_electronico': email,
        'telefono': numericPhone,
        'foto perfil': photoUrl,
        'especialidad': specialty ?? '',
        'fecha_pago': fechaPago?.toIso8601String(),
        'modalidad_pago': modalidadPago,
        'proximo_pago': proximoPago?.toIso8601String(),
        'montodecobro_mensual': montodecobroMensual,
      });

      return true;
    } catch (e) {
      rethrow;
    }
  }

  // --- TRAINERS / ENTRENADORES ---
  Future<List<Trainer>> getTrainers() async {
    if (_useMockData || !_isInitialized) {
      return _getMockTrainers();
    }
    try {
      final response = await client
          .from('EmpresasEntrenadores')
          .select()
          .eq('inhabilitado', false)
          .order('created_at', ascending: false);
      final trainers = (response as List).map((json) => Trainer.fromJson(json)).toList();
      // Enrich with superAdmin from users table
      return _enrichTrainersWithSuperAdmin(trainers);
    } catch (e) {
      print('Error en getTrainers: $e');
      if (e.toString().contains('PGRST205') ||
          e.toString().contains('relation') ||
          e.toString().contains('does not exist')) {
        // removed
      }
      return _getMockTrainers();
    }
  }

  Future<List<Trainer>> getInactiveTrainers() async {
    if (_useMockData || !_isInitialized) {
      return [];
    }
    try {
      final response = await client
          .from('EmpresasEntrenadores')
          .select()
          .eq('inhabilitado', true)
          .order('created_at', ascending: false);
      final trainers = (response as List).map((json) => Trainer.fromJson(json)).toList();
      return _enrichTrainersWithSuperAdmin(trainers);
    } catch (e) {
      print('Error en getInactiveTrainers: $e');
      return [];
    }
  }

  /// Obtener la contraseña almacenada de un entrenador desde la tabla users
  Future<String?> getTrainerPassword(String userId, {String? email}) async {
    if (_useMockData || !_isInitialized) return null;
    try {
      if (userId.trim().isNotEmpty) {
        final res = await client
            .from('users')
            .select('password')
            .eq('userID', userId.trim())
            .maybeSingle()
            .timeout(const Duration(seconds: 6));
        if (res != null && res['password'] != null) {
          return res['password']?.toString();
        }
      }
      if (email != null && email.trim().isNotEmpty) {
        final res = await client
            .from('users')
            .select('password')
            .eq('email', email.trim())
            .maybeSingle()
            .timeout(const Duration(seconds: 6));
        return res?['password']?.toString();
      }
      return null;
    } catch (e) {
      print('Error al obtener contraseña de entrenador: $e');
      return null;
    }
  }

  /// Actualizar la contraseña de un entrenador en la tabla users y auth.users
  Future<String?> updateTrainerPassword({
    required String userId,
    String? email,
    required String newPassword,
  }) async {
    if (_useMockData || !_isInitialized) return null;
    try {
      bool success = false;
      String? errorMessage;

      // 1. Intentar llamar a la función RPC admin_update_password para actualizar auth.users
      if (email != null && email.trim().isNotEmpty) {
        try {
          final rpcRes = await client.rpc('admin_update_password', params: {
            'p_email': email.trim().toLowerCase(),
            'p_password': newPassword,
          }).timeout(const Duration(seconds: 6));
          if (rpcRes == true) {
            print('Contraseña actualizada en auth.users exitosamente.');
          } else {
            errorMessage = 'El RPC devolvió false (usuario no encontrado en auth.users)';
          }
        } catch (e) {
          print('RPC admin_update_password falló: $e');
          errorMessage = 'Error SQL/RPC: $e';
        }
      }

      if (errorMessage != null) {
        return errorMessage; // Retornar temprano el error exacto del RPC
      }

      // 2. Fallback: Actualizar tabla public.users por userID
      if (userId.trim().isNotEmpty) {
        try {
          await client
              .from('users')
              .update({'password': newPassword})
              .eq('userID', userId.trim())
              .timeout(const Duration(seconds: 6));
          success = true;
        } catch (e) {
          print('Error al actualizar por userID: $e');
        }
      }

      // 3. Fallback: Actualizar tabla public.users por email
      if (!success && email != null && email.trim().isNotEmpty) {
        try {
          await client
              .from('users')
              .update({'password': newPassword})
              .eq('email', email.trim())
              .timeout(const Duration(seconds: 6));
          success = true;
        } catch (e) {
          print('Error al actualizar por email: $e');
        }
      }

      return success ? null : 'No se pudo actualizar public.users';
    } catch (e) {
      print('Error general al actualizar contraseña de entrenador: $e');
      return 'Excepción general: $e';
    }
  }

  /// Verificar si la contraseña ingresada corresponde al administrador actual autenticado
  Future<bool> verifyCurrentAdminPassword(String enteredPassword) async {
    if (_useMockData || !_isInitialized) return true;
    final currentEmail = client.auth.currentUser?.email;
    final currentUserId = client.auth.currentUser?.id;
    if (currentEmail == null && currentUserId == null) return false;

    try {
      // 1. Verificar si coincide con la contraseña almacenada en public.users
      if (currentUserId != null) {
        final row = await client
            .from('users')
            .select('password')
            .eq('userID', currentUserId)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        final storedPass = row?['password']?.toString();
        if (storedPass != null && storedPass.isNotEmpty) {
          return storedPass == enteredPassword;
        }
      }

      // 2. Intentar autenticar contra Supabase Auth Token
      if (currentEmail != null) {
        final res = await http.post(
          Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
          headers: {
            'apikey': supabaseAnonKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': currentEmail,
            'password': enteredPassword,
          }),
        ).timeout(const Duration(seconds: 5));
        return res.statusCode == 200;
      }
      return false;
    } catch (e) {
      print('Error al verificar contraseña de administrador: $e');
      return false;
    }
  }

  Future<double> getTrainerProgress() async {
    if (_useMockData || !_isInitialized) {
      return 75.0;
    }
    try {
      final clients = await getAllClients();
      if (clients.isEmpty) return 0.0;

      final clientIds = clients.map((c) => c.userID).toList();
      final response = await client
          .from('objetivos')
          .select('completed')
          .inFilter('user_id', clientIds);

      final objectives = response as List;
      if (objectives.isEmpty) return 0.0;

      final completedCount = objectives.where((o) => o['completed'] == true).length;
      final double progress = (completedCount / objectives.length) * 100;

      // Update the progress field in EmpresasEntrenadores in the background if possible
      try {
        final currentUserId = client.auth.currentUser?.id;
        if (currentUserId != null) {
          String? currentEmpresaId;
          final trainerUserRow = await client
              .from('users')
              .select('IDEmpresa')
              .eq('userID', currentUserId)
              .maybeSingle();
          if (trainerUserRow != null && trainerUserRow['IDEmpresa'] != null) {
            currentEmpresaId = trainerUserRow['IDEmpresa']?.toString();
          }
          if (currentEmpresaId == null || currentEmpresaId.trim().isEmpty) {
            final empresaRow = await client
                .from('EmpresasEntrenadores')
                .select('IDEmpresa')
                .eq('userID', currentUserId)
                .maybeSingle();
            if (empresaRow != null && empresaRow['IDEmpresa'] != null) {
              currentEmpresaId = empresaRow['IDEmpresa']?.toString();
            }
          }
          if (currentEmpresaId != null && currentEmpresaId.trim().isNotEmpty) {
            await client
                .from('EmpresasEntrenadores')
                .update({'progreso': progress})
                .eq('IDEmpresa', currentEmpresaId);
          }
        }
      } catch (_) {}

      return progress;
    } catch (e) {
      print('Error in getTrainerProgress: $e');
      return 0.0;
    }
  }

  Future<int> getTrainerCompletedObjectivesCount() async {
    if (_useMockData || !_isInitialized) {
      return 12; // Mock fallback
    }
    try {
      final clients = await getAllClients();
      if (clients.isEmpty) return 0;

      final clientIds = clients.map((c) => c.userID).toList();
      final response = await client
          .from('objetivos')
          .select('id')
          .inFilter('user_id', clientIds)
          .eq('completed', true);
      
      return (response as List).length;
    } catch (e) {
      print('Error in getTrainerCompletedObjectivesCount: $e');
      return 0;
    }
  }

  /// Enriches a list of trainers with the superAdmin field from the users table.
  Future<List<Trainer>> _enrichTrainersWithSuperAdmin(List<Trainer> trainers) async {
    if (trainers.isEmpty) return trainers;
    try {
      final userIds = trainers.map((t) => t.userId).where((id) => id.isNotEmpty).toList();
      if (userIds.isEmpty) return trainers;
      final usersResponse = await client
          .from('users')
          .select('userID, superAdmin')
          .inFilter('userID', userIds);
      final superAdminMap = <String, bool>{};
      for (final row in (usersResponse as List)) {
        superAdminMap[row['userID']?.toString() ?? ''] = row['superAdmin'] == true;
      }
      return trainers.map((t) {
        final isSA = superAdminMap[t.userId] ?? false;
        return t.copyWith(isSuperAdmin: isSA);
      }).toList();
    } catch (_) {
      return trainers;
    }
  }

  List<Trainer> _getMockTrainers()  { return []; return [];
    final now = DateTime.now();
    return [
      Trainer(
        id: 'TRAIN123',
        userId: 'user-trainer-1',
        nombre: 'Carlos Méndez',
        correoElectronico: 'carlos@gym.com',
        telefono: '+56 9 1234 5678',
        especialidad: 'Fitness y musculación',
        bio: 'Entrenador certificado con 10 años de experiencia en fitness.',
        estado: 'activo',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      ),
      Trainer(
        id: 'TRAIN456',
        userId: 'user-trainer-2',
        nombre: 'Sofía García',
        correoElectronico: 'sofia@gym.com',
        telefono: '+56 9 2345 6789',
        especialidad: 'Yoga y pilates',
        bio: 'Especialista en flexibilidad y bienestar corporal.',
        estado: 'activo',
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    ];
  }

  Future<bool> updateTrainer({
    required String trainerId,
    String? nombre,
    String? telefono,
    String? especialidad,
    String? bio,
    String? estado,
    bool? isSuperAdmin,
    DateTime? fechaPago,
    String? modalidadPago,
    DateTime? proximoPago,
    double? montodecobroMensual,
  }) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (nombre != null) updateData['nombre'] = nombre;
      if (telefono != null) updateData['telefono'] = telefono;
      if (especialidad != null) updateData['especialidad'] = especialidad;
      if (bio != null) updateData['bio'] = bio;
      if (estado != null) updateData['estado'] = estado;
      if (fechaPago != null) updateData['fecha_pago'] = fechaPago.toIso8601String();
      if (modalidadPago != null) updateData['modalidad_pago'] = modalidadPago;
      if (proximoPago != null) updateData['proximo_pago'] = proximoPago.toIso8601String();
      if (montodecobroMensual != null) updateData['montodecobro_mensual'] = montodecobroMensual;

      await client
          .from('EmpresasEntrenadores')
          .update(updateData)
          .eq('IDEmpresa', trainerId);

      // Update superAdmin in users table if provided
      if (isSuperAdmin != null) {
        // Find the userID for this trainer
        final trainerRow = await client
            .from('EmpresasEntrenadores')
            .select('userID')
            .eq('IDEmpresa', trainerId)
            .maybeSingle();
        if (trainerRow != null && trainerRow['userID'] != null) {
          await client
              .from('users')
              .update({'superAdmin': isSuperAdmin})
              .eq('userID', trainerRow['userID']);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTrainer(String trainerId) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      await client
          .from('EmpresasEntrenadores')
          .update({'inhabilitado': true})
          .eq('IDEmpresa', trainerId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> reactivateTrainer(String trainerId) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      await client
          .from('EmpresasEntrenadores')
          .update({'inhabilitado': false})
          .eq('IDEmpresa', trainerId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> registerClient({
    required String email,
    required String password,
    required String name,
    required double weight,
    required double height,
    required int age,
    required List<Map<String, dynamic>> questionnaireAnswers,
    double? abdomen,
    double? waist,
    double? leg,
    double? chest,
    double? arm,
    double? calf,
    double? cuello,
    dynamic imageFile,
  }) async {
    if (_useMockData || !_isInitialized) {
      _getMockClients();
      final newUserId = 'client-${DateTime.now().millisecondsSinceEpoch}';
      final newClient = UserProfile(
        userID: newUserId,
        email: email,
        name: name,
        currentWeight: weight,
        initialWeight: weight,
        targetWeight: weight - 5.0,
        height: height,
        age: age,
        isAdmin: false,
        updatedAt: DateTime.now(),
        questionnaireAnswers: questionnaireAnswers,
      );
      _mockClients!.add(newClient);

      if (abdomen != null ||
          waist != null ||
          leg != null ||
          chest != null ||
          arm != null ||
          calf != null ||
          cuello != null ||
          imageFile != null) {
        _initMockRecords();
        final newRecord = MeasurementRecord(
          id: 'rec-${DateTime.now().millisecondsSinceEpoch}',
          userId: newUserId,
          createdAt: DateTime.now(),
          weight: weight,
          abdomen: abdomen ?? 0.0,
          waist: waist ?? 0.0,
          leg: leg ?? 0.0,
          chest: chest ?? 0.0,
          arm: arm ?? 0.0,
          calf: calf ?? 0.0,
          cuello: cuello ?? 0.0,
          photoUrl: imageFile != null
              ? 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=600'
              : null,
        );
        _mockRecords!.add(newRecord);
      }
      return true;
    }

    try {
      final currentUserId = client.auth.currentUser?.id;
      String? currentEmpresaId;
      // Forzar IDEmpresa a TITANSITAUNICO para todos los clientes
      currentEmpresaId = 'TITANSITAUNICO';
      final authResponse = await http.post(
        Uri.parse('$supabaseUrl/auth/v1/signup'),
        headers: {
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'data': {
            'name': name,
            'is_admin': false,
            'superAdmin': false,
            'IDEmpresa': currentEmpresaId,
            'weight': weight,
            'height': height,
            'age': age,
            'initial_weight': weight,
            'target_weight': weight - 5.0,
          },
        }),
      );

      if (authResponse.statusCode != 200 && authResponse.statusCode != 201) {
        final bodyJson = jsonDecode(authResponse.body);
        final errorMsg =
            bodyJson['msg'] ??
            bodyJson['error_description'] ??
            bodyJson['message'] ??
            'Error desconocido';
        throw Exception(errorMsg);
      }

      final responseData = jsonDecode(authResponse.body);
      final userId = responseData['id'] ?? responseData['user']?['id'];
      if (userId == null) return false;

      await client.from('users').upsert({
        'userID': userId,
        'email': email,
        'name': name,
        'is_admin': false,
        'superAdmin': false,
        'IDEmpresa': currentEmpresaId,
        'password': password,
        'weight': weight,
        'height': height,
        'age': age,
        'initial_weight': weight,
        'target_weight': weight - 5.0,
        'questionnaire_answers': questionnaireAnswers,
      });

      if (abdomen != null ||
          waist != null ||
          leg != null ||
          chest != null ||
          arm != null ||
          calf != null ||
          cuello != null ||
          imageFile != null) {
        String? uploadedPhotoUrl;
        if (imageFile != null) {
          try {
            final bytes = imageFile.path.startsWith('http')
                ? await http.readBytes(Uri.parse(imageFile.path))
                : await imageFile.readAsBytes();
            final fileName =
                '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            await client.storage
                .from('general')
                .uploadBinary(
                  fileName,
                  bytes,
                  fileOptions: const FileOptions(contentType: 'image/jpeg'),
                );
            uploadedPhotoUrl = client.storage
                .from('general')
                .getPublicUrl(fileName);
          } catch (_) {
            // ignore storage errors
          }
        }

        await client.from('registros_medidas').insert({
          'user_id': userId,
          'weight': weight,
          'abdomen': abdomen ?? 0.0,
          'waist': waist ?? 0.0,
          'leg': leg ?? 0.0,
          'chest': chest ?? 0.0,
          'arm': arm ?? 0.0,
          'calf': calf ?? 0.0,
          'cuello': cuello ?? 0.0,
          'photo_url': uploadedPhotoUrl,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // --- EJERCICIOS ESTABLECIDOS ---
  Future<List<EstablishedExercise>> getEstablishedExercises({
    String? userId,
  }) async {
    if (_useMockData || !_isInitialized) {
      return _getMockExercises(userId: userId);
    }
    try {
      final targetId = userId ?? client.auth.currentUser?.id;
      if (targetId == null) {
        return _getMockExercises(userId: userId);
      }

      final response = await client
          .from('ejercicios_establecidos')
          .select()
          .eq('user_id', targetId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => EstablishedExercise.fromJson(json))
          .toList();
    } catch (e) {
      if (e.toString().contains('PGRST205') ||
          e.toString().contains('relation') ||
          e.toString().contains('does not exist')) {
        // removed
      }
      return _getMockExercises(userId: userId);
    }
  }

  void _initMockExercises() {
    if (_mockExercises != null) return;
    final now = DateTime.now();
    _mockExercises = [
      // Client-1 (Sofía Guerrero)
      EstablishedExercise(
        id: 'ex-1',
        userId: 'client-1',
        name: 'Sentadilla libre con barra',
        sets: 4,
        reps: 10,
        weight: 60.0,
        dayOfWeek: 'Lunes',
        createdAt: now,
      ),
      EstablishedExercise(
        id: 'ex-2',
        userId: 'client-1',
        name: 'Prensa de piernas',
        sets: 4,
        reps: 12,
        weight: 120.0,
        dayOfWeek: 'Lunes',
        createdAt: now,
      ),
      // Client-2 (Alejandro Morales)
      EstablishedExercise(
        id: 'ex-3',
        userId: 'client-2',
        name: 'Press de banca plano',
        sets: 4,
        reps: 8,
        weight: 80.0,
        dayOfWeek: 'Martes',
        createdAt: now,
      ),
      EstablishedExercise(
        id: 'ex-4',
        userId: 'client-2',
        name: 'Fondos en paralelas',
        sets: 3,
        reps: 12,
        weight: 0.0,
        dayOfWeek: 'Martes',
        createdAt: now,
      ),
      // Client-3 (Natalia Peña)
      EstablishedExercise(
        id: 'ex-5',
        userId: 'client-3',
        name: 'Peso muerto rumano',
        sets: 4,
        reps: 12,
        weight: 50.0,
        dayOfWeek: 'Miércoles',
        createdAt: now,
      ),
      EstablishedExercise(
        id: 'ex-6',
        userId: 'client-3',
        name: 'Plancha abdominal',
        sets: 3,
        reps: 60,
        weight: 0.0,
        dayOfWeek: 'Miércoles',
        createdAt: now,
      ),
      // Default / Mateo (mock-user-123)
      EstablishedExercise(
        id: 'ex-7',
        userId: 'mock-user-123',
        name: 'Sentadilla libre con barra',
        sets: 4,
        reps: 10,
        weight: 80.0,
        dayOfWeek: 'Lunes',
        createdAt: now,
      ),
      EstablishedExercise(
        id: 'ex-8',
        userId: 'mock-user-123',
        name: 'Prensa de piernas inclinada',
        sets: 4,
        reps: 12,
        weight: 160.0,
        dayOfWeek: 'Lunes',
        createdAt: now,
      ),
      EstablishedExercise(
        id: 'ex-9',
        userId: 'mock-user-123',
        name: 'Zancadas búlgaras con mancuerna',
        sets: 3,
        reps: 12,
        weight: 16.0,
        dayOfWeek: 'Lunes',
        createdAt: now,
      ),
      EstablishedExercise(
        id: 'ex-10',
        userId: 'mock-user-123',
        name: 'Extensión de cuádriceps en máquina',
        sets: 4,
        reps: 15,
        weight: 45.0,
        dayOfWeek: 'Lunes',
        createdAt: now,
      ),
    ];
  }

  List<EstablishedExercise> _getMockExercises({String? userId})  { return [];
    _initMockExercises();
    final targetId = userId ?? _currentUserProfile?.userID ?? 'mock-user-123';
    return _mockExercises!.where((ex) => ex.userId == targetId).toList();
  }

  Future<bool> addEstablishedExercise(
    String name,
    int sets,
    int reps,
    double weight,
    String dayOfWeek, {
    String? userId,
  }) async {
    final targetId = userId ?? client.auth.currentUser?.id;
    if (_useMockData || !_isInitialized || targetId == null) {
      _initMockExercises();
      final userKey = userId ?? _currentUserProfile?.userID ?? 'mock-user-123';
      final newItem = EstablishedExercise(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userKey,
        name: name,
        sets: sets,
        reps: reps,
        weight: weight,
        dayOfWeek: dayOfWeek,
        createdAt: DateTime.now(),
      );
      _mockExercises!.add(newItem);
      return true;
    }
    try {
      await client.from('ejercicios_establecidos').insert({
        'user_id': targetId,
        'name': name,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'day_of_week': dayOfWeek,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- RECETAS (RECETARIO) ---
  Future<List<Recipe>> getRecipes() async {
    if (!_isInitialized) {
      return [];
    }
    try {
      final profile = await getUserProfile();
      final idEmpresa = profile?.idEmpresa ?? '';

      dynamic response;
      try {
        if (idEmpresa.isNotEmpty) {
          response = await client
              .from('recipes')
              .select()
              .eq('IDEmpresa', idEmpresa)
              .order('created_at', ascending: false);
        } else {
          response = await client
              .from('recipes')
              .select()
              .order('created_at', ascending: false);
        }
      } catch (e) {
        // Fallback: select all without IDEmpresa filter if column missing or null
        response = await client
            .from('recipes')
            .select()
            .order('created_at', ascending: false);
      }
      return (response as List).map((json) => Recipe.fromJson(json)).toList();
    } catch (e) {
      print('Error in getRecipes: $e');
      return [];
    }
  }

  List<Recipe> _getMockRecipes()  { return []; return [];
    if (_mockRecipes != null) {
      return _mockRecipes!;
    }
    _mockRecipes = [
      Recipe(
        id: '1',
        title: 'Tazón de Salmón y Quinoa 🐟',
        calories: 520,
        protein: 42.0,
        carbs: 45.0,
        fat: 18.0,
        time: '25 min',
        difficulty: 'Fácil',
        imageUrl:
            'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&q=80&w=400',
        ingredients: [
          '150g de filete de salmón fresco',
          '1/2 taza de quinoa cocida',
          '1/2 aguacate rebanado',
          '1 taza de espinacas tiernas',
          '1 cucharada de aderezo de sésamo ligero',
        ],
        steps: [
          'Sazona el filete de salmón con sal, pimienta y ajo en polvo.',
          'Cocina el salmón en una sartén antiadherente a fuego medio durante 4-5 minutos por lado.',
          'En un plato hondo o tazón, coloca una base de espinacas y quinoa caliente.',
          'Agrega el salmón desmenuzado, el aguacate y baña ligeramente con el aderezo.',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Recipe(
        id: '2',
        title: 'Avena Proteica de Berries 🍓',
        calories: 380,
        protein: 30.0,
        carbs: 50.0,
        fat: 6.0,
        time: '10 min',
        difficulty: 'Muy Fácil',
        imageUrl:
            'https://images.unsplash.com/photo-1517881917430-e70dfb3610aa?auto=format&fit=crop&q=80&w=400',
        ingredients: [
          '1/2 taza de hojuelas de avena enteras',
          '1 scoop (30g) de proteína en polvo (suero aislada)',
          '1 taza de leche de almendras sin azúcar',
          '1/2 taza de fresas y arándanos frescos',
          '1 cucharada de semillas de chía o linaza',
        ],
        steps: [
          'Cocina la avena junto con la leche de almendras en el microondas o estufa por 3 minutos.',
          'Retira del fuego y mezcla vigorosamente el scoop de proteína en polvo hasta homogeneizar.',
          'Decora con los frutos rojos frescos por encima.',
          'Espolvorea las semillas de chía y una pizca de canela.',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Recipe(
        id: '3',
        title: 'Pechuga Rellena con Espinacas y Feta 🍗',
        calories: 450,
        protein: 48.0,
        carbs: 8.0,
        fat: 14.0,
        time: '35 min',
        difficulty: 'Medio',
        imageUrl:
            'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&q=80&w=400',
        ingredients: [
          '1 pechuga de pollo deshuesada de 200g',
          '1 taza de espinacas frescas picadas',
          '30g de queso feta desmenuzado',
          '1 diente de ajo picado',
          '1 cucharadita de aceite de oliva virgen extra',
        ],
        steps: [
          'Precalienta el horno a 200°C.',
          'Saltea las espinacas con el ajo picado en el aceite de oliva hasta reducir.',
          'Mezcla las espinacas templadas con el queso feta.',
          'Realiza un corte longitudinal en la pechuga de pollo a modo de "bolsillo" y rellénala.',
          'Sella la pechuga en sartén por 2 minutos y luego hornéala por 15-20 minutos.',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      Recipe(
        id: '4',
        title: 'Pancake de Plátano y Avena (Sin Gluten) 🥞',
        calories: 320,
        protein: 12.0,
        carbs: 58.0,
        fat: 4.0,
        time: '12 min',
        difficulty: 'Muy Fácil',
        imageUrl:
            'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&q=80&w=400',
        ingredients: [
          '1 plátano maduro mediano',
          '1/2 taza de hojuelas de avena sin gluten',
          '1 huevo entero',
          '1/4 taza de leche de almendras sin azúcar',
          '1 cucharadita de canela en polvo',
        ],
        steps: [
          'Licúa todos los ingredientes hasta obtener una mezcla homogénea.',
          'Calienta una sartén antiadherente a fuego medio y engrasa ligeramente.',
          'Vierte porciones de la mezcla y cocina hasta que salgan burbujas en la superficie.',
          'Voltea y cocina por 1 minuto más hasta que estén dorados.',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
      Recipe(
        id: '5',
        title: 'Licuado Verde Energético 🥤',
        calories: 180,
        protein: 4.0,
        carbs: 35.0,
        fat: 2.0,
        time: '5 min',
        difficulty: 'Muy Fácil',
        imageUrl:
            'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&q=80&w=400',
        ingredients: [
          '1 taza de espinacas frescas',
          '1/2 manzana verde rebanada',
          '1/2 taza de piña picada',
          '1 taza de agua de coco sin azúcar',
          '1 cucharada de semillas de chía',
        ],
        steps: [
          'Coloca todos los ingredientes en la licuadora excepto las semillas de chía.',
          'Licúa a alta velocidad hasta que no queden grumos.',
          'Sirve en un vaso y agrega las semillas de chía, revolviendo con una cuchara.',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 9)),
      ),
      Recipe(
        id: '6',
        title: 'Snack de Manzana con Crema de Cacahuate 🥜',
        calories: 240,
        protein: 7.0,
        carbs: 22.0,
        fat: 16.0,
        time: '5 min',
        difficulty: 'Muy Fácil',
        imageUrl:
            'https://images.unsplash.com/photo-1619546813926-a78fa6372cd2?auto=format&fit=crop&q=80&w=400',
        ingredients: [
          '1 manzana roja grande',
          '2 cucharadas de crema de cacahuate 100% natural',
          '1 cucharadita de coco rallado sin azúcar',
          'Pizca de canela en polvo',
        ],
        steps: [
          'Corta la manzana en rodajas finas o gajos.',
          'Coloca los gajos en un plato y úntales la crema de cacahuate.',
          'Espolvorea el coco rallado y la canela por encima.',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      Recipe(
        id: '7',
        title: 'Bowl de Yogur de Coco con Almendras (Sin Lactosa) 🥥',
        calories: 290,
        protein: 8.0,
        carbs: 18.0,
        fat: 20.0,
        time: '5 min',
        difficulty: 'Muy Fácil',
        imageUrl:
            'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&q=80&w=400',
        ingredients: [
          '1 taza de yogur de coco sin azúcar',
          '15 almendras enteras picadas',
          '1 cucharada de semillas de calabaza',
          '1/4 taza de arándanos frescos',
        ],
        steps: [
          'Sirve el yogur de coco en un tazón.',
          'Coloca las almendras, semillas de calabaza y arándanos en secciones ordenadas encima.',
          'Disfruta inmediatamente como desayuno o snack saludable.',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 11)),
      ),
      Recipe(
        id: '8',
        title: 'Pizza Keto de Coliflor y Pollo 🍕',
        calories: 420,
        protein: 36.0,
        carbs: 12.0,
        fat: 25.0,
        time: '30 min',
        difficulty: 'Medio',
        imageUrl:
            'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&q=80&w=400',
        ingredients: [
          '1 taza de masa de coliflor rallada y escurrida',
          '1 huevo entero',
          '50g de queso mozzarella bajo en grasa rallado',
          '100g de pechuga de pollo desmenuzada',
          '2 cucharadas de salsa de tomate sin azúcar añadido',
        ],
        steps: [
          'Precalienta el horno a 200°C. Mezcla la coliflor con el huevo para formar la masa.',
          'Extiende la masa en una bandeja para hornear y hornea por 15 minutos hasta dorar.',
          'Saca del horno, unta la salsa de tomate, agrega el queso mozzarella y el pollo.',
          'Hornea por 10 minutos más hasta derretir el queso.',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
      Recipe(
        id: '9',
        title: 'Batido de Fresa y Plátano Proteico 🍓',
        calories: 340,
        protein: 32.0,
        carbs: 45.0,
        fat: 3.0,
        time: '5 min',
        difficulty: 'Muy Fácil',
        imageUrl:
            'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&q=80&w=400',
        ingredients: [
          '1 scoop (30g) de proteína de suero aislada sabor vainilla',
          '1 plátano congelado maduro',
          '5 fresas medianas frescas',
          '1 taza de leche de almendras sin azúcar',
        ],
        steps: [
          'Coloca todos los ingredientes en la licuadora.',
          'Licúa a máxima velocidad hasta lograr una textura cremosa y suave.',
          'Sirve en un vaso grande bien frío.',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 13)),
      ),
      Recipe(
        id: '10',
        title: 'Hamburguesa de Res con Pan Integral (Tolerada) 🍔',
        calories: 650,
        protein: 40.0,
        carbs: 48.0,
        fat: 32.0,
        time: '20 min',
        difficulty: 'Fácil',
        imageUrl:
            'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&q=80&w=400',
        ingredients: [
          '150g de carne de res molida magra (95/5)',
          '1 pan de hamburguesa integral con ajonjolí',
          '1 rodaja de queso cheddar bajo en grasa',
          'Rodajas de tomate, cebolla y hojas de lechuga',
          '1 cucharadita de mostaza dijon',
        ],
        steps: [
          'Forma la hamburguesa y cocínala a la plancha por 3-4 minutos de cada lado.',
          'Coloca el queso sobre la carne en el último minuto de cocción para que se derrita.',
          'Tuesta ligeramente las mitades del pan integral.',
          'Arma la hamburguesa agregando la mostaza, carne con queso, tomate, cebolla y lechuga.',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ];
    return _mockRecipes!;
  }

  Future<bool> createRecipe(Recipe recipe) async {
    try {
      final profile = await getUserProfile();
      final idEmpresa = profile?.idEmpresa ?? '';

      final Map<String, dynamic> insertData = {
        'title': recipe.title,
        'calories': recipe.calories,
        'protein': recipe.protein,
        'carbs': recipe.carbs,
        'fat': recipe.fat,
        'time': recipe.time,
        'difficulty': recipe.difficulty,
        'image_url': recipe.imageUrl,
        'ingredients': recipe.ingredients,
        'steps': recipe.steps,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        await client.from('recipes').insert({
          ...insertData,
          'IDEmpresa': idEmpresa,
        });
      } catch (e) {
        // Fallback: retry without IDEmpresa if column is missing in DB
        await client.from('recipes').insert(insertData);
      }
      return true;
    } catch (e) {
      print('Error in createRecipe: $e');
      return false;
    }
  }

  // --- RECETAS ASIGNADAS (PLAN DIETÉTICO) ---
  Future<List<AssignedRecipe>> getAssignedRecipes({
    String? userId,
    DateTime? date,
  }) async {
    if (_useMockData || !_isInitialized) {
      return _getMockAssignedRecipes(userId: userId, date: date);
    }
    try {
      final targetId = userId ?? client.auth.currentUser?.id;
      if (targetId == null) {
        return _getMockAssignedRecipes(userId: userId, date: date);
      }

      var query = client.from('assigned_recipes').select('*, recipes(*)');

      query = query.eq('user_id', targetId);

      if (date != null) {
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        query = query.eq('assigned_date', dateStr);
      }

      final response = await query.order('created_at', ascending: true);
      return (response as List)
          .map((json) => AssignedRecipe.fromJson(json))
          .toList();
    } catch (e) {
      if (e.toString().contains('PGRST205') ||
          e.toString().contains('relation') ||
          e.toString().contains('does not exist')) {
        // removed
      }
      return _getMockAssignedRecipes(userId: userId, date: date);
    }
  }

  List<AssignedRecipe> _getMockAssignedRecipes({
    String? userId,
    DateTime? date,
  })  { return []; if (_mockAssignedRecipes == null) {
      // Seed some initial mock assigned recipes
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final recipes = _getMockRecipes();

      _mockAssignedRecipes = [
        // Seed for Mateo ('mock-user-123')
        AssignedRecipe(
          id: 'ar-1',
          userId: 'mock-user-123',
          recipeId: '2', // Avena Proteica de Berries
          assignedDate: today,
          createdAt: now.subtract(const Duration(hours: 1)),
          recipe: recipes.firstWhere(
            (r) => r.id == '2',
            orElse: () => recipes[0],
          ),
        ),
        AssignedRecipe(
          id: 'ar-2',
          userId: 'mock-user-123',
          recipeId: '1', // Tazón de Salmón y Quinoa
          assignedDate: today,
          createdAt: now.subtract(const Duration(minutes: 30)),
          recipe: recipes.firstWhere(
            (r) => r.id == '1',
            orElse: () => recipes[0],
          ),
        ),
        // Seed for Sofia ('client-1')
        AssignedRecipe(
          id: 'ar-3',
          userId: 'client-1',
          recipeId: '3', // Pechuga Rellena
          assignedDate: today,
          createdAt: now,
          recipe: recipes.firstWhere(
            (r) => r.id == '3',
            orElse: () => recipes[0],
          ),
        ),
      ];
    }

    final targetId = userId ?? client.auth.currentUser?.id ?? 'mock-user-123';
    return _mockAssignedRecipes!.where((ar) {
      final matchUser = ar.userId == targetId;
      if (date == null) return matchUser;

      final d1 = DateTime(
        ar.assignedDate.year,
        ar.assignedDate.month,
        ar.assignedDate.day,
      );
      final d2 = DateTime(date.year, date.month, date.day);
      return matchUser && d1.isAtSameMomentAs(d2);
    }).toList();
  }

  Future<bool> assignRecipe({
    required String userId,
    required String recipeId,
    required DateTime date,
    String? notes,
  }) async {
    if (_useMockData || !_isInitialized) {
      if (_mockAssignedRecipes == null) {
        _getMockAssignedRecipes(userId: userId, date: date);
      }
      final recipes = _getMockRecipes();
      final recipe = recipes.firstWhere(
        (r) => r.id == recipeId,
        orElse: () => recipes[0],
      );

      // Check if already assigned
      final exists = _mockAssignedRecipes!.any(
        (ar) =>
            ar.userId == userId &&
            ar.recipeId == recipeId &&
            ar.assignedDate.year == date.year &&
            ar.assignedDate.month == date.month &&
            ar.assignedDate.day == date.day,
      );

      if (exists) return true;

      final newItem = AssignedRecipe(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        recipeId: recipeId,
        assignedDate: DateTime(date.year, date.month, date.day),
        createdAt: DateTime.now(),
        recipe: recipe,
        notes: notes,
      );
      _mockAssignedRecipes!.add(newItem);
      return true;
    }

    try {
      _errorMessage = null;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final Map<String, dynamic> payload = {
        'user_id': userId,
        'recipe_id': recipeId,
        'assigned_date': dateStr,
      };
      if (notes != null) {
        payload['notes'] = notes;
      }

      await client.from('assigned_recipes').upsert(
        payload,
        onConflict: 'user_id, recipe_id, assigned_date',
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      print('Error in assignRecipe: $e');
      return false;
    }
  }

  Future<bool> updateAssignedRecipeNotes({
    required String assignmentId,
    required String notes,
  }) async {
    if (_useMockData || !_isInitialized) {
      if (_mockAssignedRecipes != null) {
        final index = _mockAssignedRecipes!.indexWhere((ar) => ar.id == assignmentId);
        if (index != -1) {
          final ar = _mockAssignedRecipes![index];
          _mockAssignedRecipes![index] = AssignedRecipe(
            id: ar.id,
            userId: ar.userId,
            recipeId: ar.recipeId,
            assignedDate: ar.assignedDate,
            createdAt: ar.createdAt,
            recipe: ar.recipe,
            notes: notes,
          );
        }
      }
      return true;
    }

    try {
      await client
          .from('assigned_recipes')
          .update({'notes': notes})
          .eq('id', assignmentId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unassignRecipe({required String assignmentId}) async {
    if (_useMockData || !_isInitialized) {
      if (_mockAssignedRecipes != null) {
        _mockAssignedRecipes!.removeWhere((ar) => ar.id == assignmentId);
      }
      return true;
    }

    try {
      await client.from('assigned_recipes').delete().eq('id', assignmentId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- ÚLTIMAS 5 COMIDAS ---
  Future<List<MealItem>> getRecentMeals({String? userId}) async {
    if (_useMockData || !_isInitialized) {
      return _getMockMeals(userId: userId);
    }
    try {
      final targetId = userId ?? client.auth.currentUser?.id;
      if (targetId == null) {
        return _getMockMeals(userId: userId);
      }

      final response = await client
          .from('comidas')
          .select()
          .eq('user_id', targetId)
          .order('consumed_at', ascending: false)
          .limit(5);
      return (response as List).map((json) => MealItem.fromJson(json)).toList();
    } catch (e) {
      if (e.toString().contains('PGRST205') ||
          e.toString().contains('relation') ||
          e.toString().contains('does not exist')) {
        // removed
      }
      return _getMockMeals(userId: userId);
    }
  }

  // --- TODAS LAS COMIDAS PARA EL HISTORIAL ---
  Future<List<MealItem>> getAllMeals({String? userId}) async {
    if (_useMockData || !_isInitialized) {
      return _getMockMeals(userId: userId);
    }
    try {
      final targetId = userId ?? client.auth.currentUser?.id;
      if (targetId == null) {
        return _getMockMeals(userId: userId);
      }

      final response = await client
          .from('comidas')
          .select()
          .eq('user_id', targetId)
          .order('consumed_at', ascending: false);
      return (response as List).map((json) => MealItem.fromJson(json)).toList();
    } catch (e) {
      if (e.toString().contains('PGRST205') ||
          e.toString().contains('relation') ||
          e.toString().contains('does not exist')) {
        // removed
      }
      return _getMockMeals(userId: userId);
    }
  }

  void _initMockMeals() {
    if (_mockMealsByUser != null) return;
    final now = DateTime.now();
    _mockMealsByUser = {
      // Client-1 (Sofía)
      'client-1': [
        MealItem(
          id: 'm-1',
          name: 'Filete de salmón al horno con espárragos 🐟',
          calories: 420,
          protein: 38.0,
          carbs: 10.0,
          fat: 16.0,
          consumedAt: now.subtract(const Duration(hours: 2)),
          imageUrl:
              'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&q=80&w=300',
        ),
        MealItem(
          id: 'm-2',
          name: 'Yogur griego con frutos rojos 🍓',
          calories: 150,
          protein: 16.0,
          carbs: 12.0,
          fat: 2.0,
          consumedAt: now.subtract(const Duration(hours: 5)),
          imageUrl:
              'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&q=80&w=300',
        ),
        MealItem(
          id: 'm-1b',
          name: 'Tacos de bistec con salsa verde 🌮',
          calories: 480,
          protein: 28.0,
          carbs: 38.0,
          fat: 14.0,
          consumedAt: now.subtract(const Duration(days: 1, hours: 4)),
        ),
      ],
      // Client-2 (Alejandro)
      'client-2': [
        MealItem(
          id: 'm-3',
          name: 'Pechuga de pollo con arroz blanco y aguacate 🍗',
          calories: 680,
          protein: 48.0,
          carbs: 65.0,
          fat: 15.0,
          consumedAt: now.subtract(const Duration(hours: 3)),
          imageUrl:
              'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&q=80&w=300',
        ),
        MealItem(
          id: 'm-4',
          name: 'Batido de avena, plátano y crema de cacahuate 🥤',
          calories: 520,
          protein: 25.0,
          carbs: 70.0,
          fat: 16.0,
          consumedAt: now.subtract(const Duration(hours: 7)),
        ),
        MealItem(
          id: 'm-4b',
          name: 'Ensalada de quinoa con garbanzos 🥗',
          calories: 390,
          protein: 14.0,
          carbs: 58.0,
          fat: 8.0,
          consumedAt: now.subtract(const Duration(days: 2)),
        ),
      ],
      // Client-3 (Natalia)
      'client-3': [
        MealItem(
          id: 'm-5',
          name: 'Ensalada de quinoa con atún y garbanzos 🥗',
          calories: 380,
          protein: 28.0,
          carbs: 45.0,
          fat: 8.0,
          consumedAt: now.subtract(const Duration(hours: 4)),
        ),
        MealItem(
          id: 'm-6',
          name: 'Atún sellado con sésamo y espárragos 🐟',
          calories: 320,
          protein: 34.0,
          carbs: 6.0,
          fat: 12.0,
          consumedAt: now.subtract(const Duration(days: 1)),
        ),
      ],
      // Default / Mateo
      'mock-user-123': [
        MealItem(
          id: '1',
          name: 'Filete de salmón al horno con espárragos y camote 🐟',
          calories: 490,
          protein: 35.0,
          carbs: 35.0,
          fat: 18.0,
          consumedAt: now.subtract(const Duration(hours: 2)),
          imageUrl:
              'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&q=80&w=300',
        ),
        MealItem(
          id: '2',
          name: 'Yogur griego con fresas orgánicas y chía 🍓',
          calories: 180,
          protein: 15.0,
          carbs: 15.0,
          fat: 4.0,
          consumedAt: now.subtract(const Duration(hours: 6)),
          imageUrl:
              'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&q=80&w=300',
        ),
        MealItem(
          id: '3',
          name: 'Pechuga de pollo a la plancha con quinoa y vegetales 🍗',
          calories: 550,
          protein: 45.0,
          carbs: 50.0,
          fat: 12.0,
          consumedAt: now.subtract(const Duration(hours: 10)),
          imageUrl:
              'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&q=80&w=300',
        ),
        MealItem(
          id: '4',
          name: 'Tacos de carne asada con cebolla y cilantro 🌮',
          calories: 520,
          protein: 30.0,
          carbs: 45.0,
          fat: 16.0,
          consumedAt: now.subtract(const Duration(days: 1, hours: 2)),
          imageUrl:
              'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&q=80&w=300',
        ),
        MealItem(
          id: '5',
          name: 'Ensalada de atún con aguacate y tomate 🥗',
          calories: 380,
          protein: 28.0,
          carbs: 12.0,
          fat: 22.0,
          consumedAt: now.subtract(const Duration(days: 3)),
          imageUrl:
              'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=300',
        ),
        MealItem(
          id: '6',
          name: 'Batido de proteína con plátano y avena 🍌',
          calories: 410,
          protein: 32.0,
          carbs: 52.0,
          fat: 6.0,
          consumedAt: now.subtract(const Duration(days: 10)),
        ),
      ],
    };
  }

  List<MealItem> _getMockMeals({String? userId})  { return [];
    _initMockMeals();
    final targetId = userId ?? _currentUserProfile?.userID ?? 'mock-user-123';
    return _mockMealsByUser![targetId] ?? [];
  }

  // Update the user's preferred payment method
  Future<void> updatePaymentMethod(String method) async {
    try {
      final userId = _currentUserProfile?.userID ?? 'mock-user-123';
      print('Updating payment method for $userId to: $method');
      // TODO: persist to Supabase when payment_method column is added to users table
      // await _supabase.from('users').update({'payment_method': method}).eq('userID', userId);
    } catch (e) {
      print('Error updating payment method: $e');
      rethrow;
    }
  }

  // Update user's payment cutoff date
  Future<bool> updateNextPaymentDate(String userId, DateTime newDate) async {
    if (_useMockData || !_isInitialized) {
      // For mock mode we just succeed
      return true;
    }
    try {
      await client
          .from('users')
          .update({'next_payment_date': newDate.toIso8601String()})
          .eq('userID', userId);

      // Registrar el pago en la tabla de registro_pagos automáticamente
      try {
        final userRow = await client
            .from('users')
            .select('IDEmpresa')
            .eq('userID', userId)
            .maybeSingle();
        final idEmpresa = userRow?['IDEmpresa']?.toString();
        if (idEmpresa != null && idEmpresa.trim().isNotEmpty) {
          await registerPayment(
            idEmpresa: idEmpresa,
            clienteId: userId,
            monto: 499.0, // Cuota estándar
            tipo: 'cliente_a_entrenador',
            concepto: 'Membresía mensual cliente',
          );
        }
      } catch (innerErr) {
        print('Error recording auto payment during updateNextPaymentDate: $innerErr');
      }

      return true;
    } catch (e) {
      print('Error updating next payment date: $e');
      return false;
    }
  }

  // Registrar un pago en la tabla registro_pagos
  Future<bool> registerPayment({
    required String idEmpresa,
    String? clienteId,
    required double monto,
    required String tipo,
    required String concepto,
    DateTime? fecha,
  }) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      final data = <String, dynamic>{
        'IDEmpresa': idEmpresa,
        'monto': monto,
        'tipo': tipo,
        'concepto': concepto,
        'fecha': (fecha ?? DateTime.now()).toIso8601String(),
      };
      if (clienteId != null) {
        data['cliente_id'] = clienteId;
      }
      await client.from('registro_pagos').insert(data).timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      print('Error registering payment: $e');
      return false;
    }
  }

  // Obtener pagos por empresa
  Future<List<Map<String, dynamic>>> getPaymentsByEmpresa(String idEmpresa) async {
    if (_useMockData || !_isInitialized) {
      return [];
    }
    try {
      final response = await client
          .from('registro_pagos')
          .select()
          .eq('IDEmpresa', idEmpresa)
          .order('fecha', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error getting payments by empresa: $e');
      return [];
    }
  }

  /// Obtener el historial de pagos de un cliente específico desde registro_pagos
  Future<List<Map<String, dynamic>>> getPaymentsByClient(String clienteId) async {
    if (_useMockData || !_isInitialized) {
      return [];
    }
    try {
      final response = await client
          .from('registro_pagos')
          .select()
          .eq('cliente_id', clienteId)
          .order('fecha', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error getting payments by client: $e');
      return [];
    }
  }

  // Obtener todos los pagos (exclusivo para superAdmin)
  Future<List<Map<String, dynamic>>> getAllPayments() async {
    if (_useMockData || !_isInitialized) {
      return [];
    }
    try {
      final response = await client
          .from('registro_pagos')
          .select()
          .order('fecha', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error getting all payments: $e');
      return [];
    }
  }

  // ============================================================================
  // GESTIÓN DE SUSCRIPCIONES Y CONFIGURACIÓN FINANCIERA (MULTI-TENANT)
  // ============================================================================

  /// Obtiene las suscripciones de todos los clientes pertenecientes a una empresa
  Future<List<ClientSubscription>> getClientSubscriptionsByEmpresa(String idEmpresa) async {
    if (_useMockData || !_isInitialized) return [];
    try {
      final response = await client
          .from('cliente_suscripciones')
          .select()
          .eq('IDEmpresa', idEmpresa);
      return (response as List).map((json) => ClientSubscription.fromJson(json)).toList();
    } catch (e) {
      print('Error getting client subscriptions: $e');
      return [];
    }
  }

  /// Obtiene la suscripción individual de un cliente
  Future<ClientSubscription?> getClientSubscription(String clienteId) async {
    if (_useMockData || !_isInitialized) return null;
    try {
      final response = await client
          .from('cliente_suscripciones')
          .select()
          .eq('cliente_id', clienteId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      if (response == null) return null;
      return ClientSubscription.fromJson(response);
    } catch (e) {
      print('Error getting client subscription for $clienteId: $e');
      return null;
    }
  }

  /// Inserta o actualiza la suscripción de un cliente
  Future<bool> upsertClientSubscription({
    required String clienteId,
    required String idEmpresa,
    required double montoMensualidad,
    required DateTime proximaFechaPago,
    String estatus = 'al_corriente',
    int diasGracia = 3,
    String? notas,
  }) async {
    if (_useMockData || !_isInitialized) return true;
    try {
      final data = {
        'cliente_id': clienteId,
        'IDEmpresa': idEmpresa,
        'monto_mensualidad': montoMensualidad,
        'proxima_fecha_pago': proximaFechaPago.toIso8601String().substring(0, 10),
        'estatus': estatus,
        'dias_gracia': diasGracia,
        if (notas != null) 'notas': notas,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client
          .from('cliente_suscripciones')
          .upsert(data, onConflict: 'cliente_id')
          .timeout(const Duration(seconds: 6));
      
      // Sincronizar también con next_payment_date en la tabla users de forma no bloqueante
      try {
        await client
            .from('users')
            .update({'next_payment_date': proximaFechaPago.toIso8601String()})
            .eq('userID', clienteId)
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        print('Warning: No se pudo actualizar next_payment_date en users: $e');
      }

      return true;
    } catch (e) {
      print('Error upserting client subscription: $e');
      return false;
    }
  }

  /// Registrar pago manual y extender la fecha de corte (+30 días o fecha dada)
  Future<bool> processManualPayment({
    required String clienteId,
    required String idEmpresa,
    required double monto,
    String concepto = 'Pago mensualidad (Efectivo)',
    String estatus = 'al_corriente',
    DateTime? customNextDate,
  }) async {
    if (_useMockData || !_isInitialized) return true;
    try {
      // 1. Obtener la suscripción actual del cliente para calcular la nueva fecha de corte
      final currentSub = await getClientSubscription(clienteId);
      final baseDate = currentSub != null && currentSub.proximaFechaPago.isAfter(DateTime.now())
          ? currentSub.proximaFechaPago
          : DateTime.now();
          
      final newNextDate = customNextDate ?? (estatus == 'al_corriente' 
          ? baseDate.add(const Duration(days: 30))
          : (currentSub?.proximaFechaPago ?? DateTime.now()));

      // 2. Actualizar suscripción
      await upsertClientSubscription(
        clienteId: clienteId,
        idEmpresa: idEmpresa,
        montoMensualidad: monto,
        proximaFechaPago: newNextDate,
        estatus: estatus,
      );

      // 3. Registrar la transacción en registro_pagos solo si se completó el pago
      if (estatus == 'al_corriente') {
        await registerPayment(
          idEmpresa: idEmpresa,
          clienteId: clienteId,
          monto: monto,
          tipo: 'cliente_a_entrenador',
          concepto: concepto,
        );
      }

      return true;
    } catch (e) {
      print('Error processing manual payment: $e');
      return false;
    }
  }

  /// Obtiene la configuración de pasarela de pago de la empresa
  Future<PaymentConfig?> getPaymentConfigByEmpresa(String idEmpresa) async {
    if (_useMockData || !_isInitialized) return null;
    try {
      final response = await client
          .from('config_pagos_empresa')
          .select()
          .eq('IDEmpresa', idEmpresa)
          .maybeSingle();
      if (response == null) return null;
      return PaymentConfig.fromJson(response);
    } catch (e) {
      print('Error getting payment config for $idEmpresa: $e');
      return null;
    }
  }

  /// Guarda o actualiza la configuración de pasarela de pago de la empresa
  Future<bool> savePaymentConfig(PaymentConfig config) async {
    if (_useMockData || !_isInitialized) return true;
    try {
      final data = config.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();
      await client.from('config_pagos_empresa').upsert(data, onConflict: 'IDEmpresa');
      return true;
    } catch (e) {
      print('Error saving payment config: $e');
      return false;
    }
  }


  // Log a new meal
  Future<bool> addMeal(
    String name,
    int calories,
    double protein,
    double carbs,
    double fat, {
    String? userId,
    String? imageUrl,
    DateTime? consumedAt,
  }) async {
    final targetId = userId ?? client.auth.currentUser?.id;
    if (_useMockData || !_isInitialized || targetId == null) {
      _initMockMeals();
      final userKey = userId ?? _currentUserProfile?.userID ?? 'mock-user-123';
      final newItem = MealItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        consumedAt: consumedAt ?? DateTime.now(),
        imageUrl: imageUrl,
      );
      if (!_mockMealsByUser!.containsKey(userKey)) {
        _mockMealsByUser![userKey] = [];
      }
      _mockMealsByUser![userKey]!.insert(0, newItem);
      return true;
    }
    try {
      await client.from('comidas').insert({
        'user_id': targetId,
        'name': name,
        'consumed_at': (consumedAt ?? DateTime.now()).toIso8601String(),
        'fotourl': imageUrl,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteMeal(String id, {String? userId}) async {
    if (_useMockData || !_isInitialized) {
      _initMockMeals();
      final userKey = userId ?? _currentUserProfile?.userID ?? 'mock-user-123';
      if (_mockMealsByUser!.containsKey(userKey)) {
        _mockMealsByUser![userKey]!.removeWhere((meal) => meal.id == id);
      }
      return true;
    }
    try {
      await client.from('comidas').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> uploadRecipePhoto(dynamic imageFile) async {
    final targetId = client.auth.currentUser?.id ?? 'mock-user-123';
    if (_useMockData || !_isInitialized || imageFile == null) {
      return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=500';
    }
    try {
      final bytes = imageFile.path.startsWith('http')
          ? await http.readBytes(Uri.parse(imageFile.path))
          : await imageFile.readAsBytes();
      final fileName =
          'recipes/${targetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage
          .from('general')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      return client.storage.from('general').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadMealPhoto(dynamic imageFile) async {
    final targetId = client.auth.currentUser?.id ?? 'mock-user-123';
    if (_useMockData || !_isInitialized || imageFile == null) {
      return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=500';
    }
    try {
      final bytes = imageFile.path.startsWith('http')
          ? await http.readBytes(Uri.parse(imageFile.path))
          : await imageFile.readAsBytes();
      final fileName =
          'meals/${targetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage
          .from('general')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      return client.storage.from('general').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  Future<List<UserProfile>> getAllClients() async {
    if (_useMockData || !_isInitialized) {
      return _getMockClients();
    }
    try {
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null) return [];

      // 1. Get current trainer's IDEmpresa
      String? currentEmpresaId;
      final trainerUserRow = await client
          .from('users')
          .select('IDEmpresa')
          .eq('userID', currentUserId)
          .maybeSingle();
      if (trainerUserRow != null && trainerUserRow['IDEmpresa'] != null) {
        currentEmpresaId = trainerUserRow['IDEmpresa']?.toString();
      }

      // Fallback: Try to get from EmpresasEntrenadores table
      if (currentEmpresaId == null || currentEmpresaId.trim().isEmpty) {
        final userEmail = client.auth.currentUser?.email;
        if (userEmail != null && userEmail.isNotEmpty) {
          final empresaRow = await client
              .from('EmpresasEntrenadores')
              .select('IDEmpresa')
              .eq('correo_electronico', userEmail)
              .maybeSingle();
          if (empresaRow != null && empresaRow['IDEmpresa'] != null) {
            currentEmpresaId = empresaRow['IDEmpresa']?.toString();
          }
        }
      }

      if (currentEmpresaId == null || currentEmpresaId.trim().isEmpty) {
        return [];
      }

      // 2. Fetch clients matching the trainer's IDEmpresa
      final response = await client
          .from('users')
          .select()
          .eq('is_admin', false)
          .eq('IDEmpresa', currentEmpresaId)
          .order('name', ascending: true);
      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<double> getClientObjectivesProgress(String clientUserId) async {
    if (_useMockData || !_isInitialized) {
      return 0.0;
    }
    try {
      final response = await client
          .from('objetivos')
          .select('completed')
          .eq('user_id', clientUserId);

      final objectives = response as List;
      if (objectives.isEmpty) return 0.0;

      final completed = objectives.where((o) => o['completed'] == true).length;
      return (completed / objectives.length) * 100.0;
    } catch (e) {
      print('Error in getClientObjectivesProgress: $e');
      return 0.0;
    }
  }

  List<UserProfile> _getMockClients()  { return []; return [];
    if (_mockClients != null) {
      return _mockClients!;
    }
    _mockClients = [
      UserProfile(
        userID: 'client-1',
        email: 'sofia@client.com',
        name: 'Sofía Guerrero',
        currentWeight: 68.0,
        initialWeight: 80.0,
        targetWeight: 60.0,
        height: 165.0,
        age: 26,
        isAdmin: false,
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      UserProfile(
        userID: 'client-2',
        email: 'alejandro@client.com',
        name: 'Alejandro Morales',
        currentWeight: 82.0,
        initialWeight: 76.0,
        targetWeight: 85.0,
        height: 178.0,
        age: 30,
        isAdmin: false,
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      UserProfile(
        userID: 'client-3',
        email: 'natalia@client.com',
        name: 'Natalia Peña',
        currentWeight: 59.5,
        initialWeight: 63.0,
        targetWeight: 57.0,
        height: 160.0,
        age: 24,
        isAdmin: false,
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
    return _mockClients!;
  }

  // --- AUTHENTICATION ---

  User? get currentUser => _isInitialized ? client.auth.currentUser : null;

  Stream<AuthState> get authStateChanges {
    if (!_isInitialized) {
      return const Stream.empty();
    }
    return client.auth.onAuthStateChange;
  }

  Future<bool> signIn(String email, String password) async {
    if (!_isInitialized) {
      // removed
      _setMockUserSession(email);
      return true;
    }
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      // removed

      // Check if this user/trainer is inhabilitado
      final userId = client.auth.currentUser?.id;
      if (userId != null && await _isUserSuspended(userId)) {
        await client.auth.signOut();
        throw Exception('Tu cuenta ha sido suspendida. Contacta a tu administrador para reactivarla.');
      }

      return true;
    } catch (e) {
      // removed
      rethrow;
    }
  }

  Future<bool> signInDemo(bool coach) async {
    // removed
    _setMockUserSession(
      coach ? 'coach@personaltrainer.com' : 'mateo@personaltrainer.com',
    );
    return true;
  }

  void _setMockUserSession(String email) {
    bool isAdmin =
        email.toLowerCase().contains('admin') ||
        email.toLowerCase().contains('coach');
    _currentUserProfile = UserProfile(
      userID: 'mock-user-123',
      email: email,
      name: isAdmin ? 'Coach Carlos' : 'Mateo Fernández',
      currentWeight: 78.5,
      targetWeight: 72.0,
      initialWeight: 85.0,
      height: 180.0,
      age: 28,
      isAdmin: isAdmin,
      updatedAt: DateTime.now(),
      nextPaymentDate: isAdmin
          ? null
          : DateTime.now().add(const Duration(days: 12)),
    );
    _authStreamController.add(_currentUserProfile);
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required bool isAdmin,
    required double weight,
    required double height,
    required int age,
  }) async {
    if (!_isInitialized) {
      // removed
      _setMockUserRegisteredSession(
        email: email,
        name: name,
        isAdmin: isAdmin,
        weight: weight,
        height: height,
        age: age,
      );
      return true;
    }
    try {
      await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'is_admin': isAdmin,
          'weight': weight,
          'height': height,
          'age': age,
          'initial_weight': weight,
          'target_weight': weight - 5.0,
        },
      );
      // removed
      return true;
    } catch (e) {
      // removed
      rethrow;
    }
  }

  void _setMockUserRegisteredSession({
    required String email,
    required String name,
    required bool isAdmin,
    required double weight,
    required double height,
    required int age,
  }) {
    _currentUserProfile = UserProfile(
      userID: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: name,
      currentWeight: weight,
      targetWeight: weight - 5.0,
      initialWeight: weight,
      height: height,
      age: age,
      isAdmin: isAdmin,
      updatedAt: DateTime.now(),
      nextPaymentDate: isAdmin
          ? null
          : DateTime.now().add(const Duration(days: 30)),
    );
    _authStreamController.add(_currentUserProfile);
  }

  Future<void> signOut() async {
    if (_isInitialized) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    _currentUserProfile = null;
    _mockExercises = null;
    _mockMealsByUser = null;
    _authStreamController.add(null);
    // removed
  }

  // --- REGISTRATION QUESTIONS (Cuestionario de Registro) ---

  List<RegistrationQuestion>? _mockQuestions;

  void _initMockQuestions() {
    if (_mockQuestions != null) return;
    final now = DateTime.now();
    _mockQuestions = [
      RegistrationQuestion(
        id: 'q-1',
        questionText:
            '¿Cuál es tu objetivo principal? (Perder peso, ganar masa muscular, mejorar resistencia, etc.)',
        isRequired: true,
        sortOrder: 1,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      RegistrationQuestion(
        id: 'q-2',
        questionText:
            '¿Tienes alguna lesión o condición médica que debamos considerar?',
        isRequired: true,
        sortOrder: 2,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      RegistrationQuestion(
        id: 'q-3',
        questionText:
            '¿Con qué frecuencia haces ejercicio actualmente? (Días por semana)',
        isRequired: true,
        sortOrder: 3,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      RegistrationQuestion(
        id: 'q-4',
        questionText: '¿Tienes alguna alergia o restricción alimentaria?',
        isRequired: false,
        sortOrder: 4,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    ];
  }

  Future<List<RegistrationQuestion>> getRegistrationQuestions() async {
    if (_useMockData || !_isInitialized) {
      _initMockQuestions();
      return _mockQuestions!.where((q) => q.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    try {
      final currentUserId = client.auth.currentUser?.id;
      String? currentEmpresaId;
      if (currentUserId != null) {
        final trainerUserRow = await client
            .from('users')
            .select('IDEmpresa')
            .eq('userID', currentUserId)
            .maybeSingle();
        if (trainerUserRow != null && trainerUserRow['IDEmpresa'] != null) {
          currentEmpresaId = trainerUserRow['IDEmpresa']?.toString();
        }
        if (currentEmpresaId == null || currentEmpresaId.trim().isEmpty) {
          final empresaRow = await client
              .from('EmpresasEntrenadores')
              .select('IDEmpresa')
              .eq('userID', currentUserId)
              .maybeSingle();
          if (empresaRow != null && empresaRow['IDEmpresa'] != null) {
            currentEmpresaId = empresaRow['IDEmpresa']?.toString();
          }
        }
      }

      var query = client
          .from('registration_questions')
          .select()
          .eq('is_active', true);
      
      if (currentEmpresaId != null && currentEmpresaId.trim().isNotEmpty) {
        query = query.eq('IDEmpresa', currentEmpresaId);
      } else {
        // If we don't have a trainer's company, return nothing or filter to empty
        return [];
      }

      final response = await query.order('sort_order', ascending: true);
      return (response as List)
          .map((json) => RegistrationQuestion.fromJson(json))
          .toList();
    } catch (e) {
      _initMockQuestions();
      return _mockQuestions!.where((q) => q.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
  }

  Future<List<RegistrationQuestion>> getAllRegistrationQuestions() async {
    if (_useMockData || !_isInitialized) {
      _initMockQuestions();
      return List.from(_mockQuestions!)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    try {
      final currentUserId = client.auth.currentUser?.id;
      String? currentEmpresaId;
      if (currentUserId != null) {
        final trainerUserRow = await client
            .from('users')
            .select('IDEmpresa')
            .eq('userID', currentUserId)
            .maybeSingle();
        if (trainerUserRow != null && trainerUserRow['IDEmpresa'] != null) {
          currentEmpresaId = trainerUserRow['IDEmpresa']?.toString();
        }
        if (currentEmpresaId == null || currentEmpresaId.trim().isEmpty) {
          final empresaRow = await client
              .from('EmpresasEntrenadores')
              .select('IDEmpresa')
              .eq('userID', currentUserId)
              .maybeSingle();
          if (empresaRow != null && empresaRow['IDEmpresa'] != null) {
            currentEmpresaId = empresaRow['IDEmpresa']?.toString();
          }
        }
      }

      var query = client.from('registration_questions').select();
      
      if (currentEmpresaId != null && currentEmpresaId.trim().isNotEmpty) {
        query = query.eq('IDEmpresa', currentEmpresaId);
      } else {
        return [];
      }

      final response = await query.order('sort_order', ascending: true);
      return (response as List)
          .map((json) => RegistrationQuestion.fromJson(json))
          .toList();
    } catch (e) {
      _initMockQuestions();
      return List.from(_mockQuestions!)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
  }

  Future<bool> addRegistrationQuestion(
    String text,
    bool isRequired,
    int sortOrder,
  ) async {
    if (_useMockData || !_isInitialized) {
      _initMockQuestions();
      _mockQuestions!.add(
        RegistrationQuestion(
          id: 'q-${DateTime.now().millisecondsSinceEpoch}',
          questionText: text,
          isRequired: isRequired,
          sortOrder: sortOrder,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );
      return true;
    }
    try {
      final currentUserId = client.auth.currentUser?.id;
      String? currentEmpresaId;
      if (currentUserId != null) {
        final trainerUserRow = await client
            .from('users')
            .select('IDEmpresa')
            .eq('userID', currentUserId)
            .maybeSingle();
        if (trainerUserRow != null && trainerUserRow['IDEmpresa'] != null) {
          currentEmpresaId = trainerUserRow['IDEmpresa']?.toString();
        }
        if (currentEmpresaId == null || currentEmpresaId.trim().isEmpty) {
          final empresaRow = await client
              .from('EmpresasEntrenadores')
              .select('IDEmpresa')
              .eq('userID', currentUserId)
              .maybeSingle();
          if (empresaRow != null && empresaRow['IDEmpresa'] != null) {
            currentEmpresaId = empresaRow['IDEmpresa']?.toString();
          }
        }
      }

      await client.from('registration_questions').insert({
        'question_text': text,
        'is_required': isRequired,
        'sort_order': sortOrder,
        'is_active': true,
        'IDEmpresa': currentEmpresaId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateRegistrationQuestion(
    String id, {
    String? text,
    bool? isRequired,
    bool? isActive,
    int? sortOrder,
  }) async {
    if (_useMockData || !_isInitialized) {
      _initMockQuestions();
      final index = _mockQuestions!.indexWhere((q) => q.id == id);
      if (index == -1) return false;
      final old = _mockQuestions![index];
      _mockQuestions![index] = RegistrationQuestion(
        id: old.id,
        questionText: text ?? old.questionText,
        isRequired: isRequired ?? old.isRequired,
        sortOrder: sortOrder ?? old.sortOrder,
        isActive: isActive ?? old.isActive,
        createdAt: old.createdAt,
        createdBy: old.createdBy,
      );
      return true;
    }
    try {
      final data = <String, dynamic>{};
      if (text != null) data['question_text'] = text;
      if (isRequired != null) data['is_required'] = isRequired;
      if (isActive != null) data['is_active'] = isActive;
      if (sortOrder != null) data['sort_order'] = sortOrder;
      if (data.isEmpty) return true;
      await client.from('registration_questions').update(data).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteRegistrationQuestion(String id) async {
    if (_useMockData || !_isInitialized) {
      _initMockQuestions();
      _mockQuestions!.removeWhere((q) => q.id == id);
      return true;
    }
    try {
      await client.from('registration_questions').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- QUESTIONNAIRE ANSWERS ---

  Future<bool> saveQuestionnaireAnswers(
    String userId,
    List<Map<String, dynamic>> answers,
  ) async {
    if (_useMockData || !_isInitialized) {
      // In mock mode, just update the profile in memory
      return true;
    }
    try {
      await client
          .from('users')
          .update({'questionnaire_answers': answers})
          .eq('userID', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- REGISTROS DE MEDIDAS ---

  List<MeasurementRecord>? _mockRecords;

  void _initMockRecords() {
    if (_mockRecords != null) return;
    final now = DateTime.now();
    _mockRecords = [
      // mock-user-123 records
      MeasurementRecord(
        id: 'rec-1',
        userId: 'mock-user-123',
        createdAt: now.subtract(const Duration(days: 60)),
        photoUrl:
            'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=600',
        weight: 85.0,
        abdomen: 96.0,
        waist: 92.0,
        leg: 62.0,
        chest: 104.0,
        arm: 38.0,
        calf: 41.0,
        cuello: 39.5,
      ),
      MeasurementRecord(
        id: 'rec-2',
        userId: 'mock-user-123',
        createdAt: now.subtract(const Duration(days: 45)),
        photoUrl:
            'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&q=80&w=600',
        weight: 83.2,
        abdomen: 94.0,
        waist: 90.0,
        leg: 61.5,
        chest: 103.0,
        arm: 37.8,
        calf: 40.8,
        cuello: 39.0,
      ),
      MeasurementRecord(
        id: 'rec-3',
        userId: 'mock-user-123',
        createdAt: now.subtract(const Duration(days: 30)),
        photoUrl:
            'https://images.unsplash.com/photo-1518310383802-640c2de311b2?auto=format&fit=crop&q=80&w=600',
        weight: 81.5,
        abdomen: 92.0,
        waist: 88.0,
        leg: 61.0,
        chest: 102.5,
        arm: 37.5,
        calf: 40.5,
        cuello: 38.5,
      ),
      MeasurementRecord(
        id: 'rec-4',
        userId: 'mock-user-123',
        createdAt: now.subtract(const Duration(days: 15)),
        photoUrl:
            'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?auto=format&fit=crop&q=80&w=600',
        weight: 79.8,
        abdomen: 90.0,
        waist: 86.0,
        leg: 60.5,
        chest: 102.0,
        arm: 37.2,
        calf: 40.2,
        cuello: 38.0,
      ),
      MeasurementRecord(
        id: 'rec-5',
        userId: 'mock-user-123',
        createdAt: now.subtract(const Duration(minutes: 5)),
        photoUrl:
            'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=600',
        weight: 78.5,
        abdomen: 88.5,
        waist: 84.0,
        leg: 60.0,
        chest: 101.5,
        arm: 37.0,
        calf: 40.0,
        cuello: 37.5,
      ),

      // client-2 (Alejandro Morales) records
      MeasurementRecord(
        id: 'rec-c2-1',
        userId: 'client-2',
        createdAt: now.subtract(const Duration(days: 60)),
        photoUrl:
            'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=600',
        weight: 76.0,
        abdomen: 80.0,
        waist: 78.0,
        leg: 55.0,
        chest: 95.0,
        arm: 32.0,
        calf: 36.0,
        cuello: 36.0,
      ),
      MeasurementRecord(
        id: 'rec-c2-2',
        userId: 'client-2',
        createdAt: now.subtract(const Duration(days: 45)),
        photoUrl:
            'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&q=80&w=600',
        weight: 77.5,
        abdomen: 81.0,
        waist: 79.0,
        leg: 56.0,
        chest: 97.0,
        arm: 33.0,
        calf: 36.5,
        cuello: 36.5,
      ),
      MeasurementRecord(
        id: 'rec-c2-3',
        userId: 'client-2',
        createdAt: now.subtract(const Duration(days: 30)),
        photoUrl:
            'https://images.unsplash.com/photo-1518310383802-640c2de311b2?auto=format&fit=crop&q=80&w=600',
        weight: 79.0,
        abdomen: 82.0,
        waist: 79.5,
        leg: 57.0,
        chest: 99.0,
        arm: 34.0,
        calf: 37.0,
        cuello: 37.0,
      ),
      MeasurementRecord(
        id: 'rec-c2-4',
        userId: 'client-2',
        createdAt: now.subtract(const Duration(days: 15)),
        photoUrl:
            'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?auto=format&fit=crop&q=80&w=600',
        weight: 80.5,
        abdomen: 82.5,
        waist: 80.0,
        leg: 58.0,
        chest: 100.5,
        arm: 35.0,
        calf: 37.5,
        cuello: 37.5,
      ),
      MeasurementRecord(
        id: 'rec-c2-5',
        userId: 'client-2',
        createdAt: now.subtract(const Duration(minutes: 5)),
        photoUrl:
            'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=600',
        weight: 82.0,
        abdomen: 83.0,
        waist: 80.5,
        leg: 59.0,
        chest: 102.0,
        arm: 36.0,
        calf: 38.0,
        cuello: 38.0,
      ),
    ];
  }

  Future<List<MeasurementRecord>> getMeasurementRecords({
    String? userId,
  }) async {
    final targetId = userId ?? (client.auth.currentUser?.id ?? 'mock-user-123');
    if (_useMockData || !_isInitialized) {
      _initMockRecords();
      return _mockRecords!.where((rec) => rec.userId == targetId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    try {
      final response = await client
          .from('registros_medidas')
          .select()
          .eq('user_id', targetId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => MeasurementRecord.fromJson(json))
          .toList();
    } catch (e) {
      _initMockRecords();
      return _mockRecords!.where((rec) => rec.userId == targetId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Future<bool> addMeasurementRecord(
    MeasurementRecord record, {
    dynamic imageFile,
    double? height,
  }) async {
    final targetId = record.userId.isNotEmpty
        ? record.userId
        : (client.auth.currentUser?.id ?? 'mock-user-123');

    String? uploadedPhotoUrl;

    if (imageFile != null) {
      if (_useMockData || !_isInitialized) {
        uploadedPhotoUrl =
            'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=600';
      } else {
        try {
          final bytes = imageFile.path.startsWith('http')
              ? await http.readBytes(Uri.parse(imageFile.path))
              : await imageFile.readAsBytes();
          final fileName =
              '${targetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

          await client.storage
              .from('general')
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              );

          uploadedPhotoUrl = client.storage
              .from('general')
              .getPublicUrl(fileName);
        } catch (e) {
          uploadedPhotoUrl =
              'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=600';
        }
      }
    }

    if (_useMockData || !_isInitialized) {
      _initMockRecords();
      final newRecord = MeasurementRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: targetId,
        createdAt: DateTime.now(),
        photoUrl: uploadedPhotoUrl ?? record.photoUrl,
        weight: record.weight,
        abdomen: record.abdomen,
        waist: record.waist,
        leg: record.leg,
        chest: record.chest,
        arm: record.arm,
        calf: record.calf,
        cuello: record.cuello,
      );
      _mockRecords!.add(newRecord);

      // Update mock profile in memory
      if (_currentUserProfile != null &&
          _currentUserProfile!.userID == targetId) {
        _currentUserProfile = UserProfile(
          userID: _currentUserProfile!.userID,
          email: _currentUserProfile!.email,
          name: _currentUserProfile!.name,
          currentWeight: record.weight,
          targetWeight: _currentUserProfile!.targetWeight,
          initialWeight: _currentUserProfile!.initialWeight,
          height: height ?? _currentUserProfile!.height,
          age: _currentUserProfile!.age,
          isAdmin: _currentUserProfile!.isAdmin,
          updatedAt: DateTime.now(),
          questionnaireAnswers: _currentUserProfile!.questionnaireAnswers,
        );
        _authStreamController.add(_currentUserProfile);
      }
      return true;
    }

    try {
      // 1. Insert measurement record
      await client.from('registros_medidas').insert({
        'user_id': targetId,
        'photo_url': uploadedPhotoUrl,
        'weight': record.weight,
        'abdomen': record.abdomen,
        'waist': record.waist,
        'leg': record.leg,
        'chest': record.chest,
        'arm': record.arm,
        'calf': record.calf,
        'cuello': record.cuello,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Update user's current weight (and height if present) in profiles table (users)
      final updateData = <String, dynamic>{'weight': record.weight};
      if (height != null) {
        updateData['height'] = height;
      }

      await client.from('users').update(updateData).eq('userID', targetId);

      // Trigger profile reload
      final profile = await getUserProfile();
      _currentUserProfile = profile;
      _authStreamController.add(profile);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteMeasurementRecord(String id) async {
    if (_useMockData || !_isInitialized) {
      _initMockRecords();
      _mockRecords!.removeWhere((rec) => rec.id == id);
      return true;
    }
    try {
      await client.from('registros_medidas').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- GENERAL EXERCISES (CATALOG) ---

  List<Exercise>? _mockCatalogExercises;

  void _initMockCatalogExercises() {
    if (_mockCatalogExercises != null) return;
    _mockCatalogExercises = [
      Exercise(
        id: 'exe-1',
        name: 'Sentadilla libre con barra',
        description:
            'Coloca la barra sobre los trapecios, desciende rompiendo el paralelo y sube con fuerza.',
        imageUrl:
            'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/barbell-full-squat.gif',
        category: 'Miembros Inferiores y Glúteos',
        createdAt: DateTime.now(),
      ),
      Exercise(
        id: 'exe-2',
        name: 'Peso Muerto Rumano',
        description:
            'Mantén la espalda recta, bisagra de cadera descendiendo la barra pegada a los muslos y siente el estímulo en femorales.',
        imageUrl:
            'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/hamstrings/barbell-romanian-deadlift.gif',
        category: 'Espalda y Trapecio',
        createdAt: DateTime.now(),
      ),
      Exercise(
        id: 'exe-3',
        name: 'Prensa de piernas',
        description:
            'Empuja la plataforma con los pies separados al ancho de hombros, baja controlando el peso.',
        imageUrl:
            'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/sled-45-leg-press.gif',
        category: 'Miembros Inferiores y Glúteos',
        createdAt: DateTime.now(),
      ),
      Exercise(
        id: 'exe-4',
        name: 'Calentamiento General',
        description:
            'Movilidad articular y activación general en elíptica o caminadora.',
        imageUrl:
            'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/cardio/walking-on-incline-treadmill.gif',
        category: 'General',
        createdAt: DateTime.now(),
      ),
      Exercise(
        id: 'exe-5',
        name: 'Press de banca plano',
        description:
            'Acostado en el banco, baja la barra al pecho y empuja verticalmente hasta extender los codos.',
        imageUrl:
            'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/chest/barbell-bench-press.gif',
        category: 'Pectoral',
        createdAt: DateTime.now(),
      ),
      Exercise(
        id: 'exe-6',
        name: 'Abducción de Caderas',
        description:
            'Sentado en la máquina, empuja las almohadillas hacia afuera controlando la apertura y mantén 2 segundos.',
        imageUrl:
            'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/seated-hip-abduction.gif',
        category: 'Miembros Inferiores y Glúteos',
        createdAt: DateTime.now(),
      ),
      Exercise(
        id: 'exe-7',
        name: 'Abdominal Corto',
        description:
            'Acostado boca arriba, flexiona el abdomen levantando ligeramente las escápulas del suelo.',
        imageUrl:
            'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/abs/crunch.gif',
        category: 'Abdomen Core',
        createdAt: DateTime.now(),
      ),
      Exercise(
        id: 'exe-8',
        name: 'Extensión de Pierna',
        description:
            'Sentado en la máquina, extiende las rodillas contrayendo los cuádriceps en la parte alta.',
        imageUrl:
            'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/quads/lever-leg-extension.gif',
        category: 'Miembros Inferiores y Glúteos',
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<List<Exercise>> getExercises() async {
    try {
      final response = await client.from('ejercicios').select().order('name');
      return (response as List).map((e) => Exercise.fromJson(e)).toList();
    } catch (e) {
      _initMockCatalogExercises();
      return List.from(_mockCatalogExercises!);
    }
  }

  Future<bool> addExercise(
    String name,
    String description,
    String? imageUrl, {
    String? category,
  }) async {
    if (_useMockData || !_isInitialized) {
      _initMockCatalogExercises();
      final newItem = Exercise(
        id: 'exe-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: description,
        imageUrl:
            imageUrl ??
            'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=300',
        category: category ?? 'General',
        createdAt: DateTime.now(),
      );
      _mockCatalogExercises!.add(newItem);
      return true;
    }
    try {
      await client.from('ejercicios').insert({
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'categoria': category ?? 'General',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateExercise(
    String id,
    String name,
    String description,
    String? imageUrl, {
    String? category,
  }) async {
    if (_useMockData || !_isInitialized) {
      _initMockCatalogExercises();
      final idx = _mockCatalogExercises!.indexWhere((e) => e.id == id);
      if (idx == -1) return false;
      _mockCatalogExercises![idx] = Exercise(
        id: id,
        name: name,
        description: description,
        imageUrl: imageUrl ?? _mockCatalogExercises![idx].imageUrl,
        category: category ?? _mockCatalogExercises![idx].category,
        createdAt: _mockCatalogExercises![idx].createdAt,
      );
      return true;
    }
    try {
      await client
          .from('ejercicios')
          .update({
            'name': name,
            'description': description,
            'image_url': imageUrl,
            'categoria': category,
          })
          .eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteExercise(String id) async {
    if (_useMockData || !_isInitialized) {
      _initMockCatalogExercises();
      _mockCatalogExercises!.removeWhere((e) => e.id == id);
      return true;
    }
    try {
      await client.from('ejercicios').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- ROUTINES ---

  List<Routine>? _mockRoutines;
  List<RoutineExercise>? _mockRoutineExercises;
  List<WorkoutLog>? _mockWorkoutLogs;
  void _initMockRoutines() {
    if (_mockRoutines != null) return;
    _initMockCatalogExercises();

    _mockRoutines = [
      Routine(
        id: 'rout-1',
        userId: 'mock-user-123',
        name: 'Gluteo femoral vol 2',
        assignedDate: DateTime.now(),
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        shareCode: 'GFV289',
      ),
      Routine(
        id: 'rout-2',
        userId: 'mock-user-123',
        name: 'Gluteo femoral valeria',
        assignedDate: null,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        shareCode: 'GFVVAL',
      ),
      Routine(
        id: 'rout-3',
        userId: 'mock-user-123',
        name: 'ABS',
        assignedDate: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        shareCode: 'ABS999',
      ),
    ];

    _mockRoutineExercises = [
      // Gluteo femoral vol 2
      RoutineExercise(
        id: 're-1',
        routineId: 'rout-1',
        exerciseId: 'exe-4', // Calentamiento
        sets: 1,
        reps: 1,
        seriesWeights: [0.0],
        seriesType: 'Normal',
        exerciseName: 'Calentamiento General',
        exerciseDescription: 'Eliptica y movimientos de activación',
        exerciseImageUrl:
            'https://images.unsplash.com/photo-1518310383802-640c2de311b2?auto=format&fit=crop&q=80&w=300',
      ),
      RoutineExercise(
        id: 're-2',
        routineId: 'rout-1',
        exerciseId: 'exe-2', // Peso Muerto Rumano
        sets: 4,
        reps: 12,
        seriesWeights: [50.0, 50.0, 50.0, 50.0],
        seriesType: 'Normal',
        exerciseName: 'Peso Muerto Rumano',
        exerciseDescription:
            'Baja en control 2 seg y sube normal en 1 seg, utiliza barras de peso integrado recta',
        exerciseImageUrl:
            'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=300',
      ),
      RoutineExercise(
        id: 're-3',
        routineId: 'rout-1',
        exerciseId: 'exe-8', // Extension de Pierna
        sets: 4,
        reps: 15,
        seriesWeights: [35.0, 35.0, 35.0, 35.0],
        seriesType: 'Normal',
        exerciseName: 'Extensión de Pierna',
        exerciseDescription: 'Contracción sostenida de 1 seg en la parte alta.',
        exerciseImageUrl:
            'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?auto=format&fit=crop&q=80&w=300',
      ),

      // Gluteo femoral valeria
      RoutineExercise(
        id: 're-4',
        routineId: 'rout-2',
        exerciseId: 'exe-3', // Prensa
        sets: 4,
        reps: 12,
        seriesWeights: [120.0, 120.0, 130.0, 130.0],
        seriesType: 'Normal',
        exerciseName: 'Prensa de piernas',
        exerciseDescription: 'Separación al ancho de hombros, rango completo.',
      ),

      // ABS
      RoutineExercise(
        id: 're-5',
        routineId: 'rout-3',
        exerciseId: 'exe-7', // Abdominal Corto
        sets: 4,
        reps: 20,
        seriesWeights: [0.0, 0.0, 0.0, 0.0],
        seriesType: 'Normal',
        exerciseName: 'Abdominal Corto',
        exerciseDescription: 'Rango controlado, exhala al contraer.',
      ),
    ];

    _mockWorkoutLogs = [
      WorkoutLog(
        id: 'wl-1',
        userId: 'mock-user-123',
        routineId: 'rout-3',
        routineName: 'ABS',
        completedAt: DateTime.now().subtract(const Duration(days: 2)),
        durationSeconds: 320,
        totalVolume: 0.0,
        totalSets: 4,
        loggedExercises: [
          {
            'exercise_name': 'Abdominal Corto',
            'sets': [
              {'weight': 0.0, 'reps': 20, 'completed': true},
              {'weight': 0.0, 'reps': 20, 'completed': true},
              {'weight': 0.0, 'reps': 20, 'completed': true},
              {'weight': 0.0, 'reps': 20, 'completed': true},
            ],
          },
        ],
      ),
    ];
  }

  Future<List<Routine>> getRoutines({String? userId}) async {
    final targetId = userId ?? client.auth.currentUser?.id;
    if (!_isInitialized || targetId == null) {
      return [];
    }
    try {
      final profile = await getUserProfile();
      final idEmpresa = profile.idEmpresa ?? '';

      dynamic response;
      try {
        var query = client.from('rutinas').select();
        if (userId != null && userId != client.auth.currentUser?.id) {
          query = query.eq('user_id', userId);
        } else if (idEmpresa.isNotEmpty) {
          query = query.eq('IDEmpresa', idEmpresa);
        } else {
          query = query.eq('user_id', targetId);
        }
        response = await query.order('created_at', ascending: false);
      } catch (e) {
        // Fallback: filter by user_id if IDEmpresa query fails
        response = await client
            .from('rutinas')
            .select()
            .eq('user_id', targetId)
            .order('created_at', ascending: false);
      }

      final routines = (response as List)
          .map((json) => Routine.fromJson(json))
          .toList();

      for (int i = 0; i < routines.length; i++) {
        final rId = routines[i].id;
        try {
          final exResponse = await client
              .from('rutina_ejercicios')
              .select('*, ejercicios(*)')
              .eq('routine_id', rId)
              .order('sort_order', ascending: true);

          final exercises = (exResponse as List)
              .map((exJson) => RoutineExercise.fromJson(exJson))
              .toList();
          routines[i] = Routine(
            id: routines[i].id,
            userId: routines[i].userId,
            name: routines[i].name,
            assignedDate: routines[i].assignedDate,
            createdAt: routines[i].createdAt,
            exercises: exercises,
            idEmpresa: routines[i].idEmpresa,
          );
        } catch (_) {}
      }
      return routines;
    } catch (e) {
      print('Error in getRoutines: $e');
      return [];
    }
  }

  Future<bool> addRoutine(String name, String userId) async {
    final code = _generateRandomShareCode();
    try {
      final profile = await getUserProfile();
      final idEmpresa = profile.idEmpresa;

      try {
        await client.from('rutinas').insert({
          'name': name,
          'user_id': userId,
          'share_code': code,
          'IDEmpresa': idEmpresa,
        });
      } catch (e) {
        // Fallback without IDEmpresa if column is missing
        await client.from('rutinas').insert({
          'name': name,
          'user_id': userId,
          'share_code': code,
        });
      }
      return true;
    } catch (e) {
      print('Error in addRoutine: $e');
      return false;
    }
  }

  Future<bool> assignTemplateRoutine(
    Routine template,
    String targetUserId,
  ) async {
    final code = _generateRandomShareCode();
    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      final newRoutineId = 'rout-${DateTime.now().millisecondsSinceEpoch}';
      final newRoutine = Routine(
        id: newRoutineId,
        userId: targetUserId,
        name: template.name,
        createdAt: DateTime.now(),
        shareCode: code,
      );
      _mockRoutines!.add(newRoutine);

      // Clone exercises in mock memory
      for (var re in template.exercises) {
        final newReId =
            're-${DateTime.now().millisecondsSinceEpoch}-${_mockRoutineExercises!.length}';
        final newRe = RoutineExercise(
          id: newReId,
          routineId: newRoutineId,
          exerciseId: re.exerciseId,
          sets: re.sets,
          reps: re.reps,
          seriesWeights: List.from(re.seriesWeights),
          seriesType: re.seriesType,
          exerciseName: re.exerciseName,
          exerciseDescription: re.exerciseDescription,
          exerciseImageUrl: re.exerciseImageUrl,
        );
        _mockRoutineExercises!.add(newRe);
      }
      return true;
    }

    try {
      // Get target user's IDEmpresa for the assigned routine
      final userResponse = await client
          .from('users')
          .select('IDEmpresa')
          .eq('userID', targetUserId)
          .maybeSingle();
      final targetIdEmpresa = userResponse?['IDEmpresa']?.toString();

      // 1. Insert routine copy and get its generated details
      final response = await client
          .from('rutinas')
          .insert({
            'name': template.name,
            'user_id': targetUserId,
            'share_code': code,
            'IDEmpresa': targetIdEmpresa,
          })
          .select()
          .single();

      final newRoutineId = response['id'].toString();

      // 2. Clone exercises
      if (template.exercises.isNotEmpty) {
        final List<Map<String, dynamic>> exercisesToInsert = template.exercises
            .map((re) {
              return {
                'routine_id': newRoutineId,
                'exercise_id': re.exerciseId,
                'sets': re.sets,
                'reps': re.reps,
                'series_weights': re.seriesWeights,
                'series_type': re.seriesType,
              };
            })
            .toList();

        await client.from('rutina_ejercicios').insert(exercisesToInsert);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- RUTINAS ASIGNADAS A CLIENTES CON PERSONALIZACIÓN Y FECHAS ---
  Future<List<AssignedRoutine>> getAssignedRoutines({required String userId}) async {
    if (_useMockData || !_isInitialized) {
      return [];
    }
    try {
      final response = await client
          .from('rutinas_asignadas')
          .select('*, rutinas(*)')
          .eq('user_id', userId)
          .order('assigned_date', ascending: true);

      return (response as List)
          .map((json) => AssignedRoutine.fromJson(json))
          .toList();
    } catch (e) {
      print('Error in getAssignedRoutines: $e');
      return [];
    }
  }

  Future<bool> assignRoutineToDates({
    required String userId,
    required String routineId,
    required List<DateTime> dates,
    List<RoutineExercise>? customExercises,
  }) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      _errorMessage = null;
      final profile = await getUserProfile();
      final idEmpresa = profile.idEmpresa;

      final List<Map<String, dynamic>> inserts = [];
      for (final date in dates) {
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        inserts.add({
          'user_id': userId,
          'routine_id': routineId,
          'assigned_date': dateStr,
          'idempresa': idEmpresa,
          'custom_exercises': customExercises != null
              ? customExercises.map((e) => e.toJson()).toList()
              : [],
        });
      }

      await client.from('rutinas_asignadas').insert(inserts);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      print('Error in assignRoutineToDates: $e');
      return false;
    }
  }

  Future<bool> updateAssignedRoutineParams({
    required String assignedRoutineId,
    required List<RoutineExercise> customExercises,
  }) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      await client
          .from('rutinas_asignadas')
          .update({
            'custom_exercises': customExercises.map((e) => e.toJson()).toList(),
          })
          .eq('id', assignedRoutineId);
      return true;
    } catch (e) {
      print('Error in updateAssignedRoutineParams: $e');
      return false;
    }
  }

  Future<bool> deleteAssignedRoutine(String assignedRoutineId) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      await client.from('rutinas_asignadas').delete().eq('id', assignedRoutineId);
      return true;
    } catch (e) {
      print('Error in deleteAssignedRoutine: $e');
      return false;
    }
  }

  // --- CLIENT OBJECTIVES ---
  Future<List<ClientObjective>> getClientObjectives(String userId) async {
    if (_useMockData || !_isInitialized) {
      return [];
    }
    try {
      final response = await client
          .from('objetivos')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      return (response as List).map((json) => ClientObjective.fromJson(json)).toList();
    } catch (e) {
      print('Error in getClientObjectives: $e');
      return [];
    }
  }

  Future<bool> addObjective({
    required String userId,
    required String title,
    String? description,
  }) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      final currentUserId = client.auth.currentUser?.id;
      String? idEmpresa;
      if (currentUserId != null) {
        final trainerUserRow = await client
            .from('users')
            .select('IDEmpresa')
            .eq('userID', currentUserId)
            .maybeSingle();
        if (trainerUserRow != null && trainerUserRow['IDEmpresa'] != null) {
          idEmpresa = trainerUserRow['IDEmpresa']?.toString();
        }

        if (idEmpresa == null || idEmpresa.trim().isEmpty) {
          final empresaRow = await client
              .from('EmpresasEntrenadores')
              .select('IDEmpresa')
              .eq('userID', currentUserId)
              .maybeSingle();
          if (empresaRow != null && empresaRow['IDEmpresa'] != null) {
            idEmpresa = empresaRow['IDEmpresa']?.toString();
          }
        }
      }

      await client.from('objetivos').insert({
        'user_id': userId,
        'title': title,
        'description': description,
        'completed': false,
        'IDEmpresa': idEmpresa,
      });
      return true;
    } catch (e, stack) {
      print('CRITICAL Error in addObjective: $e');
      print(stack);
      
      // Let's fallback to inserting only the basic fields in case 'completed' or 'IDEmpresa' column is missing from the remote database schema
      try {
        await client.from('objetivos').insert({
          'user_id': userId,
          'title': title,
          'description': description,
        });
        return true;
      } catch (fallbackError) {
        throw Exception('Error original: $e. Error de fallback: $fallbackError');
      }
    }
  }

  Future<bool> toggleObjectiveStatus(String objectiveId, bool completed) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      await client
          .from('objetivos')
          .update({'completed': completed})
          .eq('id', objectiveId);
      return true;
    } catch (e) {
      print('Error in toggleObjectiveStatus: $e');
      return false;
    }
  }

  Future<bool> deleteObjective(String objectiveId) async {
    if (_useMockData || !_isInitialized) {
      return true;
    }
    try {
      await client.from('objetivos').delete().eq('id', objectiveId);
      return true;
    } catch (e) {
      print('Error in deleteObjective: $e');
      return false;
    }
  }

  Future<bool> scheduleRoutine({
    required String routineId,
    required DateTime? date,
  }) async {
    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      final index = _mockRoutines!.indexWhere((r) => r.id == routineId);
      if (index != -1) {
        final r = _mockRoutines![index];
        _mockRoutines![index] = Routine(
          id: r.id,
          userId: r.userId,
          name: r.name,
          assignedDate: date,
          createdAt: r.createdAt,
          exercises: r.exercises,
          shareCode: r.shareCode,
        );
        return true;
      }
      return false;
    }

    try {
      final dateStr = date != null
          ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
          : null;
      await client
          .from('rutinas')
          .update({'assigned_date': dateStr})
          .eq('id', routineId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> duplicateRoutine(Routine routine, String newName) async {
    final code = _generateRandomShareCode();
    final userId = routine.userId;
    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      final newRoutineId = 'rout-${DateTime.now().millisecondsSinceEpoch}';
      final newRoutine = Routine(
        id: newRoutineId,
        userId: userId,
        name: newName,
        createdAt: DateTime.now(),
        shareCode: code,
      );
      _mockRoutines!.add(newRoutine);

      // Clone exercises in memory
      for (var re in routine.exercises) {
        final newReId =
            're-${DateTime.now().millisecondsSinceEpoch}-${_mockRoutineExercises!.length}';
        final newRe = RoutineExercise(
          id: newReId,
          routineId: newRoutineId,
          exerciseId: re.exerciseId,
          sets: re.sets,
          reps: re.reps,
          seriesWeights: List.from(re.seriesWeights),
          seriesType: re.seriesType,
          exerciseName: re.exerciseName,
          exerciseDescription: re.exerciseDescription,
          exerciseImageUrl: re.exerciseImageUrl,
        );
        _mockRoutineExercises!.add(newRe);
      }
      return true;
    }

    try {
      final profile = await getUserProfile();
      final idEmpresa = profile.idEmpresa;

      final response = await client
          .from('rutinas')
          .insert({
            'name': newName,
            'user_id': userId,
            'share_code': code,
            'IDEmpresa': idEmpresa,
          })
          .select()
          .single();

      final newRoutineId = response['id'].toString();

      if (routine.exercises.isNotEmpty) {
        int index = 0;
        final List<Map<String, dynamic>> exercisesToInsert = routine.exercises
            .map((re) {
              final item = {
                'routine_id': newRoutineId,
                'exercise_id': re.exerciseId,
                'sets': re.sets,
                'reps': re.reps,
                'series_weights': re.seriesWeights,
                'series_type': re.seriesType,
                'sort_order': index,
              };
              index++;
              return item;
            })
            .toList();

        await client.from('rutina_ejercicios').insert(exercisesToInsert);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteRoutine(String routineId) async {
    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      _mockRoutines!.removeWhere((r) => r.id == routineId);
      _mockRoutineExercises!.removeWhere((re) => re.routineId == routineId);
      return true;
    }
    try {
      await client.from('rutinas').delete().eq('id', routineId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<RoutineExercise>> getRoutineExercises(String routineId) async {
    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      return _mockRoutineExercises!
          .where((re) => re.routineId == routineId)
          .toList();
    }
    try {
      final response = await client
          .from('rutina_ejercicios')
          .select('*, ejercicios(*)')
          .eq('routine_id', routineId)
          .order('sort_order', ascending: true);
      return (response as List)
          .map((json) => RoutineExercise.fromJson(json))
          .toList();
    } catch (e) {
      _initMockRoutines();
      return _mockRoutineExercises!
          .where((re) => re.routineId == routineId)
          .toList();
    }
  }

  Future<bool> addRoutineExercise(RoutineExercise routineEx) async {
    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      _initMockCatalogExercises();
      final catalogEx = _mockCatalogExercises!.firstWhere(
        (e) => e.id == routineEx.exerciseId,
        orElse: () => Exercise(
          id: routineEx.exerciseId,
          name: 'Ejercicio',
          description: '',
          createdAt: DateTime.now(),
        ),
      );

      final newItem = RoutineExercise(
        id: 're-${DateTime.now().millisecondsSinceEpoch}',
        routineId: routineEx.routineId,
        exerciseId: routineEx.exerciseId,
        sets: routineEx.sets,
        reps: routineEx.reps,
        seriesWeights: routineEx.seriesWeights,
        seriesType: routineEx.seriesType,
        exerciseName: catalogEx.name,
        exerciseDescription: catalogEx.description,
        exerciseImageUrl: catalogEx.imageUrl,
      );
      _mockRoutineExercises!.add(newItem);
      return true;
    }
    try {
      await client.from('rutina_ejercicios').insert({
        'routine_id': routineEx.routineId,
        'exercise_id': routineEx.exerciseId,
        'sets': routineEx.sets,
        'reps': routineEx.reps,
        'series_weights': routineEx.seriesWeights,
        'series_type': routineEx.seriesType,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteRoutineExercise(String id) async {
    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      _mockRoutineExercises!.removeWhere((re) => re.id == id);
      return true;
    }
    try {
      await client.from('rutina_ejercicios').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- WORKOUT HISTORY LOGS ---

  Future<bool> saveWorkoutLog(WorkoutLog log) async {
    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      final newLog = WorkoutLog(
        id: 'wl-${DateTime.now().millisecondsSinceEpoch}',
        userId: log.userId.isNotEmpty ? log.userId : 'mock-user-123',
        routineId: log.routineId,
        routineName: log.routineName,
        completedAt: log.completedAt,
        durationSeconds: log.durationSeconds,
        totalVolume: log.totalVolume,
        totalSets: log.totalSets,
        loggedExercises: log.loggedExercises,
      );
      _mockWorkoutLogs!.add(newLog);
      return true;
    }
    try {
      await client.from('historial_entrenamientos').insert({
        'user_id': log.userId,
        'routine_id': log.routineId,
        'routine_name': log.routineName,
        'duration_seconds': log.durationSeconds,
        'total_volume': log.totalVolume,
        'total_sets': log.totalSets,
        'logged_exercises': log.loggedExercises,
        'completed_at': log.completedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<WorkoutLog>> getWorkoutLogs({String? userId}) async {
    final targetId = userId ?? (client.auth.currentUser?.id ?? 'mock-user-123');
    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      return _mockWorkoutLogs!.where((wl) => wl.userId == targetId).toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    }
    try {
      final response = await client
          .from('historial_entrenamientos')
          .select()
          .eq('user_id', targetId)
          .order('completed_at', ascending: false);
      return (response as List)
          .map((json) => WorkoutLog.fromJson(json))
          .toList();
    } catch (e) {
      _initMockRoutines();
      return _mockWorkoutLogs!.where((wl) => wl.userId == targetId).toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    }
  }

  // --- COMPARTIR Y IMPORTAR RUTINAS ---

  String _generateRandomShareCode() {
    final rand = Random();
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      6,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  Future<Routine?> getRoutineByShareCode(String code) async {
    String actualCode = code.trim();
    if (actualCode.contains('code=')) {
      actualCode = actualCode.split('code=').last;
    } else if (actualCode.contains('/')) {
      actualCode = actualCode.split('/').last;
    }
    actualCode = actualCode.toUpperCase();

    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      Routine? mockR;
      try {
        mockR = _mockRoutines!.firstWhere(
          (r) => (r.shareCode ?? '').toUpperCase() == actualCode,
        );
      } catch (_) {
        mockR = null;
      }
      if (mockR == null) return null;
      final rExs = _mockRoutineExercises!
          .where((re) => re.routineId == mockR!.id)
          .toList();
      return Routine(
        id: mockR.id,
        userId: mockR.userId,
        name: mockR.name,
        assignedDate: mockR.assignedDate,
        createdAt: mockR.createdAt,
        exercises: rExs,
        shareCode: mockR.shareCode,
      );
    }

    try {
      final response = await client
          .from('rutinas')
          .select()
          .eq('share_code', actualCode)
          .maybeSingle();

      if (response == null) return null;

      final routine = Routine.fromJson(response);
      final exResponse = await client
          .from('rutina_ejercicios')
          .select('*, ejercicios(*)')
          .eq('routine_id', routine.id)
          .order('sort_order', ascending: true);

      final exercises = (exResponse as List)
          .map((exJson) => RoutineExercise.fromJson(exJson))
          .toList();

      return Routine(
        id: routine.id,
        userId: routine.userId,
        name: routine.name,
        assignedDate: routine.assignedDate,
        createdAt: routine.createdAt,
        exercises: exercises,
        shareCode: routine.shareCode,
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> importSharedRoutine(Routine routine, String targetUserId) async {
    final code = _generateRandomShareCode();
    if (_useMockData || !_isInitialized) {
      _initMockRoutines();
      final newRoutineId =
          'rout-imported-${DateTime.now().millisecondsSinceEpoch}';
      final newRoutine = Routine(
        id: newRoutineId,
        userId: targetUserId,
        name: '${routine.name} (Copiada)',
        createdAt: DateTime.now(),
        shareCode: code,
      );
      _mockRoutines!.add(newRoutine);

      for (var re in routine.exercises) {
        final newReId =
            're-imported-${DateTime.now().millisecondsSinceEpoch}-${_mockRoutineExercises!.length}';
        final newRe = RoutineExercise(
          id: newReId,
          routineId: newRoutineId,
          exerciseId: re.exerciseId,
          sets: re.sets,
          reps: re.reps,
          seriesWeights: List<double>.from(re.seriesWeights),
          seriesType: re.seriesType,
          exerciseName: re.exerciseName,
          exerciseDescription: re.exerciseDescription,
          exerciseImageUrl: re.exerciseImageUrl,
        );
        _mockRoutineExercises!.add(newRe);
      }
      return true;
    }

    try {
      // 1. Insert routine copy
      final response = await client
          .from('rutinas')
          .insert({
            'name': '${routine.name} (Copiada)',
            'user_id': targetUserId,
            'share_code': code,
          })
          .select()
          .single();

      final newRoutineId = response['id'].toString();

      // 2. Clone exercises
      if (routine.exercises.isNotEmpty) {
        final List<Map<String, dynamic>> exercisesToInsert = routine.exercises
            .map((re) {
              return {
                'routine_id': newRoutineId,
                'exercise_id': re.exerciseId,
                'sets': re.sets,
                'reps': re.reps,
                'series_weights': re.seriesWeights,
                'series_type': re.seriesType,
              };
            })
            .toList();

        await client.from('rutina_ejercicios').insert(exercisesToInsert);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<ClientAiChat>> getClientAiChats(String clientId) async {
    if (_useMockData) {
      return _getMockClientAiChats(clientId);
    }
    try {
      final response = await client
          .from('chat_ia_clientes')
          .select()
          .eq('client_id', clientId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => ClientAiChat.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching AI chats: $e');
      return _getMockClientAiChats(clientId);
    }
  }

  List<ClientAiChat> _getMockClientAiChats(String clientId) {
    return [];
  }

  Future<bool> saveClientAiChat(
    String clientId,
    String coachId,
    String question,
    String answer,
  ) async {
    final newChat = ClientAiChat(
      id: _useMockData
          ? 'mock-chat-${DateTime.now().millisecondsSinceEpoch}'
          : '',
      clientId: clientId,
      coachId: coachId,
      question: question,
      answer: answer,
      createdAt: DateTime.now(),
    );

    if (_useMockData) {
      _mockClientAiChats ??= [];
      _mockClientAiChats!.insert(0, newChat);
      return true;
    }

    try {
      await client.from('chat_ia_clientes').insert({
        'client_id': clientId,
        'coach_id': coachId,
        'question': question,
        'answer': answer,
      });
      _mockClientAiChats ??= [];
      _mockClientAiChats!.insert(0, newChat);
      return true;
    } catch (e) {
      print('Error saving AI chat: $e');
      _mockClientAiChats ??= [];
      _mockClientAiChats!.insert(0, newChat);
      return true;
    }
  }

  Future<String> askAiAboutClient(
    UserProfile clientProfile,
    List<MeasurementRecord> records,
    List<MealItem> meals,
    List<WorkoutLog> workouts, {
    String? customQuestion,
  }) async {
    String? apiKey = await ApiKeyScreen.getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      apiKey =
          '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';
    }

    final double currentWeight = clientProfile.currentWeight;
    final double initialWeight = clientProfile.initialWeight;
    final double targetWeight = clientProfile.targetWeight;
    final double height = clientProfile.height;
    final int age = clientProfile.age;

    String measurementsText = 'No hay medidas corporales registradas.';
    if (records.isNotEmpty) {
      final sortedRecords = List<MeasurementRecord>.from(records)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latest = sortedRecords.first;
      measurementsText =
          'Último registro de medidas (${latest.createdAt.toLocal().toString().split(' ')[0]}):\n'
          '- Peso: ${latest.weight} kg\n'
          '- Cuello: ${latest.cuello} cm\n'
          '- Pecho: ${latest.chest} cm\n'
          '- Bíceps: ${latest.arm} cm\n'
          '- Abdomen: ${latest.abdomen} cm\n'
          '- Cintura: ${latest.waist} cm\n'
          '- Pierna: ${latest.leg} cm\n'
          '- Pantorrilla: ${latest.calf} cm';
    }

    String mealsText = 'No hay comidas registradas recientemente.';
    if (meals.isNotEmpty) {
      final recentMeals = meals.take(10).toList();
      mealsText =
          'Comidas recientes del cliente:\n' +
          recentMeals
              .map(
                (m) =>
                    '- ${m.name}: ${m.calories.toStringAsFixed(0)} kcal, ${m.protein.toStringAsFixed(0)}g proteína (Registrado: ${m.consumedAt.toLocal().toString().split(' ')[0]})',
              )
              .join('\n');
    }

    String workoutsText = 'No hay entrenamientos completados recientemente.';
    if (workouts.isNotEmpty) {
      final recentWorkouts = workouts.take(10).toList();
      workoutsText =
          'Entrenamientos recientes completados:\n' +
          recentWorkouts
              .map(
                (w) =>
                    '- ${w.routineName} (Fecha: ${w.completedAt.toLocal().toString().split(' ')[0]})',
              )
              .join('\n');
    }

    final String questionPrompt =
        customQuestion != null && customQuestion.trim().isNotEmpty
        ? 'El entrenador hace la siguiente pregunta específica sobre este cliente:\n"$customQuestion"'
        : 'Por favor, haz un análisis general detallado sobre el progreso del cliente basándote en su información, indicando fortalezas, áreas de oportunidad y recomendaciones.';

    final prompt =
        'Actúa como un entrenador personal experto y nutriólogo deportivo. Analiza los siguientes datos del cliente:\n\n'
        'Cliente: ${clientProfile.name}\n'
        'Edad: $age años\n'
        'Estatura: ${height.toStringAsFixed(0)} cm\n'
        'Peso Inicial: $initialWeight kg\n'
        'Peso Actual: $currentWeight kg\n'
        'Peso Meta: $targetWeight kg\n\n'
        'Historial de Medidas:\n$measurementsText\n\n'
        'Nutrición:\n$mealsText\n\n'
        'Actividad Física/Rutinas:\n$workoutsText\n\n'
        '$questionPrompt\n\n'
        'Proporciona una respuesta clara, profesional, concisa y estructurada en español. Usa viñetas y formato markdown si es necesario.';

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final answer =
            decoded['choices'][0]['message']['content']?.toString() ?? '';
        return answer.trim();
      } else {
        print('OpenAI error: ${response.statusCode} - ${response.body}');
        return 'Error al consultar con la IA (Código ${response.statusCode}). Por favor verifica tu API Key.';
      }
    } catch (e) {
      print('AI Query connection error: $e');
      return 'Error de conexión al consultar con la IA: $e';
    }
  }

  Future<List<Notification>> getNotifications() async {
    try {
      if (_useMockData || !_isInitialized) {
        return _generateMockNotifications();
      }

      final response = await client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      return (response as List)
          .map((item) => Notification.fromJson(item))
          .toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      return _generateMockNotifications();
    }
  }

  List<Notification> _generateMockNotifications() {
    return [
      Notification(
        id: '1',
        title: 'Pago Confirmado',
        description:
            'Tu pago de \$50 ha sido procesado correctamente. Próximo pago el 15 de julio.',
        imageUrl:
            'https://images.unsplash.com/photo-1556742757-b6bab00c5f0d?auto=format&fit=crop&q=80&w=600',
        type: 'payment',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        authorName: 'Personal Trainer',
        isRead: true,
      ),
      Notification(
        id: '2',
        title: 'Nuevo Evento: Clase Grupal',
        description:
            'Únete a nuestra nueva clase de entrenamiento en grupo este sábado a las 10:00 AM. ¡No te lo pierdas!',
        imageUrl:
            'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&q=80&w=600',
        type: 'event',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        actionDate: DateTime.now().add(const Duration(days: 3)),
        authorName: 'Coach Carlos',
      ),
      Notification(
        id: '3',
        title: 'Logro Desbloqueado',
        description:
            'Has completado 30 días consecutivos de entrenamiento. ¡Eres increíble!',
        type: 'achievement',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        authorName: 'Sistema',
      ),
      Notification(
        id: '4',
        title: 'Nueva Receta de la Comunidad',
        description:
            'La comunidad ha compartido una nueva receta de batido proteico. Mírala en la sección de recetas.',
        imageUrl:
            'https://images.unsplash.com/photo-1590080876550-cd91a4a4d549?auto=format&fit=crop&q=80&w=600',
        type: 'community',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        authorName: 'Comunidad',
      ),
      Notification(
        id: '5',
        title: 'Recordatorio de Entrenamiento',
        description:
            'No olvides completar tu rutina de hoy: Rutina HIIT Quema Grasa',
        type: 'reminder',
        createdAt: DateTime.now(),
        authorName: 'Sistema',
      ),
    ];
  }

  // --- COMUNIDAD (COMMUNITY POSTS) ---
  Future<List<CommunityPost>> getCommunityPosts() async {
    if (_useMockData || !_isInitialized) {
      return [];
    }
    try {
      final response = await client
          .from('community_posts')
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => CommunityPost.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<String?> uploadCommunityPostPhoto(dynamic imageFile) async {
    if (_useMockData || !_isInitialized || imageFile == null) {
      return null;
    }
    try {
      final targetId = client.auth.currentUser?.id ?? 'unknown';
      final bytes = imageFile.path.startsWith('http')
          ? await http.readBytes(Uri.parse(imageFile.path))
          : await imageFile.readAsBytes();
      final fileName =
          'community_posts/${targetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage
          .from('general')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      return client.storage.from('general').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  Future<bool> addCommunityPost({
    required String imageUrl,
    required String title,
    required String description,
  }) async {
    if (_useMockData || !_isInitialized) {
      return false;
    }
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;
      await client.from('community_posts').insert({
        'image_url': imageUrl,
        'title': title,
        'description': description,
        'id_user': userId,
        'visualizaciones': 0,
        'likes': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> incrementCommunityPostViews(String postId) async {
    if (_useMockData || !_isInitialized) return;
    try {
      await client.rpc(
        'increment_community_post_views',
        params: {'post_id': postId},
      );
    } catch (e) {
      // Silently ignore view-count failures
    }
  }

  Future<bool> likeCommunityPost(String postId) async {
    if (_useMockData || !_isInitialized) return false;
    try {
      await client.rpc(
        'increment_community_post_likes',
        params: {'post_id': postId},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- PRODUCTOS / TIENDA ---
  Future<List<Product>> getProducts() async {
    if (_useMockData || !_isInitialized) return [];
    try {
      final response = await client.from('products').select().order('created_at', ascending: false);
      return (response as List).map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      print('Error getting products: $e');
      return [];
    }
  }

  Future<bool> addProduct({
    required String name,
    required double price,
    String? description,
    String? category,
    String? imageUrl,
    int stock = 0,
  }) async {
    if (_useMockData || !_isInitialized) return true;
    try {
      await client.from('products').insert({
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'image_url': imageUrl,
        'stock': stock,
      });
      return true;
    } catch (e) {
      print('Error adding product: $e');
      return false;
    }
  }

  Future<bool> updateProduct({
    required String id,
    String? name,
    double? price,
    String? description,
    String? category,
    String? imageUrl,
    int? stock,
  }) async {
    if (_useMockData || !_isInitialized) return true;
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (price != null) updateData['price'] = price;
      if (description != null) updateData['description'] = description;
      if (category != null) updateData['category'] = category;
      if (imageUrl != null) updateData['image_url'] = imageUrl;
      if (stock != null) updateData['stock'] = stock;

      await client.from('products').update(updateData).eq('id', id);
      return true;
    } catch (e) {
      print('Error updating product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    if (_useMockData || !_isInitialized) return true;
    try {
      await client.from('products').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }

  Future<String?> uploadProductPhoto(dynamic imageFile) async {
    if (_useMockData || !_isInitialized || imageFile == null) {
      return 'https://images.unsplash.com/photo-1579722821273-0f110b5eb48c?auto=format&fit=crop&q=80&w=600';
    }
    try {
      final bytes = imageFile.path.startsWith('http')
          ? await http.readBytes(Uri.parse(imageFile.path))
          : await imageFile.readAsBytes();
      final fileName = 'products/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage.from('general').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      return client.storage.from('general').getPublicUrl(fileName);
    } catch (e) {
      print('Error uploading product photo: $e');
      return null;
    }
  }
}
