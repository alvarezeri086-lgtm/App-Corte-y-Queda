import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth_provider.dart';

class InterviewSchedulePage extends StatefulWidget {
  final String interviewId;
  final String activationId;
  final String candidateName;
  final String candidateId;

  const InterviewSchedulePage({
    Key? key,
    required this.interviewId,
    required this.activationId,
    required this.candidateName,
    required this.candidateId,
  }) : super(key: key);

  @override
  State<InterviewSchedulePage> createState() => _InterviewSchedulePageState();
}

class _InterviewSchedulePageState extends State<InterviewSchedulePage> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  final TextEditingController notesController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController onlineLinkController = TextEditingController();
  String interviewType = 'ONLINE'; // 'ONLINE' o 'ONSITE' para match con API
  bool isLoading = false;

  @override
  void dispose() {
    notesController.dispose();
    addressController.dispose();
    onlineLinkController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    // Primero seleccionar fecha
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF1A2942),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    // Luego seleccionar hora
    if (!mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF1A2942),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        selectedDate = pickedDate;
        selectedTime = pickedTime;
      });
    }
  }

  String _formatDateTime() {
    if (selectedDate == null || selectedTime == null) {
      return 'Seleccionar';
    }

    final day = selectedDate!.day.toString().padLeft(2, '0');
    final month = selectedDate!.month.toString().padLeft(2, '0');
    final year = selectedDate!.year;
    final hour = selectedTime!.hour.toString().padLeft(2, '0');
    final minute = selectedTime!.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute p.m.';
  }

  Future<void> _saveInterview() async {
    // Validaciones
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona fecha y hora'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (interviewType == 'ONSITE' && addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa la dirección'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];

      if (token == null || baseUrl == null) {
        throw Exception('No hay token de autenticación');
      }

      // Crear DateTime combinando fecha y hora
      final scheduledDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      // Preparar body según el API
      final Map<String, dynamic> body = {
        'interview_type': interviewType,
        'scheduled_at': scheduledDateTime.toIso8601String(),
      };

      // Agregar campos opcionales solo si tienen valor
      if (interviewType == 'ONSITE' &&
          addressController.text.trim().isNotEmpty) {
        body['onsite_address'] = addressController.text.trim();
      }

      if (interviewType == 'ONLINE' &&
          onlineLinkController.text.trim().isNotEmpty) {
        body['online_meeting_link'] = onlineLinkController.text.trim();
      }

      if (notesController.text.trim().isNotEmpty) {
        body['notes'] = notesController.text.trim();
      }

      print(
          '📤 Sending to API: POST /interviews/${widget.interviewId}/schedule');
      print('📦 Body: ${json.encode(body)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/interviews/${widget.interviewId}/schedule'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Entrevista configurada exitosamente!'),
              backgroundColor: Colors.green,
            ),
          );

          // Retornar true para indicar éxito
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1825),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2942),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.calendar_today,
                  color: Colors.blue, size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'Proceso de Entrevista',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'PENDIENTE AGENDAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con título
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1A2942),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2D3E57), width: 1),
                ),
              ),
              child: const Text(
                'Configuración de la sesión',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tipo de Entrevista
                  const Text(
                    'Tipo de Entrevista',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2942),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2D3E57)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: interviewType,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A2942),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.white),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              interviewType = newValue;
                              if (interviewType == 'ONLINE') {
                                addressController.clear();
                              }
                            });
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 'ONSITE',
                            child: Text('Presencial (On-site)'),
                          ),
                          DropdownMenuItem(
                            value: 'ONLINE',
                            child: Text('En línea (Online)'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Fecha y Hora
                  const Text(
                    'Fecha y Hora Propuesta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectDateTime,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2942),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF2D3E57)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: Colors.blue, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formatDateTime(),
                              style: TextStyle(
                                color:
                                    selectedDate != null && selectedTime != null
                                        ? Colors.white
                                        : Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Dirección (solo si es presencial)
                  if (interviewType == 'ONSITE') ...[
                    const Text(
                      'Dirección Completa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: addressController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Calle, Número, Ciudad...',
                        hintStyle:
                            TextStyle(color: Colors.grey[600], fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF1A2942),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xFF2D3E57)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xFF2D3E57)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Link de reunión (solo si es online)
                  if (interviewType == 'ONLINE') ...[
                    const Text(
                      'Enlace de Reunión (Opcional)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: onlineLinkController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'https://meet.google.com/...',
                        hintStyle:
                            TextStyle(color: Colors.grey[600], fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF1A2942),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xFF2D3E57)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xFF2D3E57)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notas
                  const Text(
                    'Notas Adicionales (Opcional)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Instrucciones de acceso, temas a tratar...',
                      hintStyle:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF1A2942),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFF2D3E57)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFF2D3E57)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: Colors.blue, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80), // Espacio para el botón
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2942),
          border: const Border(
            top: BorderSide(color: Color(0xFF2D3E57), width: 1),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveInterview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Guardar Configuración',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
