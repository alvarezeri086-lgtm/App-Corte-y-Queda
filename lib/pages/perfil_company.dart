import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/error_handler.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({Key? key}) : super(key: key);

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? organizationData;
  
  bool isLoading = true;
  String errorMessage = '';
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchAllCompanyData();
  }

  Future<void> _fetchAllCompanyData() async {
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
      ).timeout(Duration(seconds: 15));

      if (userResponse.isSuccess) {
        final userJson = json.decode(userResponse.body);
        
        setState(() {
          userData = userJson;
          
          if (userJson['photo_url'] != null) {
            profileImageUrl = userJson['photo_url'];
          }
        });

        final orgResponse = await http.get(
          Uri.parse('$baseUrl/organizations/me'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(Duration(seconds: 15));

        if (orgResponse.isSuccess) {
          final orgJson = json.decode(orgResponse.body);
          
          setState(() {
            organizationData = orgJson;
          });
        } else {
          if (userJson['organization'] != null) {
            setState(() {
              organizationData = userJson['organization'];
            });
          }
        }

        setState(() => isLoading = false);
        
      } else {
        setState(() {
          isLoading = false;
          errorMessage = userResponse.friendlyErrorMessage;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = ApiErrorHandler.handleNetworkException(e);
      });
    }
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

  void _editCompanyInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editar información de la empresa'),
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
                : organizationData == null
                    ? _buildEmptyOrganizationState()
                    : _buildProfileContent(isMobile),
      ),
    );
  }

  Widget _buildErrorState() {
    return ApiErrorHandler.buildErrorWidget(
      message: errorMessage,
      onRetry: _fetchAllCompanyData,
    );
  }

  Widget _buildEmptyOrganizationState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 80, color: Colors.blue[400]),
            SizedBox(height: 24),
            Text(
              '¡Bienvenido!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Completa la información de tu empresa para empezar',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/complete_org_profile');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              icon: Icon(Icons.business, color: Colors.white),
              label: Text('Crear Perfil Empresarial', style: TextStyle(color: Colors.white)),
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
                  _buildCompanyInfoCard(),
                  SizedBox(height: 12),
                  _buildCompanyDetailsCard(),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCompanyInfoCard()),
                      SizedBox(width: 24),
                      Expanded(child: _buildCompanyDetailsCard()),
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
    
    final companyName = organizationData?['trade_name'] ?? 
                        organizationData?['legal_name'] ?? 
                        'Empresa';
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D), width: 1),
        ),
      ),
      child: Row(
        children: [
          profileImageUrl != null && profileImageUrl!.isNotEmpty
              ? CircleAvatar(
                  radius: isVerySmall ? 22 : 26,
                  backgroundImage: NetworkImage(profileImageUrl!),
                  onBackgroundImageError: (exception, stackTrace) {},
                )
              : CircleAvatar(
                  radius: isVerySmall ? 22 : 26,
                  backgroundColor: Colors.blue[900],
                  child: Icon(
                    Icons.business,
                    color: Colors.blue[300],
                    size: isVerySmall ? 22 : 26,
                  ),
                ),
          SizedBox(width: isMobile ? 10 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  companyName,
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
                      if (organizationData?['org_type'] != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[900]!.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            organizationData!['org_type'].toString().toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue[300],
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
                onPressed: _editCompanyInfo,
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

  Widget _buildCompanyInfoCard() {
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
              Expanded(
                child: Text(
                  'Información de la empresa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.blue[400], size: 16),
                onPressed: _editCompanyInfo,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 18),
          
          if (organizationData?['legal_name'] != null) ...[
            _buildInfoLabel('RAZÓN SOCIAL'),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.business_outlined, color: Colors.blue[400], size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    organizationData!['legal_name'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),
          ],
          
          if (organizationData?['trade_name'] != null &&
              organizationData!['trade_name'] != organizationData!['legal_name']) ...[
            _buildInfoLabel('NOMBRE COMERCIAL'),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.store_outlined, color: Colors.purple[400], size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    organizationData!['trade_name'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),
          ],
          
          if (organizationData?['description'] != null) ...[
            _buildInfoLabel('DESCRIPCIÓN'),
            SizedBox(height: 6),
            Text(
              organizationData!['description'],
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 13,
                height: 1.4,
              ),
            ),
            SizedBox(height: 18),
          ],
          
          if (organizationData?['rfc'] != null) ...[
            _buildInfoLabel('RFC'),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.verified_outlined, color: Colors.green[400], size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    organizationData!['rfc'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompanyDetailsCard() {
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
          Text(
            'Datos adicionales',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 18),
          
          if (organizationData?['org_type'] != null) ...[
            Row(
              children: [
                Icon(Icons.category_outlined, color: Colors.grey[500], size: 14),
                SizedBox(width: 6),
                _buildInfoLabel('TIPO DE ORGANIZACIÓN'),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF30363D), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[900]!.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.business_center,
                      color: Colors.blue[300],
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      organizationData!['org_type'].toString().toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
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
                    _buildDateInfo(
                      'CREADA',
                      organizationData?['created_at'],
                      Icons.calendar_today_outlined,
                      Colors.green[400]!,
                    ),
                    SizedBox(height: 16),
                    _buildDateInfo(
                      'ACTUALIZADA',
                      organizationData?['updated_at'],
                      Icons.update_outlined,
                      Colors.blue[400]!,
                    ),
                  ],
                );
              }
              
              return Row(
                children: [
                  Expanded(
                    child: _buildDateInfo(
                      'CREADA',
                      organizationData?['created_at'],
                      Icons.calendar_today_outlined,
                      Colors.green[400]!,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildDateInfo(
                      'ACTUALIZADA',
                      organizationData?['updated_at'],
                      Icons.update_outlined,
                      Colors.blue[400]!,
                    ),
                  ),
                ],
              );
            },
          ),
          
          if (organizationData?['id'] != null) ...[
            SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.fingerprint, color: Colors.grey[500], size: 14),
                SizedBox(width: 6),
                _buildInfoLabel('ID DE ORGANIZACIÓN'),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF30363D), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.tag, color: Colors.grey[500], size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      organizationData!['id'].toString(),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, size: 14, color: Colors.grey[500]),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('ID copiado'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
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

  Widget _buildDateInfo(String label, String? dateString, IconData icon, Color color) {
    String formattedDate = 'N/A';
    
    if (dateString != null) {
      try {
        final date = DateTime.parse(dateString);
        formattedDate = '${date.day}/${date.month}/${date.year}';
      } catch (e) {
        formattedDate = dateString;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey[500], size: 13),
            SizedBox(width: 5),
            _buildInfoLabel(label),
          ],
        ),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Color(0xFF30363D), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 13),
              SizedBox(width: 5),
              Text(
                formattedDate,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}