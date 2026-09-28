import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import '../models/routine.dart';
import '../models/routine_exercise.dart';
import '../models/exercise.dart';
import '../models/meal_item.dart';
import '../models/workout_log.dart';
import 'records_screen.dart';
import 'admin_exercises_screen.dart';
import 'meal_history_screen.dart';
import 'client_daily_management_screen.dart';
import 'client_finances_screen.dart';
import 'admin_recipes_screen.dart';
import 'admin_settings_screen.dart';
import 'profile_screen.dart';
import 'trainers_management_screen.dart';
import 'manage_client_screen.dart';
import 'news_screen.dart';
import 'admin_finances_screen.dart';
import 'super_admin_finances_screen.dart';
import 'register_client_dialog.dart';
import 'admin_products_screen.dart';
import '../models/news_item.dart';
import '../widgets/news_carousel.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  String? _error;

  UserProfile? _coachProfile;
  List<UserProfile> _clients = [];
  List<NewsItem> _news = [];
  double _overallCompliance = 0.0;
  int _completedObjectivesCount = 0;
  final Map<String, double> _clientProgressMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final coach = await _supabaseService.getUserProfile();
      final clientsList = await _supabaseService.getAllClients();
      final newsList = await _supabaseService.getNews();
      
      // Fetch dynamic stats from table query calculations
      final compliance = await _supabaseService.getTrainerProgress();
      final objectivesCount = await _supabaseService.getTrainerCompletedObjectivesCount();

      // Fetch individual objectives progress per client
      final Map<String, double> tempProgressMap = {};
      await Future.wait(
        clientsList.map((client) async {
          final progress = await _supabaseService.getClientObjectivesProgress(client.userID);
          tempProgressMap[client.userID] = progress;
        }),
      );

      if (mounted) {
        setState(() {
          _coachProfile = coach;
          _clients = clientsList;
          _news = newsList;
          _overallCompliance = compliance;
          _completedObjectivesCount = objectivesCount;
          _clientProgressMap.clear();
          _clientProgressMap.addAll(tempProgressMap);
          _isLoading = false;
        });
        _checkPendingShareCode();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar datos: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showLogoutConfirmDialog() {
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
          '¿Estás seguro de que deseas salir del panel de control?',
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

  void _showManageClientBottomSheet(UserProfile client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageClientScreen(client: client),
      ),
    ).then((_) {
      // Reload dashboard in case client weights or metrics updated
      _loadData();
    });
  }

  Future<void> _showRegisterClientBottomSheet() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterClientDialog(),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  double _calculateOverallCompliance() {
    return _overallCompliance;
  }

  int _calculateTotalExercises() {
    return _completedObjectivesCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
        backgroundColor: Colors.black.withOpacity(0.70),
        elevation: 0,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Image.asset(
                  'assets/logo_transparent.png',
                  height: 60,
                ),
              ),
              const Divider(color: Colors.white24, indent: 20, endIndent: 20),
              const SizedBox(height: 12),
              if (!kIsWeb && Platform.isAndroid)
                ListTile(
                  leading: const Icon(Icons.monetization_on_outlined, color: Colors.white70),
                  title: Text(
                    'Finanzas',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminFinancesScreen(),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.white70),
                title: Text(
                  'Programas y Rutinas',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminExercisesScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.restaurant_menu, color: Colors.white70),
                title: Text(
                  'Recetas',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminRecipesScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.campaign_outlined, color: Colors.white70),
                title: Text(
                  'Novedades',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined, color: Colors.white70),
                title: Text(
                  'Tienda / Productos',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminProductsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.white70),
                title: Text(
                  'Mi Perfil',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadData();
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_add_alt_1_outlined,
                  color: Colors.white70,
                ),
                title: Text(
                  'Dar de Alta Clientes',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showRegisterClientBottomSheet();
                },
              ),
              if (_coachProfile?.isSuperAdmin == true) ...[
                ListTile(
                  leading: const Icon(
                    Icons.supervisor_account_outlined,
                    color: Colors.white70,
                  ),
                  title: Text(
                    'Gestionar Entrenadores',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrainersManagementScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white70,
                  ),
                  title: Text(
                    'Finanzas Generales',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SuperAdminFinancesScreen(),
                      ),
                    );
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: Colors.white70),
                title: Text(
                  'Configuración',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminSettingsScreen(),
                    ),
                  );
                },
              ),
              const Spacer(),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text(
                  'Cerrar Sesión',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutConfirmDialog();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _error != null
          ? Center(
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
                      style: const TextStyle(color: Color(0xFF737373)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Dark Header Section
                    _buildHeader(),

                    // 2. Performance horizontal cards
                    _buildUpperStatsCarousel(),

                    // 3. Clientes Section Title & List
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20.0,
                        24.0,
                        20.0,
                        12.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Clientes',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF171717),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showRegisterClientBottomSheet,
                            icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.black, size: 18),
                            label: Text(
                              'Dar de alta',
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              backgroundColor: const Color(0xFFF5F5F5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildClientsHorizontalList(),

                    const SizedBox(height: 20),

                    // 4. Metrics summary grid
                    _buildMetricsSummaryGrid(),

                    const SizedBox(height: 20),

                    // News Carousel (Novedades)
                    NewsCarousel(news: _news),

                    const SizedBox(height: 40),

                    // 6. Brand Logo Footer
                    _buildBrandFooter(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0F0F), Color(0xFF262626)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20.0, 48.0, 20.0, 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  );
                },
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Dashboard',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFA3A3A3),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _coachProfile?.name ?? 'Entrenador',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _showLogoutConfirmDialog,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE5E5E5),
                        backgroundImage: _coachProfile?.avatarUrl != null &&
                                _coachProfile!.avatarUrl!.isNotEmpty
                            ? NetworkImage(_coachProfile!.avatarUrl!)
                            : const NetworkImage(
                                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200',
                              ) as ImageProvider,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpperStatsCarousel() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
      child: Row(
        children: [
          // Card 1
          Container(
            width: 260,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF171717), Color(0xFF3A3A3A)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Desempeño en los objetivos de todos',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFA3A3A3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '${_calculateOverallCompliance().toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Card 2
          Container(
            width: 180,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Objetivos cumplidos',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF737373),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '${_calculateTotalExercises()}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF171717),
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientsHorizontalList() {
    if (_clients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Text('No hay clientes registrados aún.'),
      );
    }

    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: _clients.length,
        itemBuilder: (context, index) {
          final client = _clients[index];

          // Calculate individual objectives progress
          double progressPercent = _clientProgressMap[client.userID] ?? 0.0;

          return Container(
            width: 170,
            margin: const EdgeInsets.only(right: 12.0, bottom: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Name Header
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          client.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF171717),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.account_circle,
                        color: Color(0xFF737373),
                        size: 20,
                      ),
                    ],
                  ),
                ),

                // Weight Metrics
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Peso actual',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF737373),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${client.currentWeight.toStringAsFixed(0)} kg',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF171717),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Anterior',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF737373),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${client.initialWeight.toStringAsFixed(0)} kg',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF525252),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Compliance performance
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Desempeño',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF737373),
                        ),
                      ),
                      Text(
                        '${progressPercent.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Manage Button
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF171717), Color(0xFF333333)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: TextButton(
                    onPressed: () => _showManageClientBottomSheet(client),
                    child: Text(
                      'Gestionar',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricsSummaryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          // Total Users Card (Dark background)
          Expanded(
            child: Container(
              height: 140,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Usuarios\ntotales',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFA3A3A3),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    '${_clients.length}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Active Clients Card (White background with borders)
          Expanded(
            child: Container(
              height: 140,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Clientes\nactivos',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF737373),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    '${_clients.length}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF171717),
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesSection() {
    // We can simulate horizontal updates list with fitness images
    final updates = [
      {
        'title': 'Actualización de peso - Sofía Guerrero',
        'date': 'Actualizado hace 2 horas',
        'image':
            'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&q=80&w=300',
      },
      {
        'title': 'Rutina finalizada - Alejandro Morales',
        'date': 'Actualizado ayer',
        'image':
            'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=300',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Text(
            'Actualizaciones recientes',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF171717),
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: updates.length,
            itemBuilder: (context, index) {
              final update = updates[index];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(update['image']!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        update['title']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        update['date']!,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD4D4D4),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(
                'En PersonalTrainer.mx, nos tomamos muy en serio la seguridad y privacidad de tus datos personales.',
                style: GoogleFonts.inter(color: const Color(0xFF333333), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                '• Datos recopilados: Información de perfil (nombre, edad, peso, medidas corporales) y datos de entrenamiento/nutrición con el único fin de personalizar tu plan físico.',
                style: GoogleFonts.inter(color: const Color(0xFF333333), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                '• Seguridad: Utilizamos bases de datos en la nube seguras (Supabase) con cifrado SSL para asegurar que tu información nunca sea compartida con terceros sin tu consentimiento.',
                style: GoogleFonts.inter(color: const Color(0xFF333333), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                '• Derechos: Puedes solicitar la eliminación de tu cuenta y todos tus datos guardados directamente desde la configuración de perfil o contactando a soporte.',
                style: GoogleFonts.inter(color: const Color(0xFF333333), fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
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
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: ListBody(
          children: [
            Text(
              '¿Tienes dudas con tu plan o necesitas ayuda técnica con la aplicación?',
              style: GoogleFonts.inter(color: const Color(0xFF333333), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.email_outlined, color: Colors.black, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'soporte@personaltrainer.mx',
                    style: GoogleFonts.inter(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: Colors.black, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'WhatsApp: +52 1 234 567 890',
                    style: GoogleFonts.inter(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Horario de atención: Lunes a Viernes, 9:00 AM a 6:00 PM',
              style: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 11, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
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
                                final targetId = _coachProfile?.userID ?? 'mock-user-123';
                                final success = await _supabaseService.importSharedRoutine(routine, targetId);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? '¡Rutina importada a tus plantillas con éxito! 🎉'
                                            : 'Error al importar rutina.',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: success ? Colors.black : Colors.redAccent,
                                    ),
                                  );
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
                                'Importar a Mis Plantillas',
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
}

class ManageClientBottomSheet extends StatefulWidget {
  final UserProfile client;
  const ManageClientBottomSheet({super.key, required this.client});

  @override
  State<ManageClientBottomSheet> createState() =>
      _ManageClientBottomSheetState();
}

class _ManageClientBottomSheetState extends State<ManageClientBottomSheet> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  int _activeTab = 0; // 0 = Exercises, 1 = Meals

  List<Routine> _routines = [];
  List<MealItem> _meals = [];
  List<Exercise> _catalogExercises = [];

  List<WorkoutLog> _todayWorkoutLogs = [];
  List<MealItem> _todayMeals = [];

  // New Routine Form
  final _routineFormKey = GlobalKey<FormState>();
  String _newRoutineName = '';

  // Add Exercise to Routine Form State (per routine)
  String? _routineIdForAddingExercise;
  String? _selectedExerciseId;
  int _exSets = 4;
  int _exReps = 12;
  String _exSeriesType = 'Normal';
  final List<TextEditingController> _weightControllers = [];

  // Add Meal Form state
  final _mealFormKey = GlobalKey<FormState>();
  String _mealName = '';
  int _mealCalories = 250;
  double _mealProtein = 20.0;
  double _mealCarbs = 20.0;
  double _mealFat = 5.0;

  @override
  void initState() {
    super.initState();
    _loadClientDetails();
  }

  @override
  void dispose() {
    for (var ctrl in _weightControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _updateWeightControllers(int setsCount) {
    for (var ctrl in _weightControllers) {
      ctrl.dispose();
    }
    _weightControllers.clear();
    for (int i = 0; i < setsCount; i++) {
      _weightControllers.add(TextEditingController(text: '0.0'));
    }
  }

  Future<void> _loadClientDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final routinesList = await _supabaseService.getRoutines(
        userId: widget.client.userID,
      );
      final mealList = await _supabaseService.getRecentMeals(
        userId: widget.client.userID,
      );
      final catalog = await _supabaseService.getExercises();

      final workoutLogs = await _supabaseService.getWorkoutLogs(
        userId: widget.client.userID,
      );
      final allMeals = await _supabaseService.getAllMeals(
        userId: widget.client.userID,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayLogs = workoutLogs.where((log) {
        final logDate = DateTime(
          log.completedAt.year,
          log.completedAt.month,
          log.completedAt.day,
        );
        return logDate.isAtSameMomentAs(today);
      }).toList();

      final todayMealsList = allMeals.where((meal) {
        final mealDate = DateTime(
          meal.consumedAt.year,
          meal.consumedAt.month,
          meal.consumedAt.day,
        );
        return mealDate.isAtSameMomentAs(today);
      }).toList();

      if (mounted) {
        setState(() {
          _routines = routinesList;
          _meals = mealList;
          _catalogExercises = catalog;
          _todayWorkoutLogs = todayLogs;
          _todayMeals = todayMealsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitRoutine() async {
    if (!_routineFormKey.currentState!.validate()) return;
    _routineFormKey.currentState!.save();

    final success = await _supabaseService.addRoutine(
      _newRoutineName,
      widget.client.userID,
    );

    if (success && mounted) {
      _routineFormKey.currentState!.reset();
      _loadClientDetails();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rutina creada con éxito'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  Future<void> _deleteRoutine(String routineId) async {
    final success = await _supabaseService.deleteRoutine(routineId);
    if (success && mounted) {
      _loadClientDetails();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rutina eliminada con éxito'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  Future<void> _submitRoutineExercise(String routineId) async {
    if (_selectedExerciseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un ejercicio'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final List<double> weights = _weightControllers.map((ctrl) {
      return double.tryParse(ctrl.text) ?? 0.0;
    }).toList();

    final newEx = RoutineExercise(
      id: '',
      routineId: routineId,
      exerciseId: _selectedExerciseId!,
      sets: _exSets,
      reps: _exReps,
      seriesWeights: weights,
      seriesType: _exSeriesType,
    );

    final success = await _supabaseService.addRoutineExercise(newEx);

    if (success && mounted) {
      setState(() {
        _routineIdForAddingExercise = null;
        _selectedExerciseId = null;
      });
      _loadClientDetails();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ejercicio asignado con éxito'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  Future<void> _deleteRoutineExercise(String routineExId) async {
    final success = await _supabaseService.deleteRoutineExercise(routineExId);
    if (success && mounted) {
      _loadClientDetails();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ejercicio quitado con éxito'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  Future<void> _submitMeal() async {
    if (!_mealFormKey.currentState!.validate()) return;
    _mealFormKey.currentState!.save();

    final success = await _supabaseService.addMeal(
      _mealName,
      _mealCalories,
      _mealProtein,
      _mealCarbs,
      _mealFat,
      userId: widget.client.userID,
    );

    if (success && mounted) {
      _mealFormKey.currentState!.reset();
      _loadClientDetails();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comida registrada con éxito')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      padding: EdgeInsets.fromLTRB(20.0, 16.0, 20.0, bottomInset + 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5E5),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0xFFF5F5F5),
                child: Icon(Icons.person, color: Color(0xFF737373), size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.client.name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF171717),
                      ),
                    ),
                    Text(
                      '${widget.client.age} años • ${widget.client.height.toStringAsFixed(0)} cm de estatura',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF737373)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricItem(
                  'Inicial',
                  '${widget.client.initialWeight.toStringAsFixed(0)} kg',
                ),
                _buildMetricDivider(),
                _buildMetricItem(
                  'Actual',
                  '${widget.client.currentWeight.toStringAsFixed(0)} kg',
                ),
                _buildMetricDivider(),
                _buildMetricItem(
                  'Meta',
                  '${widget.client.targetWeight.toStringAsFixed(0)} kg',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordsScreen(
                    userId: widget.client.userID,
                    clientName: widget.client.name,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.analytics_outlined,
              color: Colors.black,
              size: 18,
            ),
            label: Text(
              'Ver Historial de Medidas y Progreso 📈',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: Colors.black),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClientDailyManagementScreen(client: widget.client),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.black,
                    size: 16,
                  ),
                  label: Text(
                    'Gestión Diaria 📅',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (!kIsWeb && Platform.isAndroid) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ClientFinancesScreen(client: widget.client),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.credit_card_outlined,
                      color: Colors.black,
                      size: 16,
                    ),
                    label: Text(
                      'Ver Finanzas 💳',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildTodaySummaryCard(),
          const SizedBox(height: 16),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 0),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _activeTab == 0
                            ? const Color(0xFF171717)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          'Rutina de Ejercicios',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _activeTab == 0
                                ? Colors.white
                                : const Color(0xFF737373),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 1),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _activeTab == 1
                            ? const Color(0xFF171717)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          'Comidas Recientes',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _activeTab == 1
                                ? Colors.white
                                : const Color(0xFF737373),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  )
                : SingleChildScrollView(
                    child: _activeTab == 0
                        ? _buildExercisesTab()
                        : _buildMealsTab(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummaryCard() {
    double totalCalories = 0;
    double totalProtein = 0;

    for (var meal in _todayMeals) {
      totalCalories += meal.calories;
      totalProtein += meal.protein;
    }

    final workoutsCount = _todayWorkoutLogs.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today, size: 16, color: Colors.black),
              const SizedBox(width: 6),
              Text(
                'Resumen del Día (Hoy)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.fitness_center,
                      size: 16,
                      color: Color(0xFF737373),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Entrenamiento',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF737373),
                            ),
                          ),
                          Text(
                            workoutsCount > 0
                                ? '$workoutsCount realizado${workoutsCount == 1 ? '' : 's'}'
                                : 'Sin realizar',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: const Color(0xFFE5E5E5)),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant,
                      size: 16,
                      color: Color(0xFF737373),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comidas de Hoy',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF737373),
                            ),
                          ),
                          Text(
                            totalCalories > 0
                                ? '${totalCalories.toStringAsFixed(0)} kcal • ${totalProtein.toStringAsFixed(0)}g P'
                                : 'Sin registros',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xFF737373),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF171717),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(width: 1, height: 24, color: const Color(0xFFE5E5E5));
  }

  Widget _buildExercisesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Form(
          key: _routineFormKey,
          child: ExpansionTile(
            title: Text(
              'Crear Nueva Rutina',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            iconColor: Colors.black,
            collapsedIconColor: Colors.black,
            childrenPadding: const EdgeInsets.only(bottom: 16),
            children: [
              TextFormField(
                style: const TextStyle(color: Color(0xFF171717)),
                decoration: _buildInputDecoration(
                  'Nombre de la Rutina (ej. Pierna Enfoque Glúteo)',
                  Icons.assignment,
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Ingresa el nombre de la rutina'
                    : null,
                onSaved: (val) => _newRoutineName = val ?? '',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submitRoutine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF171717),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Crear Rutina',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Rutinas Asignadas',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF171717),
          ),
        ),
        const SizedBox(height: 8),
        if (_routines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text(
                'No hay rutinas creadas para este cliente.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA3A3A3),
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _routines.length,
            itemBuilder: (context, index) {
              final routine = _routines[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            routine.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF171717),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => _deleteRoutine(routine.id),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFE5E5E5)),
                    if (routine.exercises.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'No hay ejercicios asignados a esta rutina.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFA3A3A3),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ...routine.exercises.map((re) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.fitness_center,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      re.exerciseName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF171717),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${re.sets} series x ${re.reps} reps • ${re.seriesWeights.map((w) => "${w.toStringAsFixed(0)} kg").join(", ")} • ${re.seriesType}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: const Color(0xFF737373),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Color(0xFF737373),
                                  size: 16,
                                ),
                                onPressed: () => _deleteRoutineExercise(re.id),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    if (_routineIdForAddingExercise == routine.id) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Asignar Ejercicio',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: _selectedExerciseId,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF171717),
                                fontSize: 13,
                              ),
                              decoration: _buildInputDecoration(
                                'Selecciona ejercicio',
                                Icons.fitness_center,
                              ),
                              items: _catalogExercises.map((e) {
                                return DropdownMenuItem<String>(
                                  value: e.id,
                                  child: Text(
                                    e.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedExerciseId = val;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _exSets.toString(),
                                    style: const TextStyle(
                                      color: Color(0xFF171717),
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: _buildInputDecoration(
                                      'Series',
                                      Icons.repeat,
                                    ),
                                    onChanged: (val) {
                                      final newSets = int.tryParse(val) ?? 1;
                                      setState(() {
                                        _exSets = newSets > 0 ? newSets : 1;
                                        _updateWeightControllers(_exSets);
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _exReps.toString(),
                                    style: const TextStyle(
                                      color: Color(0xFF171717),
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: _buildInputDecoration(
                                      'Reps',
                                      Icons.replay,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _exReps = int.tryParse(val) ?? 10;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _exSeriesType,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF171717),
                                      fontSize: 12,
                                    ),
                                    decoration: _buildInputDecoration(
                                      'Tipo',
                                      Icons.star_border,
                                    ),
                                    items:
                                        [
                                          'Normal',
                                          'Biserie',
                                          'Triserie',
                                          'Superset',
                                        ].map((type) {
                                          return DropdownMenuItem<String>(
                                            value: type,
                                            child: Text(type),
                                          );
                                        }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _exSeriesType = val ?? 'Normal';
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Peso por serie (kg):',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF737373),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(_exSets, (idx) {
                                if (_weightControllers.length <= idx) {
                                  _weightControllers.add(
                                    TextEditingController(text: '0.0'),
                                  );
                                }
                                return SizedBox(
                                  width: 70,
                                  child: TextFormField(
                                    controller: _weightControllers[idx],
                                    style: GoogleFonts.inter(
                                      color: Colors.black,
                                      fontSize: 12,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      prefixText: '#${idx + 1}: ',
                                      prefixStyle: GoogleFonts.inter(
                                        color: const Color(0xFF737373),
                                        fontSize: 11,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E5E5),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _routineIdForAddingExercise = null;
                                    });
                                  },
                                  child: Text(
                                    'Cancelar',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF737373),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () =>
                                      _submitRoutineExercise(routine.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Asignar',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _routineIdForAddingExercise = routine.id;
                            _selectedExerciseId = null;
                            _updateWeightControllers(_exSets);
                          });
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          'Agregar Ejercicio',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMealsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Register Meal Form
        Form(
          key: _mealFormKey,
          child: ExpansionTile(
            title: Text(
              'Registrar Nueva Comida',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            iconColor: Colors.black,
            collapsedIconColor: Colors.black,
            childrenPadding: const EdgeInsets.only(bottom: 16),
            children: [
              TextFormField(
                style: const TextStyle(color: Color(0xFF171717)),
                decoration: _buildInputDecoration(
                  'Nombre de la Comida (ej. Batido Proteico)',
                  Icons.restaurant,
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Ingresa el nombre de la comida'
                    : null,
                onSaved: (val) => _mealName = val ?? '',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      style: const TextStyle(color: Color(0xFF171717)),
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        'Kcal',
                        Icons.local_fire_department_outlined,
                      ),
                      validator: (val) =>
                          val == null || int.tryParse(val) == null
                          ? 'Obligatorio'
                          : null,
                      onSaved: (val) =>
                          _mealCalories = int.tryParse(val ?? '') ?? 250,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      style: const TextStyle(color: Color(0xFF171717)),
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        'Proteína (g)',
                        Icons.egg_outlined,
                      ),
                      validator: (val) =>
                          val == null || double.tryParse(val) == null
                          ? 'Obligatorio'
                          : null,
                      onSaved: (val) =>
                          _mealProtein = double.tryParse(val ?? '') ?? 20.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      style: const TextStyle(color: Color(0xFF171717)),
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        'Carbo (g)',
                        Icons.bakery_dining_outlined,
                      ),
                      validator: (val) =>
                          val == null || double.tryParse(val) == null
                          ? 'Obligatorio'
                          : null,
                      onSaved: (val) =>
                          _mealCarbs = double.tryParse(val ?? '') ?? 20.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      style: const TextStyle(color: Color(0xFF171717)),
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        'Grasas (g)',
                        Icons.opacity,
                      ),
                      validator: (val) =>
                          val == null || double.tryParse(val) == null
                          ? 'Obligatorio'
                          : null,
                      onSaved: (val) =>
                          _mealFat = double.tryParse(val ?? '') ?? 5.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submitMeal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF171717),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Registrar Comida',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Historial de Comidas',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF171717),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MealHistoryScreen(userId: widget.client.userID),
                  ),
                );
              },
              icon: const Icon(Icons.history, color: Colors.black, size: 14),
              label: Text(
                'Ver Historial Completo',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_meals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text(
                'No hay comidas registradas recientemente.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA3A3A3),
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _meals.length,
            itemBuilder: (context, index) {
              final meal = _meals[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Row(
                  children: [
                    if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty) ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7.0),
                          child: Image.network(
                            meal.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.restaurant,
                                  color: Color(0xFF737373),
                                  size: 16,
                                ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.restaurant,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF171717),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${meal.calories} kcal • P: ${meal.protein}g • C: ${meal.carbs}g • G: ${meal.fat}g',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF737373),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFFA3A3A3),
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF737373), size: 16),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 12.0,
        horizontal: 12.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

}


