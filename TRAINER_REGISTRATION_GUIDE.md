# Guía de Registro de Entrenadores - Sistema Completo

## Descripción General

Se ha implementado un sistema completo para dar de alta y gestionar entrenadores en la aplicación Workout. El sistema incluye:

1. **Formulario expandido** de registro con campos adicionales
2. **Tabla `EmpresasEntrenadores`** en Supabase
3. **Métodos de servicio** para CRUD completo
4. **Pantalla de gestión** para visualizar y editar entrenadores

## Flujo de Uso

### Para Admins - Dar de Alta un Entrenador

```
Menú Admin → "Dar de Alta Entrenador"
    ↓
Rellenar Formulario:
  • Nombre completo
  • Correo electrónico
  • Contraseña temporal
  • Teléfono (opcional)
  • Especialidad (opcional)
  • Biografía (opcional)
    ↓
Presionar "Dar de Alta Entrenador"
    ↓
Sistema crea:
  • Usuario en Supabase Auth
  • Registro en EmpresasEntrenadores
  • Permisos de admin
    ↓
Confirmación de éxito
```

### Para Admins - Gestionar Entrenadores

```
Menú Admin → "Entrenadores Registrados"
    ↓
Ver lista de todos los entrenadores
    ↓
Por cada entrenador:
  • Editar datos (teléfono, especialidad, bio)
  • Eliminar del sistema
  • Ver estado (activo/inactivo)
```

## Archivos Modificados y Creados

### Creados

#### 1. `lib/models/trainer.dart`
Modelo para representar un entrenador:
```dart
class Trainer {
  final String id;
  final String userId;
  final String nombre;
  final String correoElectronico;
  final String? telefono;
  final String? especialidad;
  final String? bio;
  final String estado;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### 2. `lib/screens/trainers_list_screen.dart`
Pantalla para visualizar y gestionar entrenadores con:
- Lista de entrenadores con tarjetas informativas
- Edición inline
- Eliminación con confirmación
- Estados visuales (activo/inactivo)

### Modificados

#### 1. `lib/screens/register_trainer_screen.dart`
**Cambios:**
- Agregados campos para: teléfono, especialidad, bio
- Parámetro `maxLines` al builder de campos de texto
- Actualización del método `_registerTrainer()` para pasar nuevos parámetros

#### 2. `lib/services/supabase_service.dart`
**Cambios:**
- Importación del modelo `Trainer`
- Expansión de `registerTrainer()` para incluir phone, specialty, bio
- Creación automática de registro en `EmpresasEntrenadores`
- Nuevos métodos públicos:
  - `getTrainers()` - Obtener lista de entrenadores
  - `updateTrainer()` - Actualizar datos de entrenador
  - `deleteTrainer()` - Eliminar entrenador
  - `_getMockTrainers()` - Datos de prueba

**Tabla SQL agregada:**
```sql
CREATE TABLE IF NOT EXISTS public.EmpresasEntrenadores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "userID" UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    correo_electronico TEXT NOT NULL,
    telefono TEXT,
    especialidad TEXT,
    bio TEXT,
    estado TEXT DEFAULT 'activo' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
