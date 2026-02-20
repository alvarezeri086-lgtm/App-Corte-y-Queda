import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'documentos_freelancer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? freelancerProfile;
  List<dynamic>? jobRolesData;
  List<dynamic>? tagsData;
  List<dynamic>? equipmentData;

  // Documentos
  List<dynamic> userDocuments = [];
  bool isLoadingDocuments = false;

  bool isLoading = true;
  String errorMessage = '';
  String? profileImageUrl;

  // ✅ NUEVO: Códigos y nombres de documentos requeridos
  static const List<String> _requiredDocCodes = [
    'ACTA_NACIMIENTO',
    'COMPROBANTE_DOMICILIO',
    'CURP',
    'CONSTANCIA_FISCAL',
    'ESTADO_CUENTA',
    'INE',
  ];

  static const Map<String, String> _docCodeNames = {
    'ACTA_NACIMIENTO': 'Acta de Nacimiento',
    'COMPROBANTE_DOMICILIO': 'Comprobante de domicilio',
    'CURP': 'CURP',
    'CONSTANCIA_FISCAL': 'Constancia Fiscal',
    'ESTADO_CUENTA': 'Estado de Cuenta',
    'INE': 'INE',
  };

  @override
  void initState() {
    super.initState();
    _fetchAllUserData();
  }

  // ✅ NUEVO: Calcula documentos faltantes para mostrar alerta en perfil
  List<String> _getProfileMissingDocs() {
    final List<String> missing = [];
    for (final code in _requiredDocCodes) {
      final found = userDocuments.any((doc) => doc['document_type']?['code'] == code);
      if (!found) missing.add(_docCodeNames[code] ?? code);
    }
    return missing;
  }

  Future<void> _fetchAllUserData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];

      if (token == null || baseUrl == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'No autenticado';
        });
        return;
      }

      final userResponse = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (userResponse.statusCode == 200) {
        final userJson = json.decode(userResponse.body);

        setState(() {
          userData = userJson;
          freelancerProfile = userJson['freelancer_profile'];
          if (userJson['photo_url'] != null) {
            profileImageUrl = userJson['photo_url'];
          }
        });

        if (userJson['freelancer_profile'] != null) {
          final rolesResponse = await http.get(
            Uri.parse('$baseUrl/freelancer/profile/get-roles'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );

          if (rolesResponse.statusCode == 200) {
            final rolesJson = json.decode(rolesResponse.body);
            setState(() {
              jobRolesData = rolesJson['job_roles'] ?? [];
              tagsData = rolesJson['tags'] ?? [];
              equipmentData = _extractEquipmentData(rolesJson);
            });
          }

          // Cargar documentos del freelancer
          await _fetchDocuments(token, baseUrl);
        }

        setState(() => isLoading = false);
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Error al cargar datos';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error de conexión';
      });
    }
  }

  // GET /documents/freelancer/me
  Future<void> _fetchDocuments(String token, String baseUrl) async {
    setState(() => isLoadingDocuments = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents/freelancer/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          userDocuments = data is List ? data : [];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => isLoadingDocuments = false);
  }

  List<dynamic> _extractEquipmentData(Map<String, dynamic> response) {
    final equipmentList = <Map<String, dynamic>>[];
    if (response.containsKey('equipment') && response['equipment'] is List) {
      for (var item in response['equipment']) {
        equipmentList.add({
          'equipment_item_id': item['equipment_item_id'] ?? item['id'],
          'name': item['name'] ?? 'Sin nombre',
          'quantity': item['quantity'] ?? 0,
          'notes': item['notes'] ?? '',
          'has_requirement': item['has_requirement'] ?? false,
          'is_experienced': item['is_experienced'] ?? false,
          'experience_years': item['experience_years'] ?? 0,
        });
      }
    }
    return equipmentList;
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF161B22),
        title: Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de que quieres cerrar sesión?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cerrar sesión', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storage = FlutterSecureStorage();
      await storage.deleteAll();
      await authProvider.logout();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _editGeneralInfo() {
    _showEditBasicInfoSheet();
  }

  void _editProfessionalDetails() {
    _showEditProfessionalSheet();
  }

  // Navegar a pantalla de documentos
  void _goToDocuments() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FreelancerDocumentUploadScreen(
          existingDocuments: userDocuments,
        ),
      ),
    );
    if (result == true) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];
      if (token != null && baseUrl != null) {
        await _fetchDocuments(token, baseUrl);
      }
    }
  }

  void _showEditBasicInfoSheet() {
    final bioCtrl =
        TextEditingController(text: freelancerProfile?['bio'] ?? '');
    final rfcCtrl =
        TextEditingController(text: freelancerProfile?['rfc'] ?? '');
    final locationCtrl =
        TextEditingController(text: freelancerProfile?['location'] ?? '');
    final yearsCtrl = TextEditingController(
        text: (freelancerProfile?['years_experience'] ?? 0).toString());
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFF30363D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[900]!.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.person_outline,
                          color: Colors.blue[400], size: 18),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Editar información',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text('PUT /freelancer/profile',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[500]),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(color: Color(0xFF30363D), height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sheetInputField(
                        controller: bioCtrl,
                        label: 'BIOGRAFÍA',
                        hint: 'Cuéntanos sobre ti y tu experiencia...',
                        maxLines: 4,
                        icon: Icons.notes_outlined,
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _sheetInputField(
                              controller: yearsCtrl,
                              label: 'AÑOS DE EXPERIENCIA',
                              hint: '0',
                              keyboardType: TextInputType.number,
                              icon: Icons.work_outline,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _sheetInputField(
                              controller: rfcCtrl,
                              label: 'RFC',
                              hint: 'XXXX000000XX0',
                              icon: Icons.verified_outlined,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _sheetInputField(
                        controller: locationCtrl,
                        label: 'UBICACIÓN',
                        hint: 'Ciudad, Estado',
                        icon: Icons.location_on_outlined,
                      ),
                      SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  setSheetState(() => saving = true);
                                  final ok = await _saveBasicInfo(
                                    bio: bioCtrl.text.trim(),
                                    years: int.tryParse(yearsCtrl.text) ?? 0,
                                    location: locationCtrl.text.trim(),
                                    rfc: rfcCtrl.text.trim(),
                                  );
                                  setSheetState(() => saving = false);
                                  if (ok && ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _fetchAllUserData();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            disabledBackgroundColor: Colors.blue[900],
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: saving
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2)),
                                    SizedBox(width: 10),
                                    Text('Guardando...',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15)),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_outlined,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Guardar cambios',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600)),
                                  ],
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
      ),
    );
  }

  Future<bool> _saveBasicInfo({
    required String bio,
    required int years,
    required String location,
    required String rfc,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];
      if (token == null || baseUrl == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/freelancer/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'bio': bio,
          'years_experience': years,
          'location': location,
          'rfc': rfc,
        }),
      );

      if (response.statusCode == 200) {
        _showSuccess('Información actualizada correctamente');
        return true;
      } else {
        _showError('No se pudieron guardar los cambios. Intenta nuevamente.');
      }
      return false;
    } catch (e) {
      _showError('Ocurrió un error al guardar. Verifica tu conexión.');
      return false;
    }
  }

  void _showEditProfessionalSheet() {
    List<Map<String, dynamic>> roles = (jobRolesData ?? [])
        .map<Map<String, dynamic>>((r) => {
              'job_role_id': r['job_role_id'] ?? r['id'],
              'name': r['name'] ?? '',
              'years': r['years'] ?? 0,
              'level': r['level'] ?? 0,
            })
        .toList();

    List<String> selectedTagIds = (tagsData ?? [])
        .map<String>((t) => (t['id'] ?? t['tag_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    List<Map<String, dynamic>> equipment = (equipmentData ?? [])
        .map<Map<String, dynamic>>((e) => {
              'equipment_item_id': e['equipment_item_id'] ?? e['id'] ?? '',
              'name': e['name'] ?? '',
              'quantity': e['quantity'] ?? 1,
              'notes': e['notes'] ?? '',
              'has_requirement': e['has_requirement'] ?? false,
              'is_experienced': e['is_experienced'] ?? false,
              'experience_years': e['experience_years'] ?? 0,
            })
        .toList();

    List<Map<String, dynamic>> availableRoles = [];
    List<Map<String, dynamic>> availableTags = [];
    List<Map<String, dynamic>> availableEquipment = [];
    bool loadingCatalogs = true;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (loadingCatalogs) {
            _fetchCatalogs().then((catalogs) {
              if (ctx.mounted) {
                setSheetState(() {
                  availableRoles = catalogs['roles']!;
                  availableTags = catalogs['tags']!;
                  availableEquipment = catalogs['equipment']!;
                  loadingCatalogs = false;
                });
              }
            });
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.92,
            decoration: BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFF30363D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple[900]!.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.work_history_outlined,
                            color: Colors.purple[400], size: 18),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Detalles profesionales',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            Text(
                                'PUT /freelancer/profile/upsert-roles',
                                style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                      IconButton(
                        icon:
                            Icon(Icons.close, color: Colors.grey[500]),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(color: Color(0xFF30363D), height: 1),
                if (loadingCatalogs)
                  Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: Colors.blue[400]),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          MediaQuery.of(ctx).viewInsets.bottom + 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sheetSubHeader(Icons.work_history_outlined,
                              'ROLES', Colors.blue[400]!),
                          SizedBox(height: 10),
                          ...roles.asMap().entries.map((e) =>
                              _buildRoleEditor(
                                  e.key, roles, setSheetState)),
                          _buildSheetAddButton('Agregar rol', () {
                            _showAddRoleDialog(
                                ctx, availableRoles, roles, setSheetState);
                          }),
                          SizedBox(height: 24),
                          _sheetSubHeader(Icons.label_outline,
                              'HABILIDADES', Colors.orange[400]!),
                          SizedBox(height: 10),
                          availableTags.isEmpty
                              ? Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF0D1117),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Color(0xFF30363D)),
                                  ),
                                  child: Text(
                                    'No hay habilidades',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12),
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: availableTags
                                      .map<Widget>((tag) {
                                    final id =
                                        (tag['id'] ?? '').toString();
                                    final sel =
                                        selectedTagIds.contains(id);
                                    return FilterChip(
                                      label: Text(tag['name'] ?? '',
                                          style: TextStyle(
                                              color: sel
                                                  ? Colors.white
                                                  : Colors.grey[300],
                                              fontSize: 12)),
                                      selected: sel,
                                      onSelected: (val) {
                                        setSheetState(() {
                                          if (val) {
                                            selectedTagIds.add(id);
                                          } else {
                                            selectedTagIds.remove(id);
                                          }
                                        });
                                      },
                                      backgroundColor:
                                          Color(0xFF0D1117),
                                      selectedColor: Colors.blue[800],
                                      checkmarkColor: Colors.white,
                                      side: BorderSide(
                                          color: sel
                                              ? Colors.blue[400]!
                                              : Color(0xFF30363D)),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                    );
                                  }).toList(),
                                ),
                          SizedBox(height: 24),
                          _sheetSubHeader(Icons.camera_alt_outlined,
                              'EQUIPO', Colors.green[400]!),
                          SizedBox(height: 10),
                          ...equipment.asMap().entries.map((e) =>
                              _buildEquipmentEditor(
                                  e.key, equipment, setSheetState)),
                          _buildSheetAddButton('Agregar equipo', () {
                            _showAddEquipmentDialog(
                                ctx,
                                availableEquipment,
                                equipment,
                                setSheetState);
                          }),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange[900]!
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.orange[700]!
                                      .withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_outlined,
                                    color: Colors.orange[400], size: 14),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Operación destructiva: roles, habilidades y equipo no incluidos serán eliminados.',
                                    style: TextStyle(
                                        color: Colors.orange[300],
                                        fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      setSheetState(
                                          () => saving = true);
                                      final ok =
                                          await _saveProfessionalDetails(
                                        roles: roles,
                                        tagIds: selectedTagIds,
                                        equipment: equipment,
                                      );
                                      setSheetState(
                                          () => saving = false);
                                      if (ok && ctx.mounted) {
                                        Navigator.pop(ctx);
                                        _fetchAllUserData();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                disabledBackgroundColor:
                                    Colors.blue[900],
                                padding: EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                              child: saving
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                            width: 16,
                                            height: 16,
                                            child:
                                                CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2)),
                                        SizedBox(width: 10),
                                        Text('Guardando...',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15)),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.sync,
                                            color: Colors.white,
                                            size: 18),
                                        SizedBox(width: 8),
                                        Text('Guardar detalles',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchCatalogs() async {
    final result = <String, List<Map<String, dynamic>>>{
      'roles': [],
      'tags': [],
      'equipment': [],
    };
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];
      if (token == null || baseUrl == null) return result;

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/job-roles'), headers: headers),
        http.get(Uri.parse('$baseUrl/tags'), headers: headers),
        http.get(Uri.parse('$baseUrl/equipment'), headers: headers),
      ]);

      final keys = ['roles', 'tags', 'equipment'];
      for (int i = 0; i < responses.length; i++) {
        if (responses[i].statusCode == 200) {
          final data = json.decode(responses[i].body);
          final list = data is List
              ? data
              : (data['results'] ?? data['items'] ?? data['data'] ?? []);
          result[keys[i]] = List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (_) {}
    return result;
  }

  Future<bool> _saveProfessionalDetails({
    required List<Map<String, dynamic>> roles,
    required List<String> tagIds,
    required List<Map<String, dynamic>> equipment,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];
      if (token == null || baseUrl == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/freelancer/profile/upsert-roles'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'job_roles': roles
              .map((r) => {
                    'job_role_id': r['job_role_id'],
                    'years': r['years'],
                    'level': r['level'],
                  })
              .toList(),
          'tag_ids': tagIds,
          'equipment': equipment
              .map((e) => {
                    'equipment_item_id': e['equipment_item_id'],
                    'quantity': e['quantity'],
                    'notes': e['notes'],
                    'has_requirement': e['has_requirement'],
                    'is_experienced': e['is_experienced'],
                    'experience_years': e['experience_years'],
                  })
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        _showSuccess('Detalles profesionales actualizados');
        return true;
      } else {
        _showError('No se pudieron guardar los cambios. Intenta nuevamente.');
      }
      return false;
    } catch (e) {
      _showError('Ocurrió un error al guardar. Verifica tu conexión.');
      return false;
    }
  }

  void _showAddRoleDialog(
    BuildContext ctx,
    List<Map<String, dynamic>> availableRoles,
    List<Map<String, dynamic>> roles,
    StateSetter setSheetState,
  ) {
    if (availableRoles.isEmpty) {
      _showError('No hay roles disponibles en el catálogo');
      return;
    }
    String? selectedId;
    String? selectedName;
    final yearsCtrl = TextEditingController(text: '1');
    final levelCtrl = TextEditingController(text: '1');

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          backgroundColor: Color(0xFF1C2128),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Agregar rol',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                dropdownColor: Color(0xFF1C2128),
                style: TextStyle(color: Colors.white),
                decoration: _dialogInputDecoration('Selecciona un rol'),
                items: availableRoles
                    .map<DropdownMenuItem<String>>((r) => DropdownMenuItem(
                          value: (r['id'] ?? r['job_role_id']).toString(),
                          child: Text(r['name'] ?? '',
                              style: TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (val) {
                  setDState(() {
                    selectedId = val;
                    selectedName = availableRoles.firstWhere(
                        (r) =>
                            (r['id'] ?? r['job_role_id']).toString() == val,
                        orElse: () => {})['name'];
                  });
                },
              ),
              SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextFormField(
                  controller: yearsCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white),
                  decoration: _dialogInputDecoration('Años'),
                )),
                SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                  controller: levelCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white),
                  decoration: _dialogInputDecoration('Nivel (1-5)'),
                )),
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: Text('Cancelar',
                    style: TextStyle(color: Colors.grey[400]))),
            TextButton(
              onPressed: () {
                if (selectedId != null) {
                  setSheetState(() {
                    roles.add({
                      'job_role_id': selectedId,
                      'name': selectedName ?? '',
                      'years': int.tryParse(yearsCtrl.text) ?? 1,
                      'level': int.tryParse(levelCtrl.text) ?? 1,
                    });
                  });
                  Navigator.pop(dCtx);
                }
              },
              child: Text('Agregar',
                  style: TextStyle(
                      color: Colors.blue[400],
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEquipmentDialog(
    BuildContext ctx,
    List<Map<String, dynamic>> availableEquipment,
    List<Map<String, dynamic>> equipment,
    StateSetter setSheetState,
  ) {
    if (availableEquipment.isEmpty) {
      _showError('No hay equipo disponible en el catálogo');
      return;
    }
    String? selectedId;
    String? selectedName;
    final qtyCtrl = TextEditingController(text: '1');
    final notesCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          backgroundColor: Color(0xFF1C2128),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Agregar equipo',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                dropdownColor: Color(0xFF1C2128),
                style: TextStyle(color: Colors.white),
                decoration: _dialogInputDecoration('Selecciona equipo'),
                items: availableEquipment
                    .map<DropdownMenuItem<String>>(
                        (e) => DropdownMenuItem(
                              value: (e['id'] ?? e['equipment_item_id'])
                                  .toString(),
                              child: Text(e['name'] ?? '',
                                  style: TextStyle(color: Colors.white)),
                            ))
                    .toList(),
                onChanged: (val) {
                  setDState(() {
                    selectedId = val;
                    selectedName = availableEquipment.firstWhere(
                        (e) =>
                            (e['id'] ?? e['equipment_item_id'])
                                .toString() ==
                            val,
                        orElse: () => {})['name'];
                  });
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white),
                decoration: _dialogInputDecoration('Cantidad'),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: notesCtrl,
                style: TextStyle(color: Colors.white),
                decoration: _dialogInputDecoration('Notas (opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: Text('Cancelar',
                    style: TextStyle(color: Colors.grey[400]))),
            TextButton(
              onPressed: () {
                if (selectedId != null) {
                  setSheetState(() {
                    equipment.add({
                      'equipment_item_id': selectedId,
                      'name': selectedName ?? '',
                      'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                      'notes': notesCtrl.text,
                      'has_requirement': false,
                      'is_experienced': false,
                      'experience_years': 0,
                    });
                  });
                  Navigator.pop(dCtx);
                }
              },
              child: Text('Agregar',
                  style: TextStyle(
                      color: Colors.blue[400],
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(Icons.check_circle, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: Colors.green[700],
      duration: Duration(seconds: 3),
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(Icons.error_outline, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: Colors.red[700],
      duration: Duration(seconds: 4),
    ));
  }

  Widget _sheetInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
        SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.grey[600], size: 18)
                : null,
            filled: true,
            fillColor: Color(0xFF0D1117),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Color(0xFF30363D))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Color(0xFF30363D))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.blue[500]!, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _sheetSubHeader(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 14),
      SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
    ]);
  }

  Widget _buildRoleEditor(
    int index,
    List<Map<String, dynamic>> roles,
    StateSetter setSheetState,
  ) {
    final role = roles[index];
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(role['name'] ?? 'Rol ${index + 1}',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600))),
            GestureDetector(
              onTap: () => setSheetState(() => roles.removeAt(index)),
              child: Icon(Icons.delete_outline,
                  color: Colors.red[400], size: 18),
            ),
          ]),
          SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Años',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 10)),
                  SizedBox(height: 4),
                  TextFormField(
                    initialValue: role['years'].toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _dialogInputDecoration('0'),
                    onChanged: (val) => setSheetState(
                        () => roles[index]['years'] =
                            int.tryParse(val) ?? 0),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nivel',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 10)),
                  SizedBox(height: 4),
                  TextFormField(
                    initialValue: role['level'].toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _dialogInputDecoration('1-5'),
                    onChanged: (val) => setSheetState(
                        () => roles[index]['level'] =
                            int.tryParse(val) ?? 0),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildEquipmentEditor(
    int index,
    List<Map<String, dynamic>> equipment,
    StateSetter setSheetState,
  ) {
    final item = equipment[index];
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(item['name'] ?? 'Equipo ${index + 1}',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600))),
            GestureDetector(
              onTap: () => setSheetState(() => equipment.removeAt(index)),
              child: Icon(Icons.delete_outline,
                  color: Colors.red[400], size: 18),
            ),
          ]),
          SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cantidad',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 10)),
                  SizedBox(height: 4),
                  TextFormField(
                    initialValue: item['quantity'].toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _dialogInputDecoration('1'),
                    onChanged: (val) => setSheetState(() =>
                        equipment[index]['quantity'] =
                            int.tryParse(val) ?? 1),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notas',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 10)),
                  SizedBox(height: 4),
                  TextFormField(
                    initialValue: item['notes'],
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _dialogInputDecoration('Opcional'),
                    onChanged: (val) => setSheetState(
                        () => equipment[index]['notes'] = val),
                  ),
                ],
              ),
            ),
          ]),
          SizedBox(height: 10),
          Row(children: [
            _miniToggle(
                'Requerido',
                item['has_requirement'] as bool,
                (val) => setSheetState(
                    () => equipment[index]['has_requirement'] = val)),
            SizedBox(width: 16),
            _miniToggle(
                'Con experiencia',
                item['is_experienced'] as bool,
                (val) => setSheetState(
                    () => equipment[index]['is_experienced'] = val)),
          ]),
        ],
      ),
    );
  }

  Widget _miniToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 30,
          height: 17,
          decoration: BoxDecoration(
            color: value ? Colors.blue[600] : Color(0xFF30363D),
            borderRadius: BorderRadius.circular(8.5),
          ),
          child: AnimatedAlign(
            duration: Duration(milliseconds: 150),
            alignment:
                value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 13,
              height: 13,
              margin: EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
        SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ]),
    );
  }

  Widget _buildSheetAddButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Colors.blue[800]!.withOpacity(0.5), width: 1),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.blue[400], size: 16),
              SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: Colors.blue[400], fontSize: 13)),
            ]),
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
      filled: true,
      fillColor: Color(0xFF161B22),
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF30363D))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF30363D))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Colors.blue[500]!, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: SafeArea(
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(color: Colors.blue[600]))
            : errorMessage.isNotEmpty
                ? _buildErrorState()
                : freelancerProfile == null
                    ? _buildEmptyProfileState()
                    : _buildProfileContent(isMobile),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            SizedBox(height: 24),
            Text(errorMessage,
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
                textAlign: TextAlign.center),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchAllUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding:
                    EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: Icon(Icons.refresh, color: Colors.white),
              label:
                  Text('Reintentar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProfileState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_outlined,
                size: 80, color: Colors.blue[400]),
            SizedBox(height: 24),
            Text('¡Bienvenido!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Completa tu perfil profesional para empezar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 16)),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding:
                    EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              icon: Icon(Icons.person_add, color: Colors.white),
              label: Text('Crear Perfil',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(bool isMobile) {
    return Column(
      children: [
        _buildCompactHeader(isMobile),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile) ...[
                  _buildProfessionalInfoCard(),
                  SizedBox(height: 12),
                  _buildProfessionalDetailsCard(),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildProfessionalInfoCard()),
                      SizedBox(width: 24),
                      Expanded(child: _buildProfessionalDetailsCard()),
                    ],
                  ),
                ],
                SizedBox(height: 16),
                // ──────────────────────────────────────────
                // SECCIÓN DOCUMENTACIÓN
                // ──────────────────────────────────────────
                _buildDocumentationSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactHeader(bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 360;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 32, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        border:
            Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
      ),
      child: Row(
        children: [
          profileImageUrl != null && profileImageUrl!.isNotEmpty
              ? CircleAvatar(
                  radius: isVerySmall ? 22 : 26,
                  backgroundImage: NetworkImage(profileImageUrl!),
                  onBackgroundImageError: (exception, stackTrace) {},
                  child: profileImageUrl!.isEmpty
                      ? Text(
                          (userData?['full_name'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isVerySmall ? 16 : 18,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                )
              : CircleAvatar(
                  radius: isVerySmall ? 22 : 26,
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    (userData?['full_name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isVerySmall ? 16 : 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
          SizedBox(width: isMobile ? 10 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userData?['full_name'] ?? 'Usuario',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isVerySmall ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3),
                if (!isVerySmall)
                  Row(
                    children: [
                      if (userData?['nickname'] != null) ...[
                        Text('@${userData!['nickname']}',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 12)),
                        SizedBox(width: 6),
                        Text('•',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                        SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          userData?['email'] ?? '',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon:
                    Icon(Icons.logout, color: Colors.red[400], size: 18),
                onPressed: _logout,
                tooltip: 'Cerrar sesión',
                padding: EdgeInsets.all(8),
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalInfoCard() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Información profesional',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    color: Colors.blue[400], size: 16),
                onPressed: _editGeneralInfo,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 18),
          if (freelancerProfile?['bio'] != null) ...[
            _buildInfoLabel('BIOGRAFÍA'),
            SizedBox(height: 6),
            Text(
              freelancerProfile!['bio'],
              style: TextStyle(
                  color: Colors.grey[300], fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 18),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 400;
              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildExperienceInfo(),
                    if (freelancerProfile?['rfc'] != null) ...[
                      SizedBox(height: 16),
                      _buildRFCInfo(),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildExperienceInfo()),
                  if (freelancerProfile?['rfc'] != null) ...[
                    SizedBox(width: 12),
                    Expanded(child: _buildRFCInfo()),
                  ],
                ],
              );
            },
          ),
          if (freelancerProfile?['location'] != null) ...[
            SizedBox(height: 18),
            _buildInfoLabel('UBICACIÓN'),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    color: Colors.purple[400], size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    freelancerProfile!['location'],
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExperienceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoLabel('EXPERIENCIA'),
        SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.work_outline, color: Colors.green[400], size: 16),
            SizedBox(width: 6),
            Text(
              '${freelancerProfile?['years_experience'] ?? 0} años',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRFCInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoLabel('RFC'),
        SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.verified_outlined,
                color: Colors.blue[400], size: 16),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                freelancerProfile!['rfc'],
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfessionalDetailsCard() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Detalles profesionales',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    color: Colors.blue[400], size: 16),
                onPressed: _editProfessionalDetails,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 18),
          if (jobRolesData != null && jobRolesData!.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.work_history_outlined,
                  color: Colors.grey[500], size: 14),
              SizedBox(width: 6),
              _buildInfoLabel('ROLES'),
            ]),
            SizedBox(height: 10),
            ...jobRolesData!.map((role) => _buildRoleChip(role)),
            SizedBox(height: 18),
          ],
          if (tagsData != null && tagsData!.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.label_outline, color: Colors.grey[500], size: 14),
              SizedBox(width: 6),
              _buildInfoLabel('HABILIDADES'),
            ]),
            SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tagsData!
                  .map<Widget>((tag) => _buildTagChip(tag))
                  .toList(),
            ),
            SizedBox(height: 18),
          ],
          if (equipmentData != null && equipmentData!.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.camera_alt_outlined,
                  color: Colors.grey[500], size: 14),
              SizedBox(width: 6),
              _buildInfoLabel('EQUIPO'),
            ]),
            SizedBox(height: 10),
            ...equipmentData!.map((item) => _buildEquipmentItem(item)),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ✅ SECCIÓN DOCUMENTACIÓN — con badges y alertas
  // ══════════════════════════════════════════════════════
  Widget _buildDocumentationSection() {
    final hasDocuments = userDocuments.isNotEmpty;
    final missingDocs = _getProfileMissingDocs();
    final isComplete = missingDocs.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 8, 0),
            child: Row(
              children: [
                Text('Documentación',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                SizedBox(width: 10),

                // ✅ Badge PENDIENTES
                if (!isComplete && hasDocuments)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange[400], size: 11),
                      SizedBox(width: 4),
                      Text(
                        '${missingDocs.length} pendiente${missingDocs.length > 1 ? 's' : ''}',
                        style: TextStyle(
                            color: Colors.orange[400],
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),

                // ✅ Badge COMPLETO
                if (isComplete && hasDocuments)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.green[400], size: 11),
                      SizedBox(width: 4),
                      Text('Completo',
                          style: TextStyle(
                              color: Colors.green[400],
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),

                Spacer(),

                // Botón Gestionar
                GestureDetector(
                  onTap: _goToDocuments,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Color(0xFF30363D)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file_outlined,
                            color: Colors.grey[400], size: 12),
                        SizedBox(width: 4),
                        Text('Gestionar',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 11)),
                      ],
                    ),
                  ),
                ),

                if (isLoadingDocuments)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.blue[400], strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Divider(color: Color(0xFF30363D), height: 1),

          if (!hasDocuments)
            // ── Estado vacío ──────────────────────────────
            Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Color(0xFF1C2128),
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF30363D)),
                    ),
                    child: Icon(Icons.shield_outlined,
                        color: Colors.grey[500], size: 28),
                  ),
                  SizedBox(height: 16),
                  Text('Verificación Pendiente',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text(
                    'Sube tus documentos para verificar tu identidad',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _goToDocuments,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2563EB),
                        padding: EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Subir documentos ahora',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            )
          else
            // ── Lista de documentos ───────────────────────
            Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Bloque de alerta cuando faltan documentos
                  if (!isComplete) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange[400], size: 15),
                            SizedBox(width: 7),
                            Text(
                              'Faltan ${missingDocs.length} documento${missingDocs.length > 1 ? 's' : ''} por subir',
                              style: TextStyle(
                                  color: Colors.orange[300],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ]),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: missingDocs
                                .map((name) => Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(name,
                                          style: TextStyle(
                                              color: Colors.orange[300],
                                              fontSize: 11)),
                                    ))
                                .toList(),
                          ),
                          SizedBox(height: 10),
                          GestureDetector(
                            onTap: _goToDocuments,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload_rounded,
                                      color: Colors.orange[300], size: 15),
                                  SizedBox(width: 6),
                                  Text('Completar documentación',
                                      style: TextStyle(
                                          color: Colors.orange[300],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14),
                  ] else ...[
                    // ✅ Banner verde cuando está completo
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.green.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.green[400], size: 14),
                        SizedBox(width: 7),
                        Text(
                            'Tu documentación está completa y en revisión',
                            style: TextStyle(
                                color: Colors.green[300], fontSize: 12)),
                      ]),
                    ),
                  ],

                  // Lista de documentos subidos
                  ...userDocuments
                      .map<Widget>((doc) => _buildDocumentRow(doc))
                      .toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(dynamic doc) {
    final docType = doc['document_type'];
    final fileName = doc['file_name'] ??
        doc['file_path']?.toString().split('/').last ??
        'Documento';
    final typeName =
        docType?['name'] ?? docType?['code'] ?? 'Documento';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[400], size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(typeName,
                    style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3)),
                SizedBox(height: 2),
                Text(fileName,
                    style: TextStyle(
                        color: Colors.grey[300], fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: _goToDocuments,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[900]!.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.blue[800]!.withOpacity(0.4)),
              ),
              child: Text('Gestionar',
                  style: TextStyle(
                      color: Colors.blue[400], fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[500],
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildRoleChip(dynamic role) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              role['name'] ?? 'Rol',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          if (role['years'] != null || role['level'] != null)
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${role['years'] ?? 0}a • Nv.${role['level'] ?? 0}',
                style: TextStyle(
                    color: Colors.blue[300],
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagChip(dynamic tag) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Text(
        tag['name'] ?? tag.toString(),
        style: TextStyle(color: Colors.grey[300], fontSize: 12),
      ),
    );
  }

  Widget _buildEquipmentItem(dynamic item) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Equipo',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                if (item['notes'] != null &&
                    item['notes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '"${item['notes']}"',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          if (item['quantity'] != null && item['quantity'] > 0)
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'x${item['quantity']}',
                style: TextStyle(
                    color: Colors.green[300],
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}