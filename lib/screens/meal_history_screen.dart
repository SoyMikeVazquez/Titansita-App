import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/meal_item.dart';
import '../services/supabase_service.dart';

class MealHistoryScreen extends StatefulWidget {
  final String? userId; // If null, defaults to the logged-in client

  const MealHistoryScreen({super.key, this.userId});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  
  List<MealItem> _allMeals = [];
  List<MealItem> _filteredMeals = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _dateFilter = 'Todos'; // 'Todos', 'Hoy', '7d'

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final list = await _supabaseService.getAllMeals(userId: widget.userId);
      if (mounted) {
        setState(() {
          _allMeals = list;
          _isLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar historial: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _applyFilters() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final sevenDaysAgo = startOfToday.subtract(const Duration(days: 7));

    setState(() {
      _filteredMeals = _allMeals.where((meal) {
        // 1. Search Query Filter (name/description matching)
        final matchSearch = meal.name.toLowerCase().contains(_searchQuery.toLowerCase());

        // 2. Date Filter
        bool matchDate = true;
        if (_dateFilter == 'Hoy') {
          matchDate = meal.consumedAt.isAfter(startOfToday) || 
                      (meal.consumedAt.year == today.year && 
                       meal.consumedAt.month == today.month && 
                       meal.consumedAt.day == today.day);
        } else if (_dateFilter == '7d') {
          matchDate = meal.consumedAt.isAfter(sevenDaysAgo);
        }

        return matchSearch && matchDate;
      }).toList();
    });
  }

  void _showFullImage(String url, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  title,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildSearchDecoration() {
    return InputDecoration(
      hintText: 'Buscar comida por descripción...',
      hintStyle: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 14),
      prefixIcon: const Icon(Icons.search, color: Color(0xFF737373), size: 20),
      suffixIcon: _searchQuery.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, color: Color(0xFF737373), size: 18),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                });
                _applyFilters();
              },
            )
          : null,
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _dateFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _dateFilter = value;
        });
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFE5E5E5),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : const Color(0xFF737373),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Historial de Comidas 📋',
          style: GoogleFonts.inter(
            color: const Color(0xFF171717),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadMeals,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: TextFormField(
                style: GoogleFonts.inter(color: const Color(0xFF171717), fontSize: 14),
                decoration: _buildSearchDecoration(),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                  _applyFilters();
                },
              ),
            ),

            // 2. Date Filter Row
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 16.0),
              child: Row(
                children: [
                  _buildFilterChip('Todas', 'Todos'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Hoy', 'Hoy'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Últimos 7 días', '7d'),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE5E5E5)),

            // 3. Meals List Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : _filteredMeals.isEmpty
                      ? RefreshIndicator(
                          color: Colors.black,
                          backgroundColor: Colors.white,
                          onRefresh: _loadMeals,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.5,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.no_meals_outlined, size: 64, color: Color(0xFFD4D4D4)),
                                  const SizedBox(height: 16),
                                  Text(
                                    _allMeals.isEmpty
                                        ? 'No hay registros de comida en el historial.'
                                        : 'Ninguna comida coincide con los filtros.',
                                    style: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: Colors.black,
                          backgroundColor: Colors.white,
                          onRefresh: _loadMeals,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                          itemCount: _filteredMeals.length,
                          itemBuilder: (context, index) {
                            final meal = _filteredMeals[index];
                            final timeStr = DateFormat('hh:mm a').format(meal.consumedAt);
                            final dateStr = DateFormat('EEEE, d \'de\' MMMM', 'es').format(meal.consumedAt);
                            final formattedDate = dateStr[0].toUpperCase() + dateStr.substring(1);

                            // Parse Name and Description if combined: "Name (Description)"
                            String nameText = meal.name;
                            String descriptionText = '';
                            if (meal.name.contains('(') && meal.name.endsWith(')')) {
                              final startIndex = meal.name.indexOf('(');
                              nameText = meal.name.substring(0, startIndex).trim();
                              descriptionText = meal.name.substring(startIndex + 1, meal.name.length - 1).trim();
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20.0),
                                border: Border.all(color: const Color(0xFFE5E5E5), width: 1.2),
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
                                  // Image + Text Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image Column
                                      GestureDetector(
                                        onTap: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                                            ? () => _showFullImage(meal.imageUrl!, nameText)
                                            : null,
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFAFAFA),
                                            borderRadius: BorderRadius.circular(12.0),
                                            border: Border.all(color: const Color(0xFFE5E5E5)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10.8),
                                            child: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                                                ? Image.network(
                                                    meal.imageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                                      Icons.restaurant,
                                                      color: Color(0xFFA3A3A3),
                                                      size: 24,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.restaurant,
                                                    color: Color(0xFFA3A3A3),
                                                    size: 24,
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Details Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    nameText,
                                                    style: GoogleFonts.inter(
                                                      color: const Color(0xFF171717),
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    '${meal.calories} kcal',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (descriptionText.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                descriptionText,
                                                style: GoogleFonts.inter(
                                                  color: const Color(0xFF737373),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.access_time, size: 12, color: Color(0xFFA3A3A3)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$formattedDate a las $timeStr',
                                                  style: GoogleFonts.inter(
                                                    color: const Color(0xFFA3A3A3),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  const Divider(height: 1, color: Color(0xFFF5F5F5)),
                                  const SizedBox(height: 10),

                                  // Macro Badges Row
                                  Row(
                                    children: [
                                      _buildMacroBadge('Prot', '${meal.protein.toStringAsFixed(0)}g'),
                                      const SizedBox(width: 6),
                                      _buildMacroBadge('Carbs', '${meal.carbs.toStringAsFixed(0)}g'),
                                      const SizedBox(width: 6),
                                      _buildMacroBadge('Grasa', '${meal.fat.toStringAsFixed(0)}g'),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.8),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF737373)),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
