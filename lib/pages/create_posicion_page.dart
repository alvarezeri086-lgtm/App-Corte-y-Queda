import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'package:intl/intl.dart';
import '../utils/error_handler.dart';

class CreatePositionPage extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  CreatePositionPage({required this.eventId, required this.eventTitle});

  @override
  _CreatePositionPageState createState() => _CreatePositionPageState();
}

class _CreatePositionPageState extends State<CreatePositionPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;
  String _errorLoadingData = '';

  List<String> _selectedJobRoleIds = [];
  List<String> _selectedJobRoleNames = [];
  int _numberOfPositions = 1;
  double _payRate = 0.0;
  String _currency = 'MXN';
  List<String> _selectedTagIds = [];
  List<String> _selectedTagNames = [];
  List<Map<String, dynamic>> _selectedEquipment = [];
  int _confirmationWindowHours = 24;
  
  List<Map<String, dynamic>> _jobRoles = [];
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _equipmentList = [];

  final _roleNameController = TextEditingController();
  final _customSkillController = TextEditingController();
  final _customEquipmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingData = true;
      _errorLoadingData = '';
    });

    try {
      await Future.wait([
        _loadJobRoles(),
        _loadTags(),
        _loadEquipment(),
      ]);

      if (_jobRoles.isNotEmpty) {
        _roleNameController.text = 'Mezcla de roles';
      }
    } catch (e) {
      setState(() {
        _errorLoadingData = ApiErrorHandler.handleNetworkException(e);
      });
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _loadJobRoles() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/job-roles/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
        final data = jsonDecode(response.body);
        List<dynamic> loadedRoles = [];
        
        if (data is List) {
          loadedRoles = data;
        } else if (data is Map) {
          if (data['items'] is List) loadedRoles = data['items'];
          else if (data['data'] is List) loadedRoles = data['data'];
          else if (data['results'] is List) loadedRoles = data['results'];
        }

        setState(() {
          _jobRoles = loadedRoles.map((role) {
            return {
              'id': role['id'].toString(),
              'name': role['name']?.toString() ?? 'Sin nombre',
              'description': role['description']?.toString(),
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading job roles: $e');
    }
  }

  Future<void> _loadTags() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tags/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
        final data = jsonDecode(response.body);
        List<dynamic> loadedTags = [];
        
        if (data is List) {
          loadedTags = data;
        } else if (data is Map) {
          if (data['items'] is List) loadedTags = data['items'];
          else if (data['data'] is List) loadedTags = data['data'];
          else if (data['results'] is List) loadedTags = data['results'];
        }

        setState(() {
          _tags = loadedTags.map((tag) {
            return {
              'id': tag['id'].toString(),
              'name': tag['name']?.toString() ?? 'Sin nombre',
              'category': tag['category']?.toString(),
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading tags: $e');
    }
  }

  Future<void> _loadEquipment() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/equipment/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
        final data = jsonDecode(response.body);
        List<dynamic> loadedEquipment = [];
        
        if (data is List) {
          loadedEquipment = data;
        } else if (data is Map) {
          if (data['items'] is List) loadedEquipment = data['items'];
          else if (data['data'] is List) loadedEquipment = data['data'];
          else if (data['results'] is List) loadedEquipment = data['results'];
        }

        setState(() {
          _equipmentList = loadedEquipment.map((equipment) {
            return {
              'id': equipment['id'].toString(),
              'name': equipment['name']?.toString() ?? 'Sin nombre',
              'description': equipment['description']?.toString(),
              'category': equipment['category']?.toString(),
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading equipment: $e');
    }
  }

  Future<Map<String, dynamic>?> _createJobRole(String name) async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/job-roles/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name}),
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
        final newRole = jsonDecode(response.body);
        return {
          'id': newRole['id'].toString(),
          'name': newRole['name']?.toString() ?? name,
        };
      }
    } catch (e) {
      print('Error creating job role: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _createTag(String name) async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tags/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name}),
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
        final newTag = jsonDecode(response.body);
        return {
          'id': newTag['id'].toString(),
          'name': newTag['name']?.toString() ?? name,
        };
      }
    } catch (e) {
      print('Error creating tag: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _createEquipment(String name) async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/equipment/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name}),
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
        final newEquipment = jsonDecode(response.body);
        return {
          'id': newEquipment['id'].toString(),
          'name': newEquipment['name']?.toString() ?? name,
        };
      }
    } catch (e) {
      print('Error creating equipment: $e');
    }
    return null;
  }

  void _showRoleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF161B22),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seleccionar Roles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey[400]),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${_selectedJobRoleIds.length} seleccionados',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Search bar
                  TextField(
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar roles...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      fillColor: Color(0xFF0D1117),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      // Implement search if needed
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // Roles list
                  Expanded(
                    child: ListView.builder(
                      itemCount: _jobRoles.length,
                      itemBuilder: (context, index) {
                        final role = _jobRoles[index];
                        final isSelected = _selectedJobRoleIds.contains(role['id']);
                        
                        return CheckboxListTile(
                          title: Text(
                            role['name'],
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: role['description'] != null
                              ? Text(
                                  role['description'],
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          value: isSelected,
                          activeColor: Colors.purple[600],
                          checkColor: Colors.white,
                          onChanged: (value) {
                            setModalState(() {
                              if (value == true) {
                                if (!_selectedJobRoleIds.contains(role['id'])) {
                                  _selectedJobRoleIds.add(role['id']);
                                  _selectedJobRoleNames.add(role['name']);
                                }
                              } else {
                                _selectedJobRoleIds.remove(role['id']);
                                _selectedJobRoleNames.remove(role['name']);
                              }
                            });
                            setState(() {}); // Update parent widget
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Done button
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[600],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Confirmar (${_selectedJobRoleIds.length})',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSkillSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF161B22),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seleccionar Habilidades',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey[400]),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${_selectedTagIds.length} seleccionadas',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  
                  // Add custom skill
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customSkillController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Agregar nueva habilidad...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            fillColor: Color(0xFF0D1117),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final skillName = _customSkillController.text.trim();
                          if (skillName.isEmpty) return;

                          final existingTag = _tags.firstWhere(
                            (tag) => tag['name'].toLowerCase() == skillName.toLowerCase(),
                            orElse: () => {},
                          );

                          if (existingTag.isNotEmpty) {
                            if (!_selectedTagIds.contains(existingTag['id'])) {
                              setModalState(() {
                                _selectedTagIds.add(existingTag['id']);
                                _selectedTagNames.add(existingTag['name']);
                              });
                              setState(() {});
                            }
                          } else {
                            final newTag = await _createTag(skillName);
                            if (newTag != null) {
                              setModalState(() {
                                _tags.add(newTag);
                                _selectedTagIds.add(newTag['id']);
                                _selectedTagNames.add(newTag['name']);
                              });
                              setState(() {});
                            }
                          }
                          _customSkillController.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        child: Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: _tags.length,
                      itemBuilder: (context, index) {
                        final tag = _tags[index];
                        final isSelected = _selectedTagIds.contains(tag['id']);
                        
                        return CheckboxListTile(
                          title: Text(tag['name'], style: TextStyle(color: Colors.white)),
                          value: isSelected,
                          activeColor: Colors.green[600],
                          checkColor: Colors.white,
                          onChanged: (value) {
                            setModalState(() {
                              if (value == true) {
                                if (!_selectedTagIds.contains(tag['id'])) {
                                  _selectedTagIds.add(tag['id']);
                                  _selectedTagNames.add(tag['name']);
                                }
                              } else {
                                _selectedTagIds.remove(tag['id']);
                                _selectedTagNames.remove(tag['name']);
                              }
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Confirmar (${_selectedTagIds.length})',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEquipmentSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF161B22),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seleccionar Equipamiento',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey[400]),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${_selectedEquipment.length} seleccionados',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  
                  // Add custom equipment
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customEquipmentController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Agregar nuevo equipo...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            fillColor: Color(0xFF0D1117),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final equipmentName = _customEquipmentController.text.trim();
                          if (equipmentName.isEmpty) return;

                          final existingEquipment = _equipmentList.firstWhere(
                            (equipment) => equipment['name'].toLowerCase() == equipmentName.toLowerCase(),
                            orElse: () => {},
                          );

                          if (existingEquipment.isNotEmpty) {
                            if (!_selectedEquipment.any((e) => e['id'] == existingEquipment['id'])) {
                              setModalState(() {
                                _selectedEquipment.add({
                                  'id': existingEquipment['id'],
                                  'name': existingEquipment['name'],
                                  'required': false,
                                  'main_quantity': 1,
                                  'is_experienced': false,
                                  'experience_years': 0,
                                });
                              });
                              setState(() {});
                            }
                          } else {
                            final newEquipment = await _createEquipment(equipmentName);
                            if (newEquipment != null) {
                              setModalState(() {
                                _equipmentList.add(newEquipment);
                                _selectedEquipment.add({
                                  'id': newEquipment['id'],
                                  'name': newEquipment['name'],
                                  'required': false,
                                  'main_quantity': 1,
                                  'is_experienced': false,
                                  'experience_years': 0,
                                });
                              });
                              setState(() {});
                            }
                          }
                          _customEquipmentController.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        child: Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: _equipmentList.length,
                      itemBuilder: (context, index) {
                        final equipment = _equipmentList[index];
                        final isSelected = _selectedEquipment.any((e) => e['id'] == equipment['id']);
                        
                        return CheckboxListTile(
                          title: Text(equipment['name'], style: TextStyle(color: Colors.white)),
                          subtitle: equipment['description'] != null
                              ? Text(equipment['description'], style: TextStyle(color: Colors.grey[500], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          value: isSelected,
                          activeColor: Colors.blue[600],
                          checkColor: Colors.white,
                          onChanged: (value) {
                            setModalState(() {
                              if (value == true) {
                                if (!_selectedEquipment.any((e) => e['id'] == equipment['id'])) {
                                  _selectedEquipment.add({
                                    'id': equipment['id'],
                                    'name': equipment['name'],
                                    'required': false,
                                    'main_quantity': 1,
                                    'is_experienced': false,
                                    'experience_years': 0,
                                  });
                                }
                              } else {
                                _selectedEquipment.removeWhere((e) => e['id'] == equipment['id']);
                              }
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        'Confirmar (${_selectedEquipment.length})',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _removeRole(String roleId, String roleName) {
    setState(() {
      _selectedJobRoleIds.remove(roleId);
      _selectedJobRoleNames.remove(roleName);
    });
  }

  void _removeSkill(String tagId, String tagName) {
    setState(() {
      _selectedTagIds.remove(tagId);
      _selectedTagNames.remove(tagName);
    });
  }

  void _updateEquipmentRequirement(int index, bool? requiredValue) {
    if (requiredValue != null) {
      setState(() {
        _selectedEquipment[index]['required'] = requiredValue;
      });
    }
  }

  void _updateEquipmentExperience(int index, bool? experiencedValue) {
    if (experiencedValue != null) {
      setState(() {
        _selectedEquipment[index]['is_experienced'] = experiencedValue;
      });
    }
  }

  void _updateExperienceYears(int index, String value) {
    final years = int.tryParse(value) ?? 0;
    setState(() {
      _selectedEquipment[index]['experience_years'] = years;
    });
  }

  void _removeEquipment(int index) {
    setState(() {
      _selectedEquipment.removeAt(index);
    });
  }

  Future<void> _createPosition() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedJobRoleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecciona al menos un rol profesional')),
      );
      return;
    }

    if (_payRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La cantidad de pago debe ser mayor a 0')),
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
      final Map<String, dynamic> requestBody = {
        "event_id": widget.eventId,
        "role_name": _roleNameController.text.trim(),
        "quantity_required": _numberOfPositions,
        "pay_rate": _payRate,
        "currency": _currency,
        "job_role_ids": _selectedJobRoleIds,
        "tag_ids": _selectedTagIds,
        "required_equipment": _selectedEquipment.map((equipment) {
          return {
            "equipment_item_id": equipment['id'],
            "required": equipment['required'],
            "main_quantity": equipment['main_quantity'],
            "is_experienced": equipment['is_experienced'],
            "experience_years": equipment['experience_years'],
          };
        }).toList(),
        "confirmation_window_minutes": _confirmationWindowHours * 60,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/positions/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Posición creada exitosamente!'),
            backgroundColor: Colors.green[600],
            duration: Duration(seconds: 3),
          ),
        );

        await Future.delayed(Duration(milliseconds: 2500));
        
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.friendlyErrorMessage),
            backgroundColor: Colors.red[600],
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorHandler.handleNetworkException(e)),
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

  Widget _buildNumberInput(String label, int value, Function(int) onChanged, {int min = 1, int max = 100}) {
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
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Color(0xFF30363D), width: 1),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove, color: Colors.grey[400], size: 20),
                onPressed: value > min ? () => onChanged(value - 1) : null,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              Expanded(
                child: Text(
                  value.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, color: Colors.grey[400], size: 20),
                onPressed: value < max ? () => onChanged(value + 1) : null,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPayRateInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAGO POR LLAMADO',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _payRate > 0 ? _payRate.toString() : '',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '150',
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
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: Colors.grey[400]),
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) {
                    setState(() {
                      _payRate = parsed;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El pago es requerido';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed <= 0) {
                    return 'Ingresa un monto válido';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 12),
            Container(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Moneda',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                        value: _currency,
                        isExpanded: true,
                        dropdownColor: Color(0xFF161B22),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                        items: ['USD', 'MXN', 'EUR'].map((currency) {
                          return DropdownMenuItem<String>(
                            value: currency,
                            child: Text(currency),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _currency = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRolesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORÍA DEL PUESTO',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        
        // Button to open selector
        InkWell(
          onTap: _showRoleSelector,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF30363D), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedJobRoleIds.isEmpty 
                      ? 'Seleccionar roles...' 
                      : '${_selectedJobRoleIds.length} roles seleccionados',
                  style: TextStyle(
                    color: _selectedJobRoleIds.isEmpty ? Colors.grey[600] : Colors.white,
                    fontSize: 14,
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
              ],
            ),
          ),
        ),
        
        // Selected roles chips
        if (_selectedJobRoleNames.isNotEmpty) ...[
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedJobRoleNames.asMap().entries.map((entry) {
              final index = entry.key;
              final roleName = entry.value;
              final roleId = _selectedJobRoleIds[index];
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple[900]!.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple[400]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      roleName,
                      style: TextStyle(color: Colors.purple[200], fontSize: 13),
                    ),
                    SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeRole(roleId, roleName),
                      child: Icon(Icons.close, color: Colors.purple[200], size: 16),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSkillsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HABILIDADES REQUERIDAS',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        
        InkWell(
          onTap: _showSkillSelector,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF30363D), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedTagIds.isEmpty 
                      ? 'Seleccionar habilidades...' 
                      : '${_selectedTagIds.length} habilidades seleccionadas',
                  style: TextStyle(
                    color: _selectedTagIds.isEmpty ? Colors.grey[600] : Colors.white,
                    fontSize: 14,
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
              ],
            ),
          ),
        ),
        
        if (_selectedTagNames.isNotEmpty) ...[
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTagNames.asMap().entries.map((entry) {
              final index = entry.key;
              final tagName = entry.value;
              final tagId = _selectedTagIds[index];
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[900]!.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green[400]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tagName,
                      style: TextStyle(color: Colors.green[200], fontSize: 13),
                    ),
                    SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeSkill(tagId, tagName),
                      child: Icon(Icons.close, color: Colors.green[200], size: 16),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildEquipmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EQUIPAMIENTO REQUERIDO',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        
        InkWell(
          onTap: _showEquipmentSelector,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF30363D), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedEquipment.isEmpty 
                      ? 'Seleccionar equipamiento...' 
                      : '${_selectedEquipment.length} equipos seleccionados',
                  style: TextStyle(
                    color: _selectedEquipment.isEmpty ? Colors.grey[600] : Colors.white,
                    fontSize: 14,
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
              ],
            ),
          ),
        ),
        
        if (_selectedEquipment.isNotEmpty) ...[
          SizedBox(height: 12),
          ..._selectedEquipment.asMap().entries.map((entry) {
            final index = entry.key;
            final equipment = entry.value;
            return Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[700]!, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          equipment['name'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey[400], size: 18),
                        onPressed: () => _removeEquipment(index),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: Checkbox(
                                value: equipment['required'],
                                onChanged: (value) => _updateEquipmentRequirement(index, value),
                                activeColor: Colors.blue[600],
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Debe tenerlo',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: Checkbox(
                                value: equipment['is_experienced'],
                                onChanged: (value) => _updateEquipmentExperience(index, value),
                                activeColor: Colors.blue[600],
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Con experiencia',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (equipment['is_experienced']) ...[
                    SizedBox(height: 8),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        initialValue: equipment['experience_years'].toString(),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Años de experiencia',
                          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
                          fillColor: Color(0xFF0D1117),
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[600]!, width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onChanged: (value) => _updateExperienceYears(index, value),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildConfirmationWindow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: true,
              onChanged: null,
              activeColor: Colors.blue[600],
              checkColor: Colors.white,
            ),
            SizedBox(width: 8),
            Text(
              'VENTANA DE CONFIRMACIÓN',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'El personal debe confirmar disponibilidad dentro de este período después de publicar la orden.',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
        SizedBox(height: 12),
        _buildNumberInput(
          'Horas',
          _confirmationWindowHours,
          (value) => setState(() => _confirmationWindowHours = value),
          min: 1,
          max: 168,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: Color(0xFF0D1117),
        appBar: AppBar(
          backgroundColor: Color(0xFF161B22),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Activar rol',
            style: TextStyle(color: Colors.white),
          ),
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue[600]),
        ),
      );
    }

    if (_errorLoadingData.isNotEmpty) {
      return Scaffold(
        backgroundColor: Color(0xFF0D1117),
        appBar: AppBar(
          backgroundColor: Color(0xFF161B22),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Activar rol',
            style: TextStyle(color: Colors.white),
          ),
          elevation: 0,
        ),
        body: ApiErrorHandler.buildErrorWidget(
          message: _errorLoadingData,
          onRetry: _loadInitialData,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Color(0xFF161B22),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Activar rol',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
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
                        'Agregando rol para:',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.eventTitle,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOMBRE DEL PUESTO',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _roleNameController,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ej: Gaffer',
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
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El nombre del rol es requerido';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      Text(
                        'ASIGNACIÓN Y ROL',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 20),

                      _buildRolesSection(),
                      SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberInput(
                              'NÚMERO DE VACANTES',
                              _numberOfPositions,
                              (value) => setState(() => _numberOfPositions = value),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Container(),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      _buildPayRateInput(),
                      SizedBox(height: 20),

                      Divider(color: Color(0xFF30363D)),
                      SizedBox(height: 20),

                      Text(
                        'REQUISITOS Y EQUIPAMIENTO',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 20),

                      _buildSkillsSection(),
                      SizedBox(height: 20),

                      _buildEquipmentSection(),
                      SizedBox(height: 20),

                      Divider(color: Color(0xFF30363D)),
                      SizedBox(height: 20),

                      Text(
                        'HORARIO Y LOGÍSTICA',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 20),

                      _buildConfirmationWindow(),
                    ],
                  ),
                ),

                SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[600]!, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createPosition,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Activar rol',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
    _roleNameController.dispose();
    _customSkillController.dispose();
    _customEquipmentController.dispose();
    super.dispose();
  }
}