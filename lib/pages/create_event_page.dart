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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor selecciona una fecha de inicio')),
      );
      return;
    }

    if (_endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor selecciona una fecha de fin')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La fecha de fin debe ser posterior a la fecha de inicio')),
      );
      return;
    }

    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: No autenticado o API no configurada')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> data = {
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "start_date": DateFormat('yyyy-MM-dd').format(_startDate!),
        "end_date": DateFormat('yyyy-MM-dd').format(_endDate!),
        "location": _locationController.text.trim(),
        "requires_documents": _requiresDocuments,
        "requires_interview": _requiresInterview,
        "payment_terms_days": int.tryParse(_paymentTermsController.text.trim()) ?? 0,
      };

      print(' CREANDO EVENTO ...');
      print('Datos: $data');

      final response = await http.post(
        Uri.parse('$baseUrl/events/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(Duration(seconds: 30));

      print('Respuesta: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Evento creado exitosamente!'),
            backgroundColor: Colors.green[600],
            duration: Duration(seconds: 3),
          ),
        );

        if (widget.onEventCreated != null) {
          widget.onEventCreated!();
        }

        await Future.delayed(Duration(milliseconds: 1500));
        
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        String errorMessage = 'Error al crear evento: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['detail'] != null) {
            errorMessage = errorData['detail'].toString();
          } else if (errorData is Map) {
            final errors = <String>[];
            errorData.forEach((key, value) {
              if (value is List) {
                errors.add('$key: ${value.join(', ')}');
              } else {
                errors.add('$key: $value');
              }
            });
            if (errors.isNotEmpty) {
              errorMessage = errors.join('\n');
            }
          }
        } catch (e) {
          print('Error parsing response: $e');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red[600],
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El servidor tardó demasiado en responder'),
          backgroundColor: Colors.red[600],
        ),
      );
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: ${e.toString()}'),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          'Nuevo Evento',
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
                          'Nueva Orden de Evento',
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
                          'Nombre del Proyecto',
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
                              return 'El nombre del proyecto es requerido';
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

                        // Payment Terms
                        Text(
                          'Términos de Pago',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _paymentTermsController,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 14 : 14,
                          ),
                          decoration: InputDecoration(
                            hintText: '1 Día',
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
                              return 'Los términos de pago son requeridos';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isMobile ? 16 : 20),

                        // Validations Section
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
                          'Documentos',
                          'Auditoría requerida',
                          _requiresDocuments,
                          (value) => setState(() => _requiresDocuments = value ?? false),
                        ),
                        SizedBox(height: isMobile ? 8 : 12),
                        _buildCheckbox(
                          'Entrevista',
                          'Sincronización requerida',
                          _requiresInterview,
                          (value) => setState(() => _requiresInterview = value ?? false),
                        ),
                      ],
                    ),
                  ),

                  // Action Button
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
                                'Activar Orden',
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