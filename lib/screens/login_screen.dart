import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import 'questionnaire_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _animationController;
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Encuentra tu objetivo',
      'subtitle':
          'Obtén tu mejor potencial con nuestros programas de entrenamiento',
    },
    {
      'title': 'Sigue tus rutinas',
      'subtitle':
          'Completa los ejercicios asignados y registra tu avance diario',
    },
    {
      'title': 'Nutrición al día',
      'subtitle': 'Lleva la cuenta de tus comidas y macronutrientes fácilmente',
    },
  ];

  final List<String> _col1Images = [
    'assets/fotoslogin/385035913_18294447586193915_236877727834713594_n.jpg',
    'assets/fotoslogin/410652433_18305924488193915_1129043350412617051_n.jpg',
    'assets/fotoslogin/417844490_18309237490193915_6435129336545725501_n.jpg',
  ];

  final List<String> _col2Images = [
    'assets/fotoslogin/622448595_18077963861362876_536681444998067018_n.jpg',
    'assets/fotoslogin/626155270_18106313023809488_8954044703489099676_n.jpg',
    'assets/fotoslogin/629882963_18398874685183708_9194550262749528527_n.jpg',
  ];

  final List<String> _col3Images = [
    'assets/fotoslogin/637748682_18560329423009209_2138153405911386858_n.jpg',
    'assets/fotoslogin/640382323_18573634759056247_5441525226785008867_n.jpg',
    'assets/fotoslogin/385035913_18294447586193915_236877727834713594_n.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showAuthBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AuthFormBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Staggered Masonry Grid Area
            SizedBox(
              height: screenHeight * 0.48,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: 520,
                        minHeight: 520,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16.0,
                            48.0,
                            16.0,
                            0,
                          ),
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              final value = _animationController.value;
                              final col1Offset = value * -25.0;
                              final col2Offset = (1.0 - value) * -25.0;
                              final col3Offset = -10.0 + (value * -15.0);

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Column 1
                                  Expanded(
                                    child: Transform.translate(
                                      offset: Offset(0, col1Offset),
                                      child: Column(
                                        children: [
                                          _buildGridImage(_col1Images[0], 120),
                                          const SizedBox(height: 8),
                                          _buildGridImage(_col1Images[1], 170),
                                          const SizedBox(height: 8),
                                          _buildGridImage(_col1Images[2], 120),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Column 2
                                  Expanded(
                                    child: Transform.translate(
                                      offset: Offset(0, col2Offset),
                                      child: Column(
                                        children: [
                                          _buildGridImage(_col2Images[0], 170),
                                          const SizedBox(height: 8),
                                          _buildGridImage(_col2Images[1], 150),
                                          const SizedBox(height: 8),
                                          _buildGridImage(_col2Images[2], 110),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Column 3
                                  Expanded(
                                    child: Transform.translate(
                                      offset: Offset(0, col3Offset),
                                      child: Column(
                                        children: [
                                          _buildGridImage(_col3Images[0], 130),
                                          const SizedBox(height: 8),
                                          _buildGridImage(_col3Images[1], 190),
                                          const SizedBox(height: 8),
                                          _buildGridImage(_col3Images[2], 100),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Fade gradient at the bottom of grid
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.white],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Onboarding Slider
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  final item = _onboardingData[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item['title']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item['subtitle']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF737373),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingData.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  height: 6,
                  width: _currentPage == index ? 24 : 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.black
                        : const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Pill Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 36.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _showAuthBottomSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  child: Text(
                    'Inicia sesión',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridImage(String url, double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.fitness_center,
                color: const Color(0xFFA3A3A3).withOpacity(0.5),
                size: 24,
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthFormBottomSheet extends StatefulWidget {
  const AuthFormBottomSheet({super.key});

  @override
  State<AuthFormBottomSheet> createState() => _AuthFormBottomSheetState();
}

class _AuthFormBottomSheetState extends State<AuthFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Form inputs
  String _email = '';
  String _password = '';
  String _name = '';
  double _weight = 70.0;
  double _height = 170.0;
  int _age = 25;
  bool _isAdmin = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool success = false;
    try {
      if (_isLogin) {
        success = await _supabaseService.signIn(_email, _password);
      } else {
        success = await _supabaseService.signUp(
          email: _email,
          password: _password,
          name: _name,
          isAdmin: _isAdmin,
          weight: _weight,
          height: _height,
          age: _age,
        );
      }

      if (mounted) {
        if (success) {
          if (!_isLogin && !_isAdmin) {
            // Close bottom sheet first
            Navigator.pop(context);
            // Navigate to questionnaire for new non-admin users
            final userId =
                _supabaseService.currentUser?.id ??
                _supabaseService.loggedInUserProfile?.userID ??
                '';
            if (context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      QuestionnaireScreen(userId: userId, userName: _name),
                ),
              );
            }
          } else {
            Navigator.pop(context); // Close bottom sheet
            // The StreamBuilder in main.dart will trigger rebuild
          }
        } else {
          setState(() {
            _errorMessage = 'Ocurrió un error. Inténtalo de nuevo.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        String friendlyError = 'Ocurrió un error al procesar tu solicitud.';

        if (errStr.contains('invalid_credentials') || errStr.contains('invalid login credentials')) {
          friendlyError = 'Correo electrónico o contraseña incorrectos. Por favor verifica tus datos e intenta de nuevo.';
        } else if (errStr.contains('user_not_found') || errStr.contains('user not found')) {
          friendlyError = 'No encontramos ninguna cuenta registrada con este correo electrónico.';
        } else if (errStr.contains('email_not_confirmed') || errStr.contains('email not confirmed')) {
          friendlyError = 'Tu correo electrónico aún no ha sido confirmado. Revisa tu bandeja de entrada.';
        } else if (errStr.contains('user_already_exists') || errStr.contains('already registered') || errStr.contains('already exists')) {
          friendlyError = 'Este correo electrónico ya está registrado. Intenta iniciar sesión.';
        } else if (errStr.contains('weak_password') || errStr.contains('password should be at least')) {
          friendlyError = 'La contraseña es muy corta. Debe tener al menos 6 caracteres.';
        } else if (errStr.contains('over_request_rate_limit') || errStr.contains('rate limit')) {
          friendlyError = 'Demasiados intentos fallidos. Por favor espera unos minutos antes de reintentar.';
        } else if (errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed to host lookup')) {
          friendlyError = 'No se pudo conectar al servidor. Comprueba tu conexión a internet.';
        }

        setState(() {
          _errorMessage = friendlyError;
          _isLoading = false;
        });
      }
    }
  }

  void _demoLogin(bool coach) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _supabaseService
        .signInDemo(coach)
        .then((_) {
          if (mounted) {
            Navigator.pop(context);
          }
        })
        .catchError((e) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Error en demo: $e';
              _isLoading = false;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 16.0, spreadRadius: 2.0),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24.0, 16.0, 24.0, bottomInset + 24.0),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Handle
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

              // Logo
              Center(
                child: Image.asset(
                  'assets/logo_transparent.png',
                  height: 120, // Adjust height as needed
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                _isLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              // Custom sliding tab selector removed to disable self-registration
              // const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF991B1B),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Full Name field (Register only)
              if (!_isLogin) ...[
                TextFormField(
                  style: const TextStyle(color: Color(0xFF171717)),
                  decoration: _buildInputDecoration(
                    'Nombre Completo',
                    Icons.person_outline,
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Ingresa tu nombre' : null,
                  onSaved: (val) => _name = val ?? '',
                ),
                const SizedBox(height: 16),
              ],

              // Email field
              TextFormField(
                style: const TextStyle(color: Color(0xFF171717)),
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(
                  'Correo Electrónico',
                  Icons.mail_outline,
                ),
                validator: (val) => val == null || !val.contains('@')
                    ? 'Ingresa un correo válido'
                    : null,
                onSaved: (val) => _email = val ?? '',
              ),
              const SizedBox(height: 16),

              // Password field
              TextFormField(
                style: const TextStyle(color: Color(0xFF171717)),
                obscureText: _obscurePassword,
                decoration:
                    _buildInputDecoration(
                      'Contraseña',
                      Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF737373),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                validator: (val) => val == null || val.length < 6
                    ? 'Mínimo 6 caracteres'
                    : null,
                onSaved: (val) => _password = val ?? '',
              ),
              const SizedBox(height: 16),

              // Client physical params row (Register only)
              if (!_isLogin) ...[
                Row(
                  children: [
                    // Weight
                    Expanded(
                      child: TextFormField(
                        style: const TextStyle(color: Color(0xFF171717)),
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration(
                          'Peso (kg)',
                          Icons.scale_outlined,
                        ),
                        validator: (val) =>
                            val == null || double.tryParse(val) == null
                            ? 'Obligatorio'
                            : null,
                        onSaved: (val) =>
                            _weight = double.tryParse(val ?? '') ?? 70.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Height
                    Expanded(
                      child: TextFormField(
                        style: const TextStyle(color: Color(0xFF171717)),
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration(
                          'Estatura (cm)',
                          Icons.height_outlined,
                        ),
                        validator: (val) =>
                            val == null || double.tryParse(val) == null
                            ? 'Obligatorio'
                            : null,
                        onSaved: (val) =>
                            _height = double.tryParse(val ?? '') ?? 170.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Age
                    Expanded(
                      child: TextFormField(
                        style: const TextStyle(color: Color(0xFF171717)),
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration(
                          'Edad',
                          Icons.calendar_today_outlined,
                        ),
                        validator: (val) =>
                            val == null || int.tryParse(val) == null
                            ? 'Obligatorio'
                            : null,
                        onSaved: (val) => _age = int.tryParse(val ?? '') ?? 25,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // isAdmin Switch Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿Eres Administrador / Coach?',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Permite programar rutinas y comidas',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF737373),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isAdmin,
                        onChanged: (val) {
                          setState(() {
                            _isAdmin = val;
                          });
                        },
                        activeColor: Colors.black,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Submit Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLogin ? 'Ingresar a mi cuenta' : 'Crear mi cuenta',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Divider for Demo options
              // Demo options hidden for now
              /*
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFE5E5E5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'O ingresa al demo con un tap',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFFA3A3A3),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE5E5E5))),
                ],
              ),
              const SizedBox(height: 16),

              // Demo access buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _demoLogin(false),
                      icon: const Icon(Icons.person_outline, size: 16, color: Colors.black),
                      label: Text(
                        'Demo Cliente',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E5E5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _demoLogin(true),
                      icon: const Icon(Icons.star_outline, size: 16, color: Colors.black),
                      label: Text(
                        'Demo Entrenador',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E5E5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              */
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFFA3A3A3),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF737373), size: 20),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 14.0,
        horizontal: 16.0,
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
