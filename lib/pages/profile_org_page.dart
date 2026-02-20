import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/error_handler.dart';

class ProfileOrgPage extends StatefulWidget {
  final String userId;

  ProfileOrgPage({required this.userId});

  @override
  _ProfileOrgPageState createState() => _ProfileOrgPageState();
}

class _ProfileOrgPageState extends State<ProfileOrgPage> {
  
  final _legalNameController = TextEditingController();
  final _tradeNameController = TextEditingController();
  final _rfcController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedOrgType = 'COMPANY';
  String _selectedCountry = 'MX';
  File? _logoFile;
  bool _isLoading = false;

  final List<Map<String, String>> _orgTypes = [
    {'value': 'COMPANY', 'label': 'EMPRESA'},
    {'value': 'PRODUCTION_HOUSE', 'label': 'CASA PRODUCTORA'},
    {'value': 'AGENCY', 'label': 'AGENCIA'},
  ];

  @override
  void dispose() {
    _legalNameController.dispose();
    _tradeNameController.dispose();
    _rfcController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _logoFile = File(image.path);
        });
      }
    } catch (e) {
      print('Error al seleccionar logo: $e');
    }
  }

  Future<bool> _associateUserToOrganization(String organizationId, String userId, String token) async {
    try {
      final baseUrl = dotenv.env['API_BASE_URL'];
      final Map<String, dynamic> data = {
        "organization_id": organizationId,
        "user_id": userId,
        "role": "OWNER", 
        "is_active": true,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/org-users/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      print('Error al asociar usuario: $e');
      return false;
    }
  }
  Future<void> _submitProfile() async {
    if (_legalNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor ingresa el nombre legal')),
      );
      return;
    }

    if (_tradeNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor ingresa el nombre comercial')),
      );
      return;
    }

    if (_rfcController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor ingresa el RFC')),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor ingresa una descripción')),
      );
      return;
    }

    final baseUrl = dotenv.env['API_BASE_URL'];
    if (baseUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: API_BASE_URL no configurada')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;
    final currentUserId = authProvider.userInfo?['id']?.toString() ?? widget.userId;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: No estás autenticado')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> data = {
        "org_type": _selectedOrgType,
        "legal_name": _legalNameController.text.trim(),
        "trade_name": _tradeNameController.text.trim(),
        "rfc": _rfcController.text.trim(),
        "country_code": _selectedCountry,
        "description": _descriptionController.text.trim(),
        "verification_badge": false, 
      };

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: Colors.blue[600]),
        ),
      );

      final response = await http.post(
        Uri.parse('$baseUrl/organizations/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(Duration(seconds: 15));

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (response.statusCode == 201) { 
        try {
          final responseData = jsonDecode(response.body);
          
          final organizationId = responseData['id'];
          
          if (organizationId != null) {
            final associationSuccess = await _associateUserToOrganization(
              organizationId.toString(),
              currentUserId,
              token,
            );
            
            if (associationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('¡Perfil de organización creado exitosamente!'),
                  backgroundColor: Colors.green[600],
                  duration: Duration(seconds: 3),
                ),
              );

              await authProvider.getUserInfo();

              await Future.delayed(Duration(milliseconds: 2500));
              Navigator.pushReplacementNamed(context, '/events');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Organización creada, pero hubo un error al asociar el usuario. Contacta al soporte.'),
                  backgroundColor: Colors.orange[600],
                ),
              );
              await authProvider.getUserInfo();
              Navigator.pushReplacementNamed(context, '/events');
            }
          } else {
            throw Exception('No se recibió ID de la organización');
          }
          
        } catch (e) {
          print('Error al procesar respuesta: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Organización creada, pero hubo un error al procesar la respuesta: $e'),
              backgroundColor: Colors.orange[600],
            ),
          );
          await authProvider.getUserInfo();
          Navigator.pushReplacementNamed(context, '/events');
        }
      } else {
        ApiErrorHandler.showErrorSnackBar(context, response.friendlyErrorMessage);
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      print('Error general: $e');
      ApiErrorHandler.showErrorSnackBar(context, ApiErrorHandler.handleNetworkException(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userInfo;
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      drawer: isMobile ? _buildDrawer(userData) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) _buildSidebar(userData),
            Expanded(
              child: _buildMainContent(isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(Map<String, dynamic>? userData) {
    return Drawer(
      backgroundColor: Color(0xFF161B22),
      child: _buildSidebarContent(userData),
    );
  }

  Widget _buildSidebar(Map<String, dynamic>? userData) {
    return Container(
      width: 200,
      color: Color(0xFF161B22),
      child: _buildSidebarContent(userData),
    );
  }

  Widget _buildSidebarContent(Map<String, dynamic>? userData) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.connect_without_contact,
                      color: Colors.white, size: 20),
                ),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Corte y Queda',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text('AUDIOVISUAL OS',
                        style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey[800], height: 1),
          SizedBox(height: 20),
          _buildMenuItem(Icons.dashboard_outlined, 'Dashboard', false),
          _buildMenuItem(Icons.business_outlined, 'Company Profile', true),
          Spacer(),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[700],
                  child: Icon(Icons.business, color: Colors.white, size: 18),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userData?['full_name']?.split(' ')[0] ?? 'Empresa',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('Admin',
                          style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isMobile) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20.0 : 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile)
              Builder(builder: (context) {
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.menu, color: Colors.white, size: 24),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                    SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.connect_without_contact,
                          color: Colors.white, size: 16),
                    ),
                    SizedBox(width: 8),
                    Text('Corte y Queda',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ],
                );
              }),
            
            if (isMobile) SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Configuración del perfil de la empresa',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Configura la identidad legal y comercial de tu organización.',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: isMobile ? 12 : 14)),
                    ],
                  ),
                ),
                if (!isMobile) ...[
                  SizedBox(width: 20),
                  _buildProgressIndicator(),
                ],
              ],
            ),

            if (isMobile) ...[
              SizedBox(height: 16),
              _buildProgressIndicator(),
            ],

            SizedBox(height: isMobile ? 24 : 32),

            isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('PROGRESO DE REGISTRO',
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('67%',
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('(67% Completado)',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          SizedBox(height: 12),
          _buildProgressStep(true, 'Registro de cuenta'),
          _buildProgressStep(true, 'Perfil de la empresa', isActive: true),
          _buildProgressStep(false, 'Información bancaria'),
          Text('2 Pasos restantes',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildProgressStep(bool isCompleted, String title, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isActive
                ? Colors.blue[400]
                : (isCompleted ? Colors.green[400] : Colors.grey[600]),
            size: 16,
          ),
          SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: isActive
                      ? Colors.blue[300]
                      : (isCompleted ? Colors.white : Colors.grey[500]),
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildLegalSection(true),
        SizedBox(height: 24),
        _buildProfileSection(true),
        SizedBox(height: 24),
        _buildLogoSection(true),
        SizedBox(height: 24),
        _buildTipsSection(true),
        SizedBox(height: 32),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildLegalSection(false),
              SizedBox(height: 24),
              _buildProfileSection(false),
              SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildTipsSection(false),
              SizedBox(height: 24),
              _buildLogoSection(false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegalSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_outlined, color: Colors.grey[400], size: 20),
              SizedBox(width: 8),
              Text('IDENTIDAD LEGAL Y COMERCIAL',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 12 : 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 20),

          Text('NOMBRE LEGAL',
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          TextFormField(
            controller: _legalNameController,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 14),
            decoration: _inputDecoration('Nombre de la entidad legal según registrado', isMobile),
          ),
          SizedBox(height: 16),

          Text('COMERCIAL / NOMBRE COMERCIAL',
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          TextFormField(
            controller: _tradeNameController,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 14),
            decoration: _inputDecoration('El nombre de la marca que conocen tus clientes', isMobile),
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID FISCAL / RFC',
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _rfcController,
                      style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 14),
                      decoration: _inputDecoration('ABCD123456XYZ', isMobile),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PAÍS',
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
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
                          value: _selectedCountry,
                          dropdownColor: Color(0xFF161B22),
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                          items: [
                            DropdownMenuItem(value: 'MX', child: Text('MX - México')),
                            DropdownMenuItem(value: 'US', child: Text('US - Estados Unidos')),
                            DropdownMenuItem(value: 'ES', child: Text('ES - España')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCountry = value!;
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
        ],
      ),
    );
  }

  Widget _buildProfileSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_circle_outlined, color: Colors.grey[400], size: 20),
              SizedBox(width: 8),
              Text('PERFIL DE LA ORGANIZACIÓN',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 12 : 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 20),

          Text('TIPO DE ORGANIZACIÓN',
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold)),
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
                value: _selectedOrgType,
                dropdownColor: Color(0xFF161B22),
                style: TextStyle(color: Colors.white, fontSize: 14),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                items: _orgTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOrgType = value!;
                  });
                },
              ),
            ),
          ),
          SizedBox(height: 8),
          Text('El tipo de entidad está bloqueado según el tipo de cuenta.',
              style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          SizedBox(height: 20),

          Text('DESCRIPCIÓN DE LA EMPRESA',
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Máximo 2000 caracteres',
              style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 5,
            maxLength: 2000,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 14),
            decoration: InputDecoration(
              hintText: 'Describe tus capacidades de producción, equipo de estudio, experiencia y los tipos de proyectos en los que te especializas...',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
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
              counterStyle: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Logo de la empresa',
              style: TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('PNG o JPG cualitativa. Máx 2MB.',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          SizedBox(height: 16),

          // Preview del logo
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF30363D), width: 1),
                ),
                child: _logoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _logoFile!, 
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: Colors.grey[600], size: 48),
                          SizedBox(height: 8),
                          Text('Click para subir logo',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange[800]!, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[400], size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nota: El logo se podrá subir posteriormente. El endpoint actual solo acepta datos básicos en formato JSON.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Color(0xFF1C2128),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONSEJOS DE CONFIGURACIÓN',
              style: TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          _buildTip(Icons.info_outline, 'Asegúrate de que tu Nombre legal coincide con los documentos de registro fiscal para evitar retrasos en el pago.'),
          SizedBox(height: 12),
          _buildTip(Icons.receipt_outlined, 'El RFC será utilizado para la facturación automática en todos los proyectos.'),
          SizedBox(height: 12),
          _buildTip(Icons.store_outlined, 'Tu Nombre comercial y descripción serán visibles para los talentos.'),
        ],
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue[400], size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(color: Colors.grey[400], fontSize: 11, height: 1.5)),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () {
              // Descartar cambios
              if (_legalNameController.text.isNotEmpty ||
                  _tradeNameController.text.isNotEmpty ||
                  _rfcController.text.isNotEmpty ||
                  _descriptionController.text.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Color(0xFF161B22),
                    title: Text('Descartar cambios', style: TextStyle(color: Colors.white)),
                    content: Text('¿Estás seguro de que quieres descartar todos los cambios?',
                        style: TextStyle(color: Colors.grey[400])),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                        ),
                        child: Text('Descartar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.grey[700]!, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text('Descartar',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              padding: EdgeInsets.symmetric(vertical: 14),
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
                : Text('Guardar configuración',
                    style: TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, bool isMobile) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: isMobile ? 12 : 13),
      fillColor: Color(0xFF0D1117),
      filled: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );
  }

  Widget _buildMenuItem(IconData icon, String title, bool isActive) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Color(0xFF1F6FEB).withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isActive
            ? Border.all(color: Color(0xFF1F6FEB).withOpacity(0.4), width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon,
            color: isActive ? Colors.blue[400] : Colors.grey[500], size: 20),
        title: Text(title,
            style: TextStyle(
                color: isActive ? Colors.blue[300] : Colors.grey[400],
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    );
  }
}