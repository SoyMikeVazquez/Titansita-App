import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import 'api_key_screen.dart';
import 'integration_config_screen.dart';
import 'manage_questions_bottom_sheet.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();

    void showLogoutConfirmDialog() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFF171717), fontWeight: FontWeight.bold)),
          content: const Text('¿Estás seguro de que deseas salir del panel de control?', style: TextStyle(color: Color(0xFF525252))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF737373))),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Pop Settings Screen
                await supabaseService.signOut();
              },
              child: const Text('Cerrar sesión', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Configuración de la Plataforma',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Title
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                'APIS E INTEGRACIONES',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF737373),
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // OpenAI API Key
            _buildSettingsItem(
              context: context,
              icon: Icons.auto_awesome_outlined,
              iconColor: const Color(0xFF7C3AED),
              title: 'Inteligencia Artificial (OpenAI)',
              subtitle: 'Configura la API de GPT-4o para el escaneo de comidas.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ApiKeyScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // Mercado Pago API Key
            if (!kIsWeb && Platform.isAndroid)
              _buildSettingsItem(
                context: context,
                icon: Icons.payment_outlined,
                iconColor: const Color(0xFF009EE3),
                title: 'Pasarela Mercado Pago',
                subtitle: 'Configura las llaves públicas y privadas para cobros nacionales.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IntegrationConfigScreen(
                        title: 'API de Mercado Pago',
                        description: 'Ingresa tu Token de Acceso (Access Token) de Mercado Pago para automatizar el procesamiento de pagos de tus clientes.',
                        prefKey: 'mercadopago_api_key',
                        hintText: 'APP_USR-... o TEST-...',
                        icon: Icons.payment_outlined,
                        iconColor: Color(0xFF009EE3),
                        steps: [
                          'Ingresa a Mercado Pago Desarrolladores (developers.mercadopago.com).',
                          'Inicia sesión con tu cuenta y ve a la sección "Tus Integraciones".',
                          'Selecciona tu aplicación o crea una nueva.',
                          'Ve a la pestaña "Credenciales de producción" o "Credenciales de prueba".',
                          'Copia el "Access Token" y pégalo aquí.',
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (!kIsWeb && Platform.isAndroid)
              const SizedBox(height: 12),

            // Stripe API Key
            if (!kIsWeb && Platform.isAndroid)
              _buildSettingsItem(
                context: context,
                icon: Icons.credit_card_outlined,
                iconColor: const Color(0xFF635BFF),
                title: 'Pasarela Stripe',
                subtitle: 'Configura las llaves secretas de Stripe para pagos internacionales.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IntegrationConfigScreen(
                        title: 'API de Stripe',
                        description: 'Ingresa tu Clave Secreta (Secret Key) de Stripe para procesar cobros automáticos de tarjetas de débito/crédito internacionales.',
                        prefKey: 'stripe_api_key',
                        hintText: 'sk_live_... o sk_test_...',
                        icon: Icons.credit_card_outlined,
                        iconColor: Color(0xFF635BFF),
                        steps: [
                          'Accede al Dashboard de Stripe (dashboard.stripe.com) e inicia sesión.',
                          'Activa el "Developer mode" en la esquina superior derecha.',
                          'Ve al menú lateral en "Developers" -> "API keys".',
                          'Ubica la fila "Secret key" y presiona "Reveal live key" (o test key).',
                          'Copia la clave (comienza con sk_) y pégala aquí.',
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (!kIsWeb && Platform.isAndroid)
              const SizedBox(height: 12),

            // WhatsApp API Key
            _buildSettingsItem(
              context: context,
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'WhatsApp Business API',
              subtitle: 'Token de acceso de Meta para notificaciones automáticas.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IntegrationConfigScreen(
                      title: 'API de WhatsApp Business',
                      description: 'Ingresa el Token de Acceso Temporal o Permanente de Meta Developers para automatizar notificaciones y reportes de progreso directos al celular de tus clientes.',
                      prefKey: 'whatsapp_api_key',
                      hintText: 'EAABw...',
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: Color(0xFF25D366),
                      steps: [
                        'Ve a Meta for Developers (developers.facebook.com) y crea una App de tipo Business.',
                        'Configura el producto de "WhatsApp" en el panel izquierdo.',
                        'Ve a la sección "Configuración de WhatsApp" -> "Comenzar".',
                        'Genera un Token de Acceso temporal en el panel de pruebas o copia el token permanente de tu System User en Business Manager.',
                        'Pega el token aquí.',
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Questionnaire Section
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                'CUESTIONARIO DE REGISTRO',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF737373),
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Manage Questions option
            _buildSettingsItem(
              context: context,
              icon: Icons.quiz_outlined,
              iconColor: const Color(0xFFF97316),
              title: 'Cuestionario de Registro',
              subtitle: 'Configura las preguntas para nuevos clientes al registrarse.',
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const ManageQuestionsBottomSheet(),
                );
              },
            ),
            const SizedBox(height: 32),

            // General Settings Section
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                'OPCIONES GENERALES',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF737373),
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Logout option
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5E5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text(
                  'Cerrar Sesión',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                subtitle: Text(
                  'Salir de la cuenta de entrenador.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF737373)),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFA3A3A3)),
                onTap: showLogoutConfirmDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF737373)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFA3A3A3)),
        onTap: onTap,
      ),
    );
  }
}