```

## Integración en la Aplicación

### Paso 1: Ejecutar setup en Supabase

Si es la primera vez, ejecuta el script SQL en Supabase:

1. Accede a Supabase Dashboard
2. Ve a SQL Editor
3. Copia el contenido del método `sqlSetupScript` de SupabaseService
4. Ejecuta el script completo
5. Verifica que se creó la tabla `EmpresasEntrenadores`

### Paso 2: Agregar navegación (Opcional)

Si deseas agregar un botón en el admin dashboard para ver la lista de entrenadores:

```dart
// En admin_dashboard_screen.dart o donde gestiones el menú
ListTile(
  title: const Text('Entrenadores Registrados'),
  leading: const Icon(Icons.people),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrainersListScreen(),
      ),
    );
  },
),
```

### Paso 3: Importar en main.dart si es necesario

```dart
import 'screens/trainers_list_screen.dart';
```

## Estructura de Datos en EmpresasEntrenadores

| Campo | Tipo | Restricciones | Descripción |
|-------|------|----------------|-------------|
| `id` | UUID | PK, Default: gen_random_uuid() | ID único |
| `userID` | UUID | FK→auth.users, NOT NULL, UNIQUE | Usuario autenticado |
| `nombre` | TEXT | NOT NULL | Nombre del entrenador |
| `correo_electronico` | TEXT | NOT NULL | Email del entrenador |
| `telefono` | TEXT | Nullable | Número de contacto |
| `especialidad` | TEXT | Nullable | Área de especialización |
| `bio` | TEXT | Nullable | Biografía profesional |
| `estado` | TEXT | Default: 'activo' | Estado actual |
| `created_at` | TIMESTAMP | Default: NOW() | Fecha de creación |
| `updated_at` | TIMESTAMP | Default: NOW() | Fecha de actualización |

## Métodos del Servicio

### `registerTrainer()`
```dart
Future<bool> registerTrainer({
  required String email,
  required String password,
  required String name,
  String? phone,
  String? specialty,
  String? bio,
}) async
```
- Crea usuario en Supabase Auth con is_admin = true
- Inserta registro en EmpresasEntrenadores
- Retorna true si éxito, false o lanza excepción si error

### `getTrainers()`
```dart
Future<List<Trainer>> getTrainers() async
```
- Obtiene lista de todos los entrenadores
- Retorna lista vacía si hay error
- Soporta modo demo con datos mock

### `updateTrainer()`
```dart
Future<bool> updateTrainer({
  required String trainerId,
  String? nombre,
  String? telefono,
  String? especialidad,
  String? bio,
  String? estado,
}) async
```
- Actualiza solo los campos especificados
- Automáticamente actualiza `updated_at`
- Retorna true si éxito

### `deleteTrainer()`
```dart
Future<bool> deleteTrainer(String trainerId) async
```
- Elimina entrenador de la tabla
- En cascada elimina el usuario si existe
- Retorna true si éxito

## Validaciones

### Lado Cliente
- **Nombre:** Obligatorio
- **Email:** Obligatorio, validación de formato
- **Contraseña:** Obligatorio, mínimo 6 caracteres
- **Teléfono, Especialidad, Bio:** Opcionales

### Lado Servidor
- **Email único:** Constraint en tabla auth.users
- **UserID único:** Constraint en EmpresasEntrenadores
- **RLS:** Solo admins pueden crear/editar/eliminar

## Seguridad

- **Row Level Security (RLS):** Habilitado en la tabla
- **Integridad referencial:** Foreign key a auth.users con ON DELETE CASCADE
- **Email único:** No puede haber duplicados
- **Admin requerido:** Solo usuarios con is_admin=true pueden gestionar

## Modo Demo/Mock

En modo demo:
- El formulario se muestra pero deshabilitado
- Se devuelven datos mock en `_getMockTrainers()`
- Las operaciones retornan true pero no persisten
- Perfecto para pruebas sin conexión a base de datos real

## Próximas Mejoras

1. **Foto de perfil** - Subida y almacenamiento de imágenes
2. **Certificaciones** - Credenciales y validaciones profesionales
3. **Horarios** - Disponibilidad de los entrenadores
4. **Clientes asignados** - Relación con usuarios
5. **Búsqueda y filtros** - En la lista de entrenadores
6. **Historial de cambios** - Auditoría de modificaciones
7. **Confirmación de email** - Verificación de cuenta

## Troubleshooting

### "Error al dar de alta el entrenador"
- Verifica que el servicio Supabase esté inicializado
- Comprueba que la tabla `EmpresasEntrenadores` existe
- Revisa permisos en Supabase RLS

### Email duplicado
- Asegúrate que el email no está registrado
- Revisa la tabla `EmpresasEntrenadores` en Supabase

### Modo Demo deshabilitado
- El registro está deshabilitado en modo demo
- Usa una conexión real a Supabase para probar

## Testing

Para probar localmente:
```bash
flutter run
# Navega a Admin Dashboard
# Click en "Dar de Alta Entrenador"
# Rellena formulario con datos válidos
# Debería crear el entrenador y mostrar confirmación
```

## Documentación Adicional

- Supabase Docs: https://supabase.com/docs
- Flutter Docs: https://flutter.dev/docs
- Tabla de modelos relacionados: Ver otros archivos en `lib/models/`
