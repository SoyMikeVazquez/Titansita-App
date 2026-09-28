# Testing - Sistema de Registro de Entrenadores

## Prerequisitos

- Flutter instalado y funcionando
- Proyecto sincronizado con Supabase
- Acceso a Admin Dashboard

## Testing Manual

### 1. Test de Registro de Entrenador

#### Paso a Paso:
1. Ejecuta la app: `flutter run`
2. Navega a Admin Dashboard
3. Selecciona "Dar de Alta Entrenador"
4. Rellena el formulario con:
   ```
   Nombre: Juan García
   Correo: juan.garcia@gym.com
   Contraseña: Password123
   Teléfono: +56 9 1234 5678
   Especialidad: Fitness y musculación
   Bio: Entrenador certificado con 8 años de experiencia
   ```
5. Click en "Dar de Alta Entrenador"

#### Resultado Esperado:
- ✅ Mensaje de éxito: "Entrenador registrado exitosamente ✅"
- ✅ Formulario se limpia
- ✅ Nuevo usuario aparece en Supabase Auth
- ✅ Nuevo registro en tabla `EmpresasEntrenadores`
- ✅ Usuario tiene is_admin = true

#### Verificación en Supabase:
```sql
-- Verificar en SQL Editor
SELECT * FROM "EmpresasEntrenadores" ORDER BY created_at DESC LIMIT 1;
-- Debería mostrar el nuevo entrenador
```

---

### 2. Test de Visualización de Entrenadores

#### Paso a Paso:
1. En Admin Dashboard, selecciona "Entrenadores Registrados"
2. Espera a que cargue la lista

#### Resultado Esperado:
- ✅ Se muestra lista de entrenadores
- ✅ Cada entrenador en una tarjeta con información
- ✅ Se muestra nombre, email, teléfono, especialidad, bio
- ✅ Estado visible (activo/inactivo)
- ✅ Botón de menú con opciones de Editar/Eliminar

---

### 3. Test de Edición de Entrenador

#### Paso a Paso:
1. En lista de entrenadores, click en el menú (⋮) de un entrenador
2. Click en "Editar"
3. Modifica algunos campos:
   ```
   Teléfono: +56 9 9999 8888
   Especialidad: Boxeo profesional
   ```
4. Click en "Guardar"

#### Resultado Esperado:
- ✅ Diálogo se cierra
- ✅ Lista se actualiza automáticamente
- ✅ Nueva información visible en tarjeta
- ✅ `updated_at` se actualiza en BD

#### Verificación:
```sql
SELECT nombre, telefono, especialidad, updated_at 
FROM "EmpresasEntrenadores" 
WHERE nombre = 'Juan García';
-- Debe mostrar los datos actualizados
```

---

### 4. Test de Eliminación de Entrenador

#### Paso a Paso:
1. En lista de entrenadores, click en el menú (⋮) 
2. Click en "Eliminar"
3. Confirma en diálogo: "¿Eliminar entrenador?"

#### Resultado Esperado:
- ✅ Diálogo se cierra
- ✅ Entrenador desaparece de la lista
- ✅ Registro eliminado de `EmpresasEntrenadores`
- ✅ Usuario eliminado de `auth.users` (en cascada)

#### Verificación:
```sql
SELECT COUNT(*) FROM "EmpresasEntrenadores" WHERE nombre = 'Juan García';
-- Debe retornar 0
```

---

### 5. Test de Validaciones

#### Test 5.1: Email obligatorio
1. Intenta crear entrenador sin llenar email
2. Presiona "Dar de Alta Entrenador"

**Resultado:** ✅ Debe mostrar error "Obligatorio"

#### Test 5.2: Email inválido
1. Rellena email: "juangmail.com" (sin @)
2. Presiona "Dar de Alta Entrenador"

**Resultado:** ✅ Debe mostrar error "Correo no válido"

#### Test 5.3: Contraseña muy corta
1. Contraseña: "123"
2. Presiona "Dar de Alta Entrenador"

**Resultado:** ✅ Debe mostrar error "Mínimo 6 caracteres"

