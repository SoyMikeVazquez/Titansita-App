import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification.dart' as notif_model;
import '../services/supabase_service.dart';
import '../utils/cors_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  
  // Settings state
  bool _workoutReminders = true;
  bool _mealReminders = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  bool _isSettingsLoading = true;

  // Notifications state
  List<notif_model.Notification> _notifications = [];
  bool _isNotificationsLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadNotifications();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _workoutReminders = prefs.getBool('daily_workout_reminders') ?? true;
        _mealReminders = prefs.getBool('daily_meal_reminders') ?? true;
        final timeStr = prefs.getString('daily_reminder_time') ?? '08:00';
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          _reminderTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
        _isSettingsLoading = false;
      });
    } catch (e) {
      setState(() => _isSettingsLoading = false);
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      // Handle error quietly
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isNotificationsLoading = true;
      _error = null;
    });

    try {
      final list = await _supabaseService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isNotificationsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar notificaciones';
          _isNotificationsLoading = false;
        });
      }
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Color(0xFF171717),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      await _saveSetting('daily_reminder_time', '$hourStr:$minStr');
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'payment':
        return const Color(0xFF00A86B);
      case 'event':
        return const Color(0xFF6366F1);
      case 'community':
        return const Color(0xFFEC4899);
      case 'achievement':
        return const Color(0xFFFBBF24);
      case 'reminder':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _showNotificationDetails(notif_model.Notification notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24.0),
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
              const SizedBox(height: 20),
              // Type Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getTypeColor(notification.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getTypeColor(notification.type)),
                    ),
                    child: Text(
                      notification.getTypeLabel(),
                      style: GoogleFonts.inter(
                        color: _getTypeColor(notification.type),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Image if available
              if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    getCorsFriendlyUrl(notification.imageUrl!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                notification.title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF171717),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Color(0xFF737373)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMMM yyyy, hh:mm a', 'es').format(notification.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF737373),
                    ),
                  ),
                  if (notification.authorName != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.person_outline, size: 14, color: Color(0xFF737373)),
                    const SizedBox(width: 6),
                    Text(
                      notification.authorName!.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text(
                notification.description,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.6,
                  color: const Color(0xFF525252),
                ),
              ),
              if (notification.actionDate != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getTypeColor(notification.type).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getTypeColor(notification.type).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: _getTypeColor(notification.type)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fecha Programada',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getTypeColor(notification.type),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy - hh:mm a', 'es').format(notification.actionDate!),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF171717),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Notificaciones',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadNotifications();
          await _loadSettings();
        },
        color: Colors.black,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Settings Section Header
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
              child: Text(
                'CONFIGURACIÓN DE RECORDATORIOS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF737373),
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Settings Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: _isSettingsLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      ),
                    )
                  : Column(
                      children: [
                        // Workout reminders switch
                        SwitchListTile(
                          activeColor: Colors.black,
                          title: Text(
                            'Recordatorios de Entrenamiento',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF171717),
                            ),
                          ),
                          subtitle: Text(
                            'Recibe alertas para realizar tu rutina asignada',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF737373),
                            ),
                          ),
                          value: _workoutReminders,
                          onChanged: (val) {
                            setState(() => _workoutReminders = val);
                            _saveSetting('daily_workout_reminders', val);
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        
                        // Meal reminders switch
                        SwitchListTile(
                          activeColor: Colors.black,
                          title: Text(
                            'Recordatorios de Comidas',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF171717),
                            ),
                          ),
                          subtitle: Text(
                            'Alertas para registrar tus comidas del día',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF737373),
                            ),
                          ),
                          value: _mealReminders,
                          onChanged: (val) {
                            setState(() => _mealReminders = val);
                            _saveSetting('daily_meal_reminders', val);
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),

                        // Time Picker row
                        InkWell(
                          onTap: _selectTime,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hora de Recordatorio',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF171717),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hora sugerida para tus alertas diarias',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF737373),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _reminderTime.format(context),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 32),

            // Notifications Section Header
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
              child: Text(
                'HISTORIAL DE NOTIFICACIONES',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF737373),
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Notifications List / State
            if (_isNotificationsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: GoogleFonts.inter(color: const Color(0xFF737373)),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loadNotifications,
                        child: const Text('Reintentar', style: TextStyle(color: Colors.black)),
                      )
                    ],
                  ),
                ),
              )
            else if (_notifications.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_outlined,
                        size: 32,
                        color: Color(0xFF737373),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin Notificaciones',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF171717),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Te avisaremos cuando haya actualizaciones importantes sobre tu plan.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _notifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final isNew = !notification.isRead;
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isNew ? _getTypeColor(notification.type).withOpacity(0.3) : const Color(0xFFE5E5E5),
                        width: isNew ? 1.5 : 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _showNotificationDetails(notification),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left type badge / colored circle
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _getTypeColor(notification.type).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getNotificationIcon(notification.type),
                                size: 20,
                                color: _getTypeColor(notification.type),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Type label
                                      Text(
                                        notification.getTypeLabel().toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getTypeColor(notification.type),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      // Time since
                                      Text(
                                        _formatTimeAgo(notification.createdAt),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: const Color(0xFF737373),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notification.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF171717),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.description,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF525252),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'payment':
        return Icons.credit_card_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'community':
        return Icons.forum_outlined;
      case 'achievement':
        return Icons.emoji_events_outlined;
      case 'reminder':
        return Icons.alarm_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('dd MMM', 'es').format(dateTime);
    } else if (difference.inDays >= 1) {
      return 'Hace ${difference.inDays} ${difference.inDays == 1 ? 'día' : 'días'}';
    } else if (difference.inHours >= 1) {
      return 'Hace ${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inMinutes >= 1) {
      return 'Hace ${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'}';
    } else {
      return 'Hace un momento';
    }
  }
}
