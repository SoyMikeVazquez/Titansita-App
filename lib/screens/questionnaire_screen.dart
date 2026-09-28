import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../models/registration_question.dart';

class QuestionnaireScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const QuestionnaireScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

  bool _isLoading = true;
  bool _isSaving = false;
  List<RegistrationQuestion> _questions = [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await _supabaseService.getRegistrationQuestions();
      for (final q in questions) {
        _controllers[q.id] = TextEditingController();
      }
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitAnswers() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final answers = _questions.map((q) {
      return {
        'question_id': q.id,
        'question_text': q.questionText,
        'answer': _controllers[q.id]?.text ?? '',
      };
    }).toList();

    await _supabaseService.saveQuestionnaireAnswers(widget.userId, answers);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _skipQuestionnaire() {
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : _questions.isEmpty
                ? _buildEmptyState()
                : _buildQuestionnaireForm(),
      ),
    );
  }

  Widget _buildEmptyState() {
    // No questions configured, auto-skip
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, false);
    });
    return const Center(
      child: CircularProgressIndicator(color: Colors.black),
    );
  }

  Widget _buildQuestionnaireForm() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¡Bienvenido, ${widget.userName}!',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Antes de comenzar, tu entrenador necesita conocerte mejor. Responde estas preguntas para personalizar tu experiencia.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFF737373),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Text(
                    '${_questions.where((q) => q.isRequired).length} obligatorias  •  ${_questions.where((q) => !q.isRequired).length} opcionales',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF525252),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  ...List.generate(_questions.length, (index) {
                    final question = _questions[index];
                    return _buildQuestionCard(question, index + 1);
                  }),
                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitAnswers,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Enviar respuestas',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Skip Button
                  TextButton(
                    onPressed: _isSaving ? null : _skipQuestionnaire,
                    child: Text(
                      'Responder después',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF737373),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(RegistrationQuestion question, int number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Number Badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.questionText,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF171717),
                        height: 1.4,
                      ),
                    ),
                    if (question.isRequired) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Obligatoria',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFFA3A3A3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _controllers[question.id],
            maxLines: 3,
            minLines: 1,
            style: GoogleFonts.inter(
              color: const Color(0xFF171717),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Escribe tu respuesta aquí...',
              hintStyle: GoogleFonts.inter(
                color: const Color(0xFFA3A3A3),
                fontSize: 14,
              ),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            ),
            validator: (val) {
              if (question.isRequired && (val == null || val.trim().isEmpty)) {
                return 'Esta pregunta es obligatoria';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