#### Test 5.4: Campos opcionales
1. Rellena solo: nombre, email, contraseña
2. Deja vacíos: teléfono, especialidad, bio
3. Presiona "Dar de Alta Entrenador"

**Resultado:** ✅ Debe crear entrenador sin error

---

### 6. Test de Modo Demo

#### Paso a Paso:
1. Desactiva Supabase (o usa modo demo)
2. Intenta crear entrenador
3. Intenta editar
4. Intenta eliminar

#### Resultado Esperado:
- ✅ Formulario muestra banner de modo Demo
- ✅ Operaciones retornan "No disponible en modo Demo"
- ✅ No hay cambios en base de datos real

---

### 7. Test de Rendimiento

#### Test 7.1: Carga de lista con muchos entrenadores
1. Crea 20 entrenadores
2. Abre "Entrenadores Registrados"

**Resultado:** ✅ Lista carga en < 2 segundos

#### Test 7.2: Edición con campos grandes
1. Edita bio con 500 caracteres
2. Presiona guardar

**Resultado:** ✅ Se actualiza sin problemas

---

### 8. Test de Casos Límite

#### Test 8.1: Email duplicado
1. Crea entrenador con email: test@gym.com
2. Intenta crear otro con mismo email

**Resultado:** ✅ Debe mostrar error de email duplicado

#### Test 8.2: Caracteres especiales
1. Nombre: "José María O'Connor"
2. Bio: "Especialidad en ejercicios como sentadilla (profunda) & peso muerto"
3. Crear entrenador

**Resultado:** ✅ Se guarda correctamente con caracteres especiales

#### Test 8.3: Campos vacíos opcionales
1. Crea entrenador sin teléfono, especialidad, bio
2. Visualiza en lista

**Resultado:** ✅ Se muestra sin esos campos, sin errores

---

## Checklist de Testing

- [ ] Registro básico funciona
- [ ] Nuevos datos en `EmpresasEntrenadores`
- [ ] Nuevos usuarios en `auth.users`
- [ ] Permisos is_admin asignados
- [ ] Lista de entrenadores muestra datos
- [ ] Edición actualiza campos
- [ ] Eliminación borra de BD
- [ ] Validaciones funcionan
- [ ] Modo demo deshabilitado
- [ ] Caracteres especiales soportados
- [ ] Email único validado
- [ ] Campos opcionales trabajen
- [ ] Interfaz responsive
- [ ] Errores manejados correctamente
- [ ] Mensajes de éxito/error claros

## Debugging

### Si los datos no aparecen en BD:
```bash
# Verifica conexión a Supabase
flutter run -vvv

# Revisa logs en Supabase Console
# Dashboard → Logs → Query Performance
```

### Si hay errores de RLS:
```sql
-- Verifica políticas
SELECT * FROM pg_policies WHERE tablename = 'EmpresasEntrenadores';

-- Verifica rol del usuario
SELECT auth.uid();
```

### Si formulario no responde:
```bash
# Limpia caché
flutter clean
flutter pub get
flutter run
```

---

## Casos de Prueba Automatizados (Futuro)

Se podría agregar tests con:
- `flutter_test` para unit tests
- `integration_test` para pruebas end-to-end
- Mocks de Supabase para testing offline

Ejemplo de unit test:
```dart
test('Trainer.fromJson parses correctly', () {
  final json = {
    'id': 'test-id',
    'userID': 'user-123',
    'nombre': 'Test Trainer',
    'correo_electronico': 'test@example.com',
    'telefono': '+56 9 1234 5678',
    'especialidad': 'Fitness',
    'bio': 'Test bio',
    'estado': 'activo',
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };
  
  final trainer = Trainer.fromJson(json);
  expect(trainer.nombre, 'Test Trainer');
  expect(trainer.estado, 'activo');
});
```

---

## Información de Contacto para Soporte

Si encuentras problemas:
1. Revisa `TRAINER_REGISTRATION_GUIDE.md`
2. Verifica logs en `flutter run -vvv`
3. Consulta Supabase Docs: https://supabase.com/docs
4. Revisa código comentado en los archivos

---

**Última actualización:** 2026-07-07
**Versión:** 1.0
