import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/recipe.dart';
import '../services/supabase_service.dart';
import 'add_recipe_screen.dart';

class AdminRecipesScreen extends StatefulWidget {
  const AdminRecipesScreen({super.key});

  @override
  State<AdminRecipesScreen> createState() => _AdminRecipesScreenState();
}

class _AdminRecipesScreenState extends State<AdminRecipesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _selectedCategory = 'Todas';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'name': 'Todas', 'emoji': '🍽️'},
    {'name': 'Fácil de realizar', 'emoji': '⚡'},
    {'name': 'Snacks', 'emoji': '🍿'},
    {'name': 'Más Proteínas', 'emoji': '💪'},
    {'name': 'Sin Gluten', 'emoji': '🌾'},
    {'name': 'Intolerantes a la Lactosa', 'emoji': '🥛'},
    {'name': 'Keto', 'emoji': '🥑'},
    {'name': 'Más Carbohidratos', 'emoji': '🍠'},
    {'name': 'Volumen Limpio', 'emoji': '📈'},
    {'name': 'Desayunos', 'emoji': '🍳'},
    {'name': 'Comidas', 'emoji': '🍗'},
    {'name': 'Cenas', 'emoji': '🥗'},
    {'name': 'Licuados', 'emoji': '🥤'},
    {'name': 'No Oficiales (Toleradas)', 'emoji': '🍕'},
  ];

  List<Recipe> _getFilteredRecipes() {
    List<Recipe> result = _recipes;

    // Filter by Category
    if (_selectedCategory != 'Todas') {
      result = result.where((recipe) {
        final titleLower = recipe.title.toLowerCase();
        final difficultyLower = recipe.difficulty.toLowerCase();
        final ingredientsLower = recipe.ingredients.map((i) => i.toLowerCase()).join(' ');

        switch (_selectedCategory) {
          case 'Fácil de realizar':
            return difficultyLower.contains('fácil') || difficultyLower.contains('facil') || difficultyLower.contains('muy fácil');
          case 'Snacks':
            return titleLower.contains('snack') || 
                   titleLower.contains('yogur') || 
                   titleLower.contains('avena') ||
                   titleLower.contains('barra') ||
                   recipe.calories < 250;
          case 'Más Proteínas':
            return recipe.protein >= 30.0;
          case 'Sin Gluten':
            return titleLower.contains('sin gluten') || 
                   titleLower.contains('gluten-free') || 
                   (!ingredientsLower.contains('harina de trigo') && 
                    !ingredientsLower.contains('pan ') && 
                    !ingredientsLower.contains('pasta ') &&
                    !ingredientsLower.contains('gluten'));
          case 'Intolerantes a la Lactosa':
            return titleLower.contains('sin lactosa') || 
                   titleLower.contains('lactose-free') || 
                   (!ingredientsLower.contains('leche entera') && 
                    !ingredientsLower.contains('queso feta') && 
                    !ingredientsLower.contains('yogur griego') && 
                    !ingredientsLower.contains('queso ') && 
                    !ingredientsLower.contains('crema '));
          case 'Keto':
            return recipe.fat > (recipe.protein + recipe.carbs) || recipe.carbs <= 15.0;
          case 'Más Carbohidratos':
            return recipe.carbs >= 45.0;
          case 'Volumen Limpio':
            return recipe.calories >= 450 && recipe.protein >= 30.0 && recipe.carbs >= 35.0;
          case 'Desayunos':
            return titleLower.contains('avena') || 
                   titleLower.contains('desayuno') || 
                   titleLower.contains('huevo') || 
                   titleLower.contains('pancake') || 
                   titleLower.contains('waffle') || 
                   titleLower.contains('omelet') || 
                   titleLower.contains('tostada');
          case 'Comidas':
            return titleLower.contains('pollo') || 
                   titleLower.contains('filete') || 
                   titleLower.contains('carne') || 
                   titleLower.contains('arroz') || 
                   titleLower.contains('salmón') || 
                   titleLower.contains('quinoa') || 
                   titleLower.contains('tazón') ||
                   titleLower.contains('pasta');
          case 'Cenas':
            return titleLower.contains('cena') || 
                   titleLower.contains('ensalada') || 
                   titleLower.contains('pechuga') || 
                   titleLower.contains('sopa') || 
                   recipe.calories < 400;
          case 'Licuados':
            return titleLower.contains('licuado') || 
                   titleLower.contains('batido') || 
                   titleLower.contains('smoothie') || 
                   titleLower.contains('shake') ||
                   ingredientsLower.contains('licuar');
          case 'No Oficiales (Toleradas)':
            return titleLower.contains('tolerante') || 
                   titleLower.contains('no oficial') || 
                   titleLower.contains('permitida') ||
                   titleLower.contains('antojo') ||
                   recipe.calories > 600 || 
                   recipe.fat > 25;
          default:
            return true;
        }
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      result = result.where((recipe) {
        return recipe.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               recipe.ingredients.any((i) => i.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = _supabaseService.loggedInUserProfile;
    _isAdmin = user?.isAdmin ?? false;
    final recipes = await _supabaseService.getRecipes();
    if (mounted) {
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    }
  }

  Future<void> _logRecipeAsMeal(Recipe recipe) async {
    // Show a loading indicator during logging
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    final success = await _supabaseService.addMeal(
      recipe.title,
      recipe.calories,
      recipe.protein,
      recipe.carbs,
      recipe.fat,
      imageUrl: recipe.imageUrl,
    );

    if (mounted) {
      Navigator.pop(context); // Dismiss loading spinner
      if (success) {
        Navigator.pop(context); // Close recipe detail bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Comida registrada en tu bitácora de hoy! 🍽️',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al registrar la comida'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void showRecipeDetails(Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
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
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                    ? Image.network(
                        recipe.imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: const Color(0xFFF5F5F5),
                          child: const Icon(Icons.restaurant, color: Colors.grey, size: 50),
                        ),
                      )
                    : Container(
                        height: 200,
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(Icons.restaurant, color: Colors.grey, size: 50),
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                recipe.title,
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTag('${recipe.calories} kcal', Colors.redAccent),
                  const SizedBox(width: 6),
                  _buildTag('${recipe.protein.toStringAsFixed(0)}g P', Colors.green),
                  const SizedBox(width: 6),
                  _buildTag('${recipe.carbs.toStringAsFixed(0)}g C', Colors.amber),
                  const SizedBox(width: 6),
                  _buildTag('${recipe.fat.toStringAsFixed(0)}g G', Colors.blue),
                ],
              ),
              const Divider(height: 32, color: Color(0xFFE5E5E5)),
              Text(
                'Ingredientes',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 10),
              ...List.generate(recipe.ingredients.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check, size: 16, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          recipe.ingredients[index],
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF525252)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 32, color: Color(0xFFE5E5E5)),
              Text(
                'Instrucciones de Preparación',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 12),
              ...List.generate(recipe.steps.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          recipe.steps[index],
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF525252), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (!_isAdmin) ...[
                const Divider(height: 40, color: Color(0xFFE5E5E5)),
                ElevatedButton.icon(
                  onPressed: () => _logRecipeAsMeal(recipe),
                  icon: const Icon(Icons.add_task_rounded, size: 18),
                  label: Text(
                    'Registrar como mi comida de hoy',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 10),
              ]
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = _getFilteredRecipes();

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
          'Recetario Saludable',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddRecipeScreen()),
                );
                if (result == true) {
                  _loadData();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5E5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _searchController,
                style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar recetas o ingredientes...',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF737373)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF737373)),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
          ),

          // 2. Horizontal Categories list
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final name = cat['name']!;
                  final emoji = cat['emoji']!;
                  final isSelected = _selectedCategory == name;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = name;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.black : const Color(0xFFE5E5E5),
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              color: isSelected ? Colors.white : const Color(0xFF525252),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. Recipes List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : filteredRecipes.isEmpty
                    ? RefreshIndicator(
                        color: Colors.black,
                        backgroundColor: Colors.white,
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.5,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No se encontraron recetas'
                                      : 'No hay recetas en esta categoría',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF737373),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Prueba con otros términos o ingredientes'
                                      : 'Explora otras categorías de recetas',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFFA3A3A3),
                                  ),
                                ),
                                if (_isAdmin) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AddRecipeScreen()),
                                      );
                                      if (result == true) {
                                        _loadData();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                                    child: const Text('Crear Primera Receta', style: TextStyle(color: Colors.white)),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.black,
                        backgroundColor: Colors.white,
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                          itemCount: filteredRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = filteredRecipes[index];
                            return GestureDetector(
                              onTap: () => showRecipeDetails(recipe),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
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
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                      child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                                          ? Image.network(
                                              recipe.imageUrl!,
                                              height: 160,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                height: 160,
                                                color: const Color(0xFFF5F5F5),
                                                child: const Icon(Icons.restaurant, color: Colors.grey, size: 40),
                                              ),
                                            )
                                          : Container(
                                              height: 160,
                                              color: const Color(0xFFF5F5F5),
                                              child: const Icon(Icons.restaurant, color: Colors.grey, size: 40),
                                            ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  recipe.title,
                                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                                                ),
                                              ),
                                              Text(
                                                recipe.time,
                                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF737373), fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _buildTag('${recipe.calories} kcal', Colors.redAccent.withOpacity(0.1), textStyle: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 6),
                                              _buildTag('${recipe.protein.toStringAsFixed(0)}g P', Colors.green.withOpacity(0.1), textStyle: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 6),
                                              _buildTag('${recipe.carbs.toStringAsFixed(0)}g C', Colors.amber.withOpacity(0.1), textStyle: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 6),
                                              _buildTag('${recipe.fat.toStringAsFixed(0)}g G', Colors.blue.withOpacity(0.1), textStyle: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color, {TextStyle? textStyle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: textStyle ?? GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
