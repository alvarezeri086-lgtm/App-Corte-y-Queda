import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  
  bool isLoading = true;
  String errorMessage = '';
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchAllUserData();
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

  List<dynamic> _extractEquipmentData(Map<String, dynamic> response) {
    final equipmentList = <Map<String, dynamic>>[];
    
    if (response.containsKey('equipment') && response['equipment'] is List) {
      for (var item in response['equipment']) {
        equipmentList.add({
          'name': item['name'] ?? 'Sin nombre',
          'quantity': item['quantity'] ?? 0,
          'notes': item['notes'] ?? '',
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editar información general'),
        backgroundColor: Colors.blue[600],
      ),
    );
  }

  void _editProfessionalDetails() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editar detalles profesionales'),
        backgroundColor: Colors.blue[600],
      ),
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
            ? Center(child: CircularProgressIndicator(color: Colors.blue[600]))
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
            Text(errorMessage, style: TextStyle(color: Colors.grey[400], fontSize: 16), textAlign: TextAlign.center),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchAllUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: Icon(Icons.refresh, color: Colors.white),
              label: Text('Reintentar', style: TextStyle(color: Colors.white)),
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
            Icon(Icons.person_add_outlined, size: 80, color: Colors.blue[400]),
            SizedBox(height: 24),
            Text('¡Bienvenido!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Completa tu perfil profesional para empezar', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontSize: 16)),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              icon: Icon(Icons.person_add, color: Colors.white),
              label: Text('Crear Perfil', style: TextStyle(color: Colors.white)),
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
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
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
                          style: TextStyle(color: Colors.white, fontSize: isVerySmall ? 16 : 18, fontWeight: FontWeight.bold),
                        )
                      : null,
                )
              : CircleAvatar(
                  radius: isVerySmall ? 22 : 26,
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    (userData?['full_name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: isVerySmall ? 16 : 18, fontWeight: FontWeight.bold),
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
                        Text('@${userData!['nickname']}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        SizedBox(width: 6),
                        Text('•', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          userData?['email'] ?? '',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
                icon: Icon(Icons.logout, color: Colors.red[400], size: 18),
                onPressed: _logout,
                tooltip: 'Cerrar sesión',
                padding: EdgeInsets.all(8),
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.blue[400], size: 18),
                onPressed: _editGeneralInfo,
                tooltip: 'Editar',
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
              Text('Información profesional', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.blue[400], size: 16),
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
              style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4),
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
                Icon(Icons.location_on_outlined, color: Colors.purple[400], size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    freelancerProfile!['location'],
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
            Icon(Icons.verified_outlined, color: Colors.blue[400], size: 16),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                freelancerProfile!['rfc'],
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
              Text('Detalles profesionales', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.blue[400], size: 16),
                onPressed: _editProfessionalDetails,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 18),
          
          if (jobRolesData != null && jobRolesData!.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.work_history_outlined, color: Colors.grey[500], size: 14),
                SizedBox(width: 6),
                _buildInfoLabel('ROLES'),
              ],
            ),
            SizedBox(height: 10),
            ...jobRolesData!.map((role) => _buildRoleChip(role)),
            SizedBox(height: 18),
          ],
          
          if (tagsData != null && tagsData!.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.label_outline, color: Colors.grey[500], size: 14),
                SizedBox(width: 6),
                _buildInfoLabel('HABILIDADES'),
              ],
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tagsData!.map<Widget>((tag) => _buildTagChip(tag)).toList(),
            ),
            SizedBox(height: 18),
          ],
          
          if (equipmentData != null && equipmentData!.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.camera_alt_outlined, color: Colors.grey[500], size: 14),
                SizedBox(width: 6),
                _buildInfoLabel('EQUIPO'),
              ],
            ),
            SizedBox(height: 10),
            ...equipmentData!.map((item) => _buildEquipmentItem(item)),
          ],
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
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          if (role['years'] != null || role['level'] != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${role['years'] ?? 0}a • Nv.${role['level'] ?? 0}',
                style: TextStyle(color: Colors.blue[300], fontSize: 11, fontWeight: FontWeight.w500),
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
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (item['notes'] != null && item['notes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '"${item['notes']}"',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          if (item['quantity'] != null && item['quantity'] > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'x${item['quantity']}',
                style: TextStyle(color: Colors.green[300], fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}