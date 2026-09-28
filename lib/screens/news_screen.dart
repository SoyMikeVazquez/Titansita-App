import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/news_item.dart';
import '../services/supabase_service.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<NewsItem> _newsList = [];
  String? _error;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _isAdmin = _supabaseService.loggedInUserProfile?.isAdmin ?? false;
      final list = await _supabaseService.getNews();
      if (mounted) {
        setState(() {
          _newsList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar novedades: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showAddNewsSheet() {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String content = '';
    XFile? newsPhoto;
    dynamic newsPhotoBytes;
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
            Future<void> pickNewsPhoto() async {
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
                    newsPhoto = image;
                    newsPhotoBytes = bytes;
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
                            'Publicar Novedad 📢',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF171717),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF737373)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agrega una imagen, título y descripción para la comunidad.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Photo Selector Box
                      GestureDetector(
                        onTap: pickNewsPhoto,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: newsPhotoBytes != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(newsPhotoBytes, fit: BoxFit.cover),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_a_photo_outlined, color: Color(0xFFA3A3A3), size: 36),
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

                      // News Title Input
                      TextFormField(
                        style: const TextStyle(color: Colors.black),
                        decoration: _buildInputDecoration('Título de la novedad'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa un título' : null,
                        onSaved: (val) => title = val ?? '',
                      ),
                      const SizedBox(height: 16),

                      // News Description Input
                      TextFormField(
                        maxLines: 4,
                        style: const TextStyle(color: Colors.black),
                        decoration: _buildInputDecoration('Escribe la descripción o contenido...'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el contenido' : null,
                        onSaved: (val) => content = val ?? '',
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (formKey.currentState?.validate() ?? false) {
                                  formKey.currentState?.save();
                                  setModalState(() => isSaving = true);

                                  String? uploadedUrl;
                                  if (newsPhoto != null) {
                                    uploadedUrl = await _supabaseService.uploadNewsPhoto(newsPhoto);
                                  }

                                  final success = await _supabaseService.addNews(
                                    title: title,
                                    content: content,
                                    imageUrl: uploadedUrl,
                                  );

                                  if (!context.mounted) return;
                                  setModalState(() => isSaving = false);

                                  if (success) {
                                    Navigator.pop(context);
                                    _loadNews();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Novedad publicada correctamente ✅', style: TextStyle(color: Colors.white)),
                                        backgroundColor: Colors.black,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Error al guardar la novedad'),
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
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Publicar Novedad',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
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

  void _showNewsDetails(NewsItem item) {
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
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    item.imageUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 220,
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                item.title,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Text(
                      item.authorName.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('dd MMMM yyyy, hh:mm a').format(item.createdAt),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF737373),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32, color: Color(0xFFE5E5E5)),
              Text(
                item.content,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF333333),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),
              if (_isAdmin) ...[
                const Divider(height: 32, color: Color(0xFFE5E5E5)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditNewsSheet(item),
                        icon: const Icon(Icons.edit_outlined, color: Colors.black),
                        label: Text('Editar', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmDeleteNews(item),
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                        label: Text('Eliminar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ]
            ],
          ),
        ),
      ),
    );
  }

  void _showEditNewsSheet(NewsItem item) {
    final formKey = GlobalKey<FormState>();
    String title = item.title;
    String content = item.content;
    XFile? newsPhoto;
    dynamic newsPhotoBytes;
    String? currentImageUrl = item.imageUrl;
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
            Future<void> pickNewsPhoto() async {
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
                    newsPhoto = image;
                    newsPhotoBytes = bytes;
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
                            'Editar Novedad 📝',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF171717),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF737373)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Photo Selector Box
                      GestureDetector(
                        onTap: pickNewsPhoto,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: newsPhotoBytes != null
                              ? Image.memory(newsPhotoBytes, fit: BoxFit.cover)
                              : (currentImageUrl != null && currentImageUrl.isNotEmpty)
                                  ? Image.network(currentImageUrl, fit: BoxFit.cover)
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_a_photo_outlined, color: Color(0xFFA3A3A3), size: 36),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Toca para cambiar foto 📸',
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

                      // News Title Input
                      TextFormField(
                        initialValue: title,
                        style: const TextStyle(color: Colors.black),
                        decoration: _buildInputDecoration('Título de la novedad'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa un título' : null,
                        onSaved: (val) => title = val ?? '',
                      ),
                      const SizedBox(height: 16),

                      // News Description Input
                      TextFormField(
                        initialValue: content,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.black),
                        decoration: _buildInputDecoration('Escribe la descripción o contenido...'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el contenido' : null,
                        onSaved: (val) => content = val ?? '',
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (formKey.currentState?.validate() ?? false) {
                                  formKey.currentState?.save();
                                  setModalState(() => isSaving = true);

                                  String? uploadedUrl;
                                  if (newsPhoto != null) {
                                    uploadedUrl = await _supabaseService.uploadNewsPhoto(newsPhoto);
                                  }

                                  final success = await _supabaseService.updateNews(
                                    id: item.id,
                                    title: title,
                                    content: content,
                                    imageUrl: uploadedUrl,
                                  );

                                  if (!context.mounted) return;
                                  setModalState(() => isSaving = false);

                                  if (success) {
                                    Navigator.pop(context); // close edit sheet
                                    Navigator.pop(context); // close details sheet
                                    _loadNews();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Novedad editada correctamente ✅', style: TextStyle(color: Colors.white)),
                                        backgroundColor: Colors.black,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Error al guardar la novedad'),
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
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Guardar Cambios',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
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

  Future<void> _confirmDeleteNews(NewsItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Novedad', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que deseas eliminar esta novedad? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _supabaseService.deleteNews(item.id);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context); // close details sheet
        _loadNews();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Novedad eliminada correctamente 🗑️'),
            backgroundColor: Colors.black,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar la novedad'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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

  String _getCuratedFallbackImage(int index) {
    final images = [
      'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=600',
      'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&q=80&w=600',
      'https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&q=80&w=600'
    ];
    return images[index % images.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Novedades y Noticias',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadNews,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                          child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _newsList.isEmpty
                  ? RefreshIndicator(
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      onRefresh: _loadNews,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No hay novedades publicadas aún',
                                style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF737373), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      onRefresh: _loadNews,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20.0),
                        itemCount: _newsList.length,
                        itemBuilder: (context, index) {
                          final item = _newsList[index];
                          final bgImage = (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                              ? item.imageUrl!
                              : _getCuratedFallbackImage(index);
                          return GestureDetector(
                            onTap: () => _showNewsDetails(item),
                            child: Container(
                              height: 180,
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      bgImage,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xFF171717),
                                        child: const Icon(Icons.image, color: Colors.white24, size: 40),
                                      ),
                                    ),
                                    // Gradient overlay
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.15),
                                            Colors.black.withOpacity(0.8),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            item.title,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Por ${item.authorName}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: Colors.white.withOpacity(0.8),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('dd MMM yyyy').format(item.createdAt),
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: Colors.white.withOpacity(0.6),
                                                ),
                                              ),
                                            ],
                                          )
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
                    ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: _showAddNewsSheet,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
