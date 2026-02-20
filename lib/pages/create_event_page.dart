import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class CreateEventPage extends StatefulWidget {
  final VoidCallback? onEventCreated;

  CreateEventPage({this.onEventCreated});

  @override
  _CreateEventPageState createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  bool _requiresDocuments = false;
  bool _requiresInterview = false;
  bool _isLoading = false;

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue[600]!,
              onPrimary: Colors.white,
              surface: Color(0xFF161B22),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Color(0xFF161B22),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final initialDate = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: initialDate,
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue[600]!,
              onPrimary: Colors.white,
              surface: Color(0xFF161B22),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Color(0xFF161B22),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null) {
      _showErrorSnackBar('Por favor selecciona una fecha de inicio');
      return;
    }

    if (_endDate == null) {
      _showErrorSnackBar('Por favor selecciona una fecha de fin');
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      _showErrorSnackBar('La fecha de fin debe ser posterior a la fecha de inicio');
      return;
    }

    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) {
      _showErrorSnackBar('Error de autenticación. Por favor inicia sesión nuevamente');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Enviar payment_terms_days como string
      final Map<String, dynamic> data = {
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "start_date": DateFormat('yyyy-MM-dd').format(_startDate!),
        "end_date": DateFormat('yyyy-MM-dd').format(_endDate!),
        "location": _locationController.text.trim(),
        "requires_documents": _requiresDocuments,
        "requires_interview": _requiresInterview,
        "payment_terms_days": _paymentTermsController.text.trim().isEmpty 
            ? "1" 
            : _paymentTermsController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/events/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSuccessSnackBar('¡Llamado creado exitosamente!');

        if (widget.onEventCreated != null) {
          widget.onEventCreated!();
        }

        await Future.delayed(Duration(milliseconds: 1500));
        
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        // Manejo de errores mejorado
        String errorMessage = 'No se pudo crear el llamado';
        
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('detail')) {
            errorMessage = errorData['detail'].toString();
          } else if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'].toString();
          }
        } catch (e) {
          // Error al parsear respuesta
        }

        _showErrorSnackBar(errorMessage);
      }
    } on TimeoutException catch (_) {
      _showErrorSnackBar('La solicitud tardó demasiado. Verifica tu conexión');
    } catch (e) {
      print('Error: $e');
      _showErrorSnackBar('No se pudo crear el llamado. Intenta nuevamente');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Color(0xFF30363D), width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.grey[500],
                  size: 18,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('dd/MM/yyyy').format(date)
                        : 'Seleccionar fecha',
                    style: TextStyle(
                      color: date != null ? Colors.white : Colors.grey[600],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox(String label, String subtitle, bool value, void Function(bool?) onChanged) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue[600],
          checkColor: Colors.white,
          fillColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue[600]!;
            }
            return Colors.grey[700]!;
          }),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Color(0xFF161B22),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nuevo Llamado',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : isTablet ? 24 : 32,
              vertical: isMobile ? 16 : 24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SISTEMA OPERATIVO DE COORDINACIÓN OPERACIONAL',
                          style: TextStyle(
                            color: Colors.blue[400],
                            fontSize: isMobile ? 10 : 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Nueva Orden de Llamado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'INFORMACIÓN GENERAL',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
                    decoration: BoxDecoration(
                      color: Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF30363D), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nombre del llamado',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _titleController,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 14 : 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Evento cinematográfico',
                            hintStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isMobile ? 14 : 14,
                            ),
                            fillColor: Color(0xFF0D1117),
                            filled: true,
                            contentPadding: EdgeInsets.all(isMobile ? 12 : 12),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue[600]!, width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El nombre del llamado es requerido';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isMobile ? 16 : 20),
                        Text(
                          'Ubicación',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _locationController,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 14 : 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'San Nicolas Galeana, Zacatepec, Morelos, 62784, México',
                            hintStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isMobile ? 14 : 14,
                            ),
                            fillColor: Color(0xFF0D1117),
                            filled: true,
                            contentPadding: EdgeInsets.all(isMobile ? 12 : 12),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue[600]!, width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'La ubicación es requerida';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isMobile ? 16 : 20),
                        if (isMobile)
                          Column(
                            children: [
                              _buildDateField(
                                'Fecha de Inicio',
                                _startDate,
                                () => _selectStartDate(context),
                              ),
                              SizedBox(height: 16),
                              _buildDateField(
                                'Fecha de Fin',
                                _endDate,
                                () => _selectEndDate(context),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  'Fecha de Inicio',
                                  _startDate,
                                  () => _selectStartDate(context),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildDateField(
                                  'Fecha de Fin',
                                  _endDate,
                                  () => _selectEndDate(context),
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: isMobile ? 16 : 20),

                        Text(
                          'Descripción',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: isMobile ? 3 : 4,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 14 : 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Es un evento cinematográfico...',
                            hintStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isMobile ? 14 : 14,
                            ),
                            fillColor: Color(0xFF0D1117),
                            filled: true,
                            contentPadding: EdgeInsets.all(isMobile ? 12 : 12),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue[600]!, width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'La descripción es requerida';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isMobile ? 16 : 20),

                        Text(
                          'Días de Pago',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _paymentTermsController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 14 : 14,
                          ),
                          decoration: InputDecoration(
                            hintText: '1',
                            hintStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isMobile ? 14 : 14,
                            ),
                            fillColor: Color(0xFF0D1117),
                            filled: true,
                            contentPadding: EdgeInsets.all(isMobile ? 12 : 12),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue[600]!, width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Los días de pago son requeridos';
                            }
                            final number = int.tryParse(value.trim());
                            if (number == null || number < 1) {
                              return 'Debe ser un número válido mayor a 0';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isMobile ? 16 : 20),

                        Text(
                          'VALIDACIONES',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isMobile ? 8 : 12),
                        _buildCheckbox(
                          'Documentacion requerida',
                          'El rol requiere documentación vigente',
                          _requiresDocuments,
                          (value) => setState(() => _requiresDocuments = value ?? false),
                        ),
                        SizedBox(height: isMobile ? 8 : 12),
                        _buildCheckbox(
                          'Entrevista previa',
                          'Se requiere validacion previa ',
                          _requiresInterview,
                          (value) => setState(() => _requiresInterview = value ?? false),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isMobile ? 24 : 32),
                  Center(
                    child: SizedBox(
                      width: isMobile ? double.infinity : null,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 20 : 40,
                            vertical: isMobile ? 14 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                          minimumSize: isMobile ? Size(double.infinity, 48) : Size(180, 52),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: isMobile ? 20 : 20,
                                width: isMobile ? 20 : 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Activar Llamado',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 24 : 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _paymentTermsController.dispose();
    super.dispose();
  }
}