import 'dart:ui';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/news_item.dart';
import '../models/user_profile.dart';
import '../models/notification.dart' as notif_model;
import '../models/routine.dart';
import '../models/product.dart';
import '../widgets/notifications_carousel.dart';
import '../widgets/news_carousel.dart';
import '../widgets/daily_routine_card.dart';
import '../widgets/progress_card.dart';
import '../models/established_exercise.dart';
import '../widgets/exercises_list.dart';
import '../models/assigned_recipe.dart';
import '../models/meal_item.dart';
import '../models/community_post.dart';
import '../widgets/assigned_recipes_list.dart';
import '../widgets/community_posts_list.dart';
import '../utils/cors_helper.dart';
import 'workout_tab.dart';
import 'payment_method_screen.dart';
import 'admin_recipes_screen.dart';
import 'client_recipes_calendar_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  ImageProvider _resolveImageProvider(String? url, {String fallbackUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200'}) {
    if (url == null || url.isEmpty) {
      return NetworkImage(fallbackUrl);
    }
    if (url.startsWith('http')) {
      return NetworkImage(url);
    }
    if (!kIsWeb) {
      if (url.startsWith('file://')) {
        return FileImage(File(Uri.parse(url).toFilePath()));
      }
      if (url.startsWith('/')) {
        return FileImage(File(url));
      }
    }
    return NetworkImage(_supabaseService.client.storage.from('general').getPublicUrl(url));
  }

  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;
  late DateTime _selectedDate;

  List<NewsItem> _news = [];
  List<notif_model.Notification> _notifications = [];
  List<Routine> _routines = [];
  UserProfile? _userProfile;
  List<EstablishedExercise> _exercises = [];
  List<AssignedRecipe> _assignedRecipes = [];
  List<MealItem> _meals = [];
  List<CommunityPost> _communityPosts = [];
  List<Product> _products = [];

  // Inline Meal Upload Form State
  XFile? _inlineMealPhoto;
  Uint8List? _inlineMealPhotoBytes;
  final TextEditingController _inlineMealTitleController =
      TextEditingController();
  bool _isSavingInlineMeal = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Initialize Supabase if needed
      await _supabaseService.initialize();

      // Retrieve all data in parallel
      final results = await Future.wait([
        _supabaseService.getNews(),
        _supabaseService.getNotifications(),
        _supabaseService.getUserProfile(),
        _supabaseService.getEstablishedExercises(),
        _supabaseService.getAssignedRecipes(date: DateTime.now()),
        _supabaseService.getRoutines(),
        _supabaseService.getRecentMeals(),
        _supabaseService.getCommunityPosts(),
        _supabaseService.getProducts(),
      ]);

      if (mounted) {
        setState(() {
          _news = results[0] as List<NewsItem>;
          _notifications = results[1] as List<notif_model.Notification>;
          _userProfile = results[2] as UserProfile;
          _exercises = results[3] as List<EstablishedExercise>;
          _assignedRecipes = results[4] as List<AssignedRecipe>;
          _routines = results[5] as List<Routine>;
          _meals = results[6] as List<MealItem>;
          _communityPosts = results[7] as List<CommunityPost>;
          _products = results[8] as List<Product>;
          _isLoading = false;
        });
        _checkPendingShareCode();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando datos: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickInlineMealPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _inlineMealPhoto = image;
          _inlineMealPhotoBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveInlineMeal() async {
    final title = _inlineMealTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un título para tu comida'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_inlineMealPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una foto de tu comida'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSavingInlineMeal = true;
    });

    try {
      final String? photoUrl = await _supabaseService.uploadMealPhoto(
        _inlineMealPhoto,
      );
      final success = await _supabaseService.addMeal(
        title,
        0, // calories
        0.0, // protein
        0.0, // carbs
        0.0, // fat
        imageUrl: photoUrl,
      );

      if (mounted) {
        setState(() {
          _isSavingInlineMeal = false;
        });

        if (success) {
          _inlineMealTitleController.clear();
          setState(() {
            _inlineMealPhoto = null;
            _inlineMealPhotoBytes = null;
          });
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Comida registrada correctamente ✅',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.black,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar comida'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingInlineMeal = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAddMealSheet({
    String? initialTitle,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? defaultImageUrl,
  }) {
    final formKey = GlobalKey<FormState>();
    String mealName = initialTitle ?? '';
    XFile? mealPhoto;
    Uint8List? mealPhotoBytes;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickMealPhoto() async {
              try {
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 85,
                );
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  setModalState(() {
                    mealPhoto = image;
                    mealPhotoBytes = bytes;
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al seleccionar imagen: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subir Comida',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF171717),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFF737373),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sube una foto de tu comida y ponle un título',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Photo Picker
                      GestureDetector(
                        onTap: pickMealPhoto,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: mealPhotoBytes != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      mealPhotoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : defaultImageUrl != null &&
                                    defaultImageUrl.isNotEmpty
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      defaultImageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_a_photo_outlined,
                                      color: Color(0xFFA3A3A3),
                                      size: 36,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Toca para agregar foto 📸',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF737373),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Meal Title Input
                      TextFormField(
                        initialValue: initialTitle,
                        style: const TextStyle(color: Colors.black),
                        decoration: _buildInputDecoration(
                          'Título de la comida (ej. Pollo con arroz)',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Por favor ingresa un título'
                            : null,
                        onSaved: (val) => mealName = val ?? '',
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (mealPhoto == null &&
                                    (defaultImageUrl == null ||
                                        defaultImageUrl.isEmpty)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Por favor selecciona una foto de tu comida',
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }
                                if (formKey.currentState?.validate() ?? false) {
                                  formKey.currentState?.save();
                                  setModalState(() => isSaving = true);

                                  // Upload photo
                                  final String? photoUrl = mealPhoto != null
                                      ? await _supabaseService.uploadMealPhoto(
                                          mealPhoto,
                                        )
                                      : defaultImageUrl;

                                  final success = await _supabaseService
                                      .addMeal(
                                        mealName,
                                        calories ?? 0,
                                        protein ?? 0.0,
                                        carbs ?? 0.0,
                                        fat ?? 0.0,
                                        imageUrl: photoUrl,
                                      );

                                  if (!context.mounted) return;
                                  setModalState(() => isSaving = false);

                                  if (success) {
                                    Navigator.pop(context);
                                    _loadData();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Comida registrada correctamente ✅',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        backgroundColor: Colors.black,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Error al guardar comida',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Subir Comida',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCommunityPostSheet() {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String description = '';
    XFile? photo;
    Uint8List? photoBytes;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickPhoto() async {
              try {
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1000,
                  maxHeight: 1000,
                  imageQuality: 85,
                );
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  setModalState(() {
                    photo = image;
                    photoBytes = bytes;
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al seleccionar imagen: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            }

            Future<void> submitPost() async {
              if (!formKey.currentState!.validate()) return;

              if (photo == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor selecciona una foto para subir'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              formKey.currentState!.save();
              setModalState(() => isSaving = true);

              final imageUrl = await _supabaseService.uploadCommunityPostPhoto(
                photo,
              );

              if (imageUrl == null) {
                if (!context.mounted) return;
                setModalState(() => isSaving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al subir la imagen'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              final success = await _supabaseService.addCommunityPost(
                imageUrl: imageUrl,
                title: title,
                description: description,
              );

              if (!context.mounted) return;

              setModalState(() => isSaving = false);

              if (success) {
                _loadData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '¡Gracias por compartir con la comunidad!',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.black,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al publicar'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Compartir con la Comunidad',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFF737373),
                            ),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: pickPhoto,
                        child: Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: photoBytes != null
                              ? Image.memory(photoBytes!, fit: BoxFit.cover)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_a_photo_outlined,
                                      color: Color(0xFF737373),
                                      size: 28,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Agregar foto',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF737373),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        decoration: _buildInputDecoration('Título'),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Ingresa un título'
                            : null,
                        onSaved: (val) => title = val ?? '',
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        maxLines: 3,
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        decoration: _buildInputDecoration('Descripción'),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Ingresa una descripción'
                            : null,
                        onSaved: (val) => description = val ?? '',
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: isSaving ? null : submitPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Publicar',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF737373), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildMealsView() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Colors.black,
          backgroundColor: Colors.white,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 24.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nutrición y Comidas',
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registra tus comidas',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Inline Upload Form Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sube tu comida',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Photo Picker Box
                        GestureDetector(
                          onTap: _pickInlineMealPhoto,
                          child: Container(
                            height: 140,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E5E5),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _inlineMealPhotoBytes != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(
                                        _inlineMealPhotoBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.add_a_photo_outlined,
                                        color: Color(0xFFA3A3A3),
                                        size: 28,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Agregar foto de comida',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF737373),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title Input
                        TextField(
                          controller: _inlineMealTitleController,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Título de la comida (ej. Pollo con arroz)',
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFFA3A3A3),
                              fontSize: 13,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E5E5),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E5E5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Submit Button
                        ElevatedButton(
                          onPressed: _isSavingInlineMeal
                              ? null
                              : _saveInlineMeal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSavingInlineMeal
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Subir Comida',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3 Últimos Registros
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Últimos Registros de Hoy',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF171717),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_meals.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'No has registrado comidas aún',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF737373),
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ..._meals.take(3).map((meal) {
                          final timeStr = DateFormat(
                            'dd MMM, hh:mm a',
                          ).format(meal.consumedAt);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10.0),
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: const Color(0xFFE5E5E5),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    color: const Color(0xFFF5F5F5),
                                    child:
                                        (meal.imageUrl != null &&
                                            meal.imageUrl!.isNotEmpty)
                                        ? Image.network(
                                            getCorsFriendlyUrl(meal.imageUrl!),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.restaurant,
                                                      color: Color(0xFF737373),
                                                      size: 20,
                                                    ),
                                          )
                                        : const Icon(
                                            Icons.restaurant,
                                            color: Color(0xFF737373),
                                            size: 20,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        meal.name,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF171717),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeStr,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF737373),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Calendario de Recetas Card
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ClientRecipesCalendarScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.calendar_month_outlined,
                              color: Color(0xFF3B82F6),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Calendario de Recetas',
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Visualiza tus recetas por día',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF737373),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Color(0xFFA3A3A3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Recetario Saludable Card
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminRecipesScreen(),
                        ),
                      );
                      _loadData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined,
                              color: Color(0xFF22C55E),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recetario Saludable',
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Explora ideas y registra tus comidas al instante',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF737373),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Color(0xFFA3A3A3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    if (_userProfile == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Header
              Text(
                'Mi Perfil',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Avatar & Name Card
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFFF5F5F5),
                      backgroundImage: _resolveImageProvider(_userProfile?.avatarUrl),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _userProfile!.name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userProfile!.email,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildPaymentCutoffBanner(horizontalMargin: 0),
              const SizedBox(height: 24),

              // Physical stats
              Text(
                'Datos Físicos',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildProfileStat('Edad', '${_userProfile!.age} años'),
                    _buildProfileStat(
                      'Estatura',
                      '${_userProfile!.height.toStringAsFixed(0)} cm',
                    ),
                    _buildProfileStat(
                      'Peso Actual',
                      '${_userProfile!.currentWeight.toStringAsFixed(1)} kg',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Settings Options
              Text(
                'Configuración',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              _buildProfileOption(
                icon: Icons.edit_outlined,
                title: 'Editar Perfil',
                subtitle: 'Modifica tus datos y foto de perfil',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                  if (result == true) {
                    _loadData();
                  }
                },
              ),
              const SizedBox(height: 12),

              /*
              _buildProfileOption(
                icon: Icons.notifications_none,
                title: 'Notificaciones',
                subtitle: 'Configura tus recordatorios diarios',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              */


              const SizedBox(height: 12),

              _buildProfileOption(
                icon: Icons.logout,
                title: 'Cerrar Sesión',
                subtitle: 'Salir de tu cuenta de forma segura',
                isDestructive: true,
                onTap: _showLogoutDialog,
              ),

              const SizedBox(height: 32),

              // Questionnaire Answers
              if (_userProfile!.questionnaireAnswers.isNotEmpty) ...[
                Text(
                  'Respuestas de Registro',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _userProfile!.questionnaireAnswers.length,
                  itemBuilder: (context, idx) {
                    final item = _userProfile!.questionnaireAnswers[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['question_text'] ?? 'Pregunta',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF737373),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['answer'] ?? 'Sin respuesta',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: const Color(0xFFA3A3A3),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex == 1) {
      return Scaffold(
        extendBody: true,
        body: const WorkoutTab(),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    if (_currentIndex == 2) {
      return Scaffold(
        extendBody: true,
        body: _buildMealsView(),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    if (_currentIndex == 3) {
      return Scaffold(
        extendBody: true,
        body: _buildProfileView(),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: const Color(0xFFFAFAFA),
      bottomNavigationBar: _buildBottomNavBar(),

      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Colors.black,
          backgroundColor: Colors.white,
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 2. Beautiful Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 12.0,
                    right: 20.0,
                    top: 20.0,
                    bottom: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE5E5E5),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFF5F5F5),
                              backgroundImage: _resolveImageProvider(_userProfile?.avatarUrl),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '¡Hola, ${_userProfile?.name.split(" ").first ?? "Mateo"}!',
                                    style: const TextStyle(
                                      color: Color(0xFF171717),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFE5E5E5),
                                      ),
                                    ),
                                    child: Text(
                                      (_userProfile?.isAdmin ?? false)
                                          ? 'ADMIN'
                                          : 'CLIENTE',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E5E5),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.notifications_none,
                                color: Colors.black,
                              ),
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.black,
                              ),
                              onPressed: _showLogoutDialog,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF737373)),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),

                    // 3. News Carousel (Filtered by IDEmpresa)
                    NewsCarousel(news: _news),
                    const SizedBox(height: 24),
                    
                    _buildProductsSection(),
                    const SizedBox(height: 24),

                    // 6. Progress Card
                    if (_userProfile != null) ...[
                      ProgressCard(profile: _userProfile!),
                      const SizedBox(height: 24),
                    ],

                    // 4. Daily Routine Card
                    DailyRoutineCard(
                      routines: _routines,
                      selectedDate: _selectedDate,
                    ),
                    const SizedBox(height: 24),

                    // 7. Assigned Recipes for the Day
                    AssignedRecipesList(
                      assignedRecipes: _assignedRecipes,
                      onRefresh: _loadData,
                      onLogRecipe: (recipe) {
                        _showAddMealSheet(
                          initialTitle: recipe.title,
                          calories: recipe.calories,
                          protein: recipe.protein,
                          carbs: recipe.carbs,
                          fat: recipe.fat,
                          defaultImageUrl: recipe.imageUrl,
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 8. Community Posts (User-submitted photos)
                    CommunityPostsList(
                      posts: _communityPosts,
                      onAddTap: _showAddCommunityPostSheet,
                      onPostTap: (post) {
                        _supabaseService.incrementCommunityPostViews(post.id);
                      },
                    ),
                    const SizedBox(height: 32),
                    _buildBrandFooter(),
                    const SizedBox(height: 100),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
        height: 64,
        decoration: BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: const Color(0x14000000),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xC0FFFFFF),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0x66FFFFFF), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home),
                  _buildNavItem(
                    1,
                    Icons.fitness_center_outlined,
                    Icons.fitness_center,
                  ),
                  _buildNavItem(
                    2,
                    Icons.restaurant_menu_outlined,
                    Icons.restaurant_menu,
                  ),
                  _buildNavItem(3, Icons.person_outline, Icons.person),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData unselectedIcon,
    IconData selectedIcon,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE5E5E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: isSelected ? Colors.black : const Color(0xFF737373),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFEF4444) : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFFFCA5A5)
                : const Color(0xFFE5E5E5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF737373),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFFD4D4D4),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(
            color: Color(0xFF171717),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          '¿Estás seguro de que deseas salir de tu cuenta?',
          style: TextStyle(color: Color(0xFF525252)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF737373)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _supabaseService.signOut();
            },
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandFooter() {
    return Column(
      children: [
        Center(
          child: Image.asset(
            'assets/logo_transparent.png',
            height: 80,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _showPrivacyPolicyDialog,
              child: Text(
                'Políticas de Privacidad',
                style: GoogleFonts.inter(
                  color: const Color(0xFF737373),
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: _showContactSupportDialog,
              child: Text(
                'Contacto y Soporte',
                style: GoogleFonts.inter(
                  color: const Color(0xFF737373),
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          'Políticas de Privacidad',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(
                'En PersonalTrainer.mx, nos tomamos muy en serio la seguridad y privacidad de tus datos personales.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF333333),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '• Datos recopilados: Información de perfil (nombre, edad, peso, medidas corporales) y datos de entrenamiento/nutrición con el único fin de personalizar tu plan físico.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF333333),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Seguridad: Utilizamos bases de datos en la nube seguras (Supabase) con cifrado SSL para asegurar que tu información nunca sea compartida con terceros sin tu consentimiento.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF333333),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Derechos: Puedes solicitar la eliminación de tu cuenta y todos tus datos guardados directamente desde la configuración de perfil o contactando a soporte.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF333333),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          'Contacto y Soporte',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: ListBody(
          children: [
            Text(
              '¿Tienes dudas con tu plan o necesitas ayuda técnica con la aplicación?',
              style: GoogleFonts.inter(
                color: const Color(0xFF333333),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.email_outlined, color: Colors.black, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'soporte@personaltrainer.mx',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.black,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'WhatsApp: +52 1 234 567 890',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Horario de atención: Lunes a Viernes, 9:00 AM a 6:00 PM',
              style: GoogleFonts.inter(
                color: const Color(0xFF737373),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCutoffBanner({double horizontalMargin = 20.0}) {
    if (_userProfile == null ||
        _userProfile!.isAdmin ||
        _userProfile!.nextPaymentDate == null) {
      return const SizedBox.shrink();
    }

    final nextPayment = _userProfile!.nextPaymentDate!;
    final now = DateTime.now();

    // Clear time parts to calculate exact day differences
    final nextPaymentDateOnly = DateTime(
      nextPayment.year,
      nextPayment.month,
      nextPayment.day,
    );
    final nowDateOnly = DateTime(now.year, now.month, now.day);
    final difference = nextPaymentDateOnly.difference(nowDateOnly).inDays;

    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final formattedDate =
        "${nextPayment.day} de ${months[nextPayment.month - 1]}, ${nextPayment.year}";

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    Color iconColor;
    IconData icon;
    String statusText;

    if (difference < 0) {
      // Overdue
      backgroundColor = const Color(0xFFFEE2E2); // Light red
      borderColor = const Color(0xFFFCA5A5);
      textColor = const Color(0xFF991B1B);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.warning_amber_rounded;
      statusText =
          'Tu pago está vencido hace ${difference.abs()} ${difference.abs() == 1 ? 'día' : 'días'}.';
    } else if (difference <= 3) {
      // Urgent (3 days or less)
      backgroundColor = const Color(0xFFFEF3C7); // Light amber
      borderColor = const Color(0xFFFCD34D);
      textColor = const Color(0xFF92400E);
      iconColor = const Color(0xFFD97706);
      icon = Icons.priority_high_rounded;
      statusText = difference == 0
          ? '¡Hoy es tu fecha límite de pago!'
          : 'Faltan $difference ${difference == 1 ? 'día' : 'días'} para tu fecha de corte.';
    } else {
      // Normal / Safe
      backgroundColor = const Color(0xFFEEF2FF); // Light indigo
      borderColor = const Color(0xFFC7D2FE);
      textColor = const Color(0xFF3730A3);
      iconColor = const Color(0xFF4F46E5);
      icon = Icons.calendar_month_rounded;
      statusText = 'Faltan $difference días para tu fecha de corte.';
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          // Text Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRÓXIMA FECHA DE CORTE DE PAGO DE SERVICIOS',
                  style: GoogleFonts.inter(
                    color: textColor.withOpacity(0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formattedDate,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    color: textColor.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _checkPendingShareCode() async {
    final code = SupabaseService.pendingShareCode;
    if (code == null || code.isEmpty) return;
    
    SupabaseService.pendingShareCode = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    final routine = await _supabaseService.getRoutineByShareCode(code);
    
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      if (routine != null) {
        _showRoutinePreviewBottomSheet(routine);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró la rutina con ese código o enlace.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showRoutinePreviewBottomSheet(Routine routine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final isImporting = ValueNotifier<bool>(false);
            return ValueListenableBuilder<bool>(
              valueListenable: isImporting,
              builder: (context, importing, child) {

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E5E5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.share_outlined, color: Colors.black, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rutina Compartida ⚡',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF737373),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  routine.name,
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFFF5F5F5), height: 1),
                    Expanded(
                      child: routine.exercises.isEmpty
                          ? Center(
                              child: Text(
                                'Esta rutina no tiene ejercicios.',
                                style: GoogleFonts.inter(color: const Color(0xFF737373)),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(20),
                              itemCount: routine.exercises.length,
                              itemBuilder: (context, index) {
                                final ex = routine.exercises[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE5E5E5)),
                                  ),
                                  child: Row(
                                    children: [
                                      if (ex.exerciseImageUrl != null && ex.exerciseImageUrl!.isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            ex.exerciseImageUrl!,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.fitness_center, color: Color(0xFF9CA3AF)),
                                        ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ex.exerciseName,
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.black,
                                              ),
                                            ),
                                            if (ex.exerciseDescription.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                ex.exerciseDescription,
                                                style: GoogleFonts.inter(
                                                  color: const Color(0xFF737373),
                                                  fontSize: 11,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF3F4F6),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    '${ex.sets}x${ex.reps}',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.black,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Tipo: ${ex.seriesType}',
                                                  style: GoogleFonts.inter(
                                                    color: const Color(0xFF737373),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ElevatedButton(
                        onPressed: importing
                            ? null
                            : () async {
                                isImporting.value = true;
                                final targetId = _userProfile?.userID ?? 'mock-user-123';
                                final success = await _supabaseService.importSharedRoutine(routine, targetId);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? '¡Rutina importada a tus rutinas con éxito! 🎉'
                                            : 'Error al importar rutina.',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: success ? Colors.black : Colors.redAccent,
                                    ),
                                  );
                                  // Refresh routines
                                  _loadData();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: importing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Guardar Rutina',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
}
  Widget _buildProductsSection() {
    if (_products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.storefront_outlined, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tienda',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF171717),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 16, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          image: product.imageUrl != null
                              ? DecorationImage(
                                  image: _resolveImageProvider(product.imageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: product.imageUrl == null
                            ? const Center(child: Icon(Icons.shopping_bag, color: Colors.grey))
                            : null,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF171717),
                              ),
                            ),
                            Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

