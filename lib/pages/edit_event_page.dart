import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class EditEventPage extends StatefulWidget {
  final String eventId;

  EditEventPage({required this.eventId});

  @override
  _EditEventPageState createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  bool _requiresDocuments = false;
  bool _requiresInterview = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String _selectedStatus = 'ACTIVE';

  final List<Map<String, String>> _statusOptions = [
    {'value': 'ACTIVE', 'label': 'ACTIVO'},
    {'value': 'INACTIVE', 'label': 'INACTIVO'},
    {'value': 'COMPLETED', 'label': 'COMPLETADO'},
    {'value': 'CANCELLED', 'label': 'CANCELADO'},
  ];

  @override
  void initState() {
    super.initState();
    _loadEventData();
  }

  Future<void> _loadEventData() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events/${widget.eventId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _titleController.text = data['title'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _locationController.text = data['location'] ?? '';
          _paymentTermsController.text = data['payment_terms_days']?.toString() ?? '';
          _requiresDocuments = data['requires_documents'] ?? false;
          _requiresInterview = data['requires_interview'] ?? false;
          _selectedStatus = data['status'] ?? 'ACTIVE';
          
          if (data['start_date'] != null) {
            _startDate = DateTime.parse(data['start_date']);
          }
          if (data['end_date'] != null) {
            _endDate = DateTime.parse(data['end_date']);
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
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
      initialDate: _endDate ?? initialDate,
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

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor selecciona las fechas')),
      );
      return;
    }

    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: No autenticado')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
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
        "payment_terms_days": _paymentTermsController.text.trim(),
        "status": _selectedStatus,
      };

      print('=== ACTUALIZANDO LLAMADO ===');
      print('Datos: $data');

      final response = await http.patch(
        Uri.parse('$baseUrl/events/${widget.eventId}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(Duration(seconds: 30));

      print('Respuesta: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Llamado actualizado exitosamente!'),
            backgroundColor: Colors.green[600],
          ),
        );

        await Future.delayed(Duration(milliseconds: 1000));
        
        if (mounted) {
          Navigator.pop(context, true); // Devolver true para indicar que se actualizó
        }
      } else {
        String errorMessage = 'Error al actualizar llamado: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['detail'] != null) {
            errorMessage = errorData['detail'].toString();
          }
        } catch (e) {}
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión'),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
                Icon(Icons.calendar_today_outlined, color: Colors.grey[500], size: 18),
                SizedBox(width: 12),
                Text(
                  date != null
                      ? DateFormat('dd/MM/yyyy').format(date)
                      : 'Seleccionar fecha',
                  style: TextStyle(
                    color: date != null ? Colors.white : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Spacer(),
                Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
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
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final isSmallMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Color(0xFF161B22),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Editar Llamado', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blue[600]))
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        decoration: BoxDecoration(
                          color: Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFF30363D), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nombre del Proyecto',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: _titleController,
                              style: TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Llamado cinematográfico',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                fillColor: Color(0xFF0D1117),
                                filled: true,
                                contentPadding: EdgeInsets.all(12),
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
                              validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                            ),
                            SizedBox(height: 20),

                            Text('Ubicación', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: _locationController,
                              style: TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Ciudad, Estado',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                fillColor: Color(0xFF0D1117),
                                filled: true,
                                contentPadding: EdgeInsets.all(12),
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
                              validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                            ),
                            SizedBox(height: 20),

                            if (isSmallMobile)
                              Column(
                                children: [
                                  _buildDateField('Fecha de Inicio', _startDate, () => _selectStartDate(context)),
                                  SizedBox(height: 16),
                                  _buildDateField('Fecha de Fin', _endDate, () => _selectEndDate(context)),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(child: _buildDateField('Fecha de Inicio', _startDate, () => _selectStartDate(context))),
                                  SizedBox(width: 16),
                                  Expanded(child: _buildDateField('Fecha de Fin', _endDate, () => _selectEndDate(context))),
                                ],
                              ),
                            
                            SizedBox(height: 20),

                            Text('Descripción', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 4,
                              style: TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Descripción del llamado...',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                fillColor: Color(0xFF0D1117),
                                filled: true,
                                contentPadding: EdgeInsets.all(12),
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
                              validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                            ),
                            SizedBox(height: 20),

                            if (isSmallMobile)
                              Column(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Dias de Pago', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 8),
                                      TextFormField(
                                        controller: _paymentTermsController,
                                        style: TextStyle(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: '1 Día',
                                          hintStyle: TextStyle(color: Colors.grey[600]),
                                          fillColor: Color(0xFF0D1117),
                                          filled: true,
                                          contentPadding: EdgeInsets.all(12),
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
                                        validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Estado', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF0D1117),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Color(0xFF30363D), width: 1),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _selectedStatus,
                                            dropdownColor: Color(0xFF161B22),
                                            style: TextStyle(color: Colors.white),
                                            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                                            items: _statusOptions.map((status) {
                                              return DropdownMenuItem<String>(
                                                value: status['value'],
                                                child: Text(status['label']!),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedStatus = value!;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Dias de Pago', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                                        SizedBox(height: 8),
                                        TextFormField(
                                          controller: _paymentTermsController,
                                          style: TextStyle(color: Colors.white, fontSize: 14),
                                          decoration: InputDecoration(
                                            hintText: '1 Día',
                                            hintStyle: TextStyle(color: Colors.grey[600]),
                                            fillColor: Color(0xFF0D1117),
                                            filled: true,
                                            contentPadding: EdgeInsets.all(12),
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
                                          validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Estado', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                                        SizedBox(height: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF0D1117),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Color(0xFF30363D), width: 1),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              value: _selectedStatus,
                                              dropdownColor: Color(0xFF161B22),
                                              style: TextStyle(color: Colors.white),
                                              icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                                              items: _statusOptions.map((status) {
                                                return DropdownMenuItem<String>(
                                                  value: status['value'],
                                                  child: Text(status['label']!),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedStatus = value!;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            SizedBox(height: 20),

                            Text('VALIDACIONES', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(height: 12),
                            _buildCheckbox('Documentos', 'Auditoría requerida', _requiresDocuments,
                                (value) => setState(() => _requiresDocuments = value ?? false)),
                            SizedBox(height: 12),
                            _buildCheckbox('Entrevista', 'Sincronización requerida', _requiresInterview,
                                (value) => setState(() => _requiresInterview = value ?? false)),
                          ],
                        ),
                      ),

                      SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey[700]!),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _updateEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: _isSaving
                                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                  : Text('Guardar Cambios', style: TextStyle(color: Colors.white, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 40),
                    ],
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