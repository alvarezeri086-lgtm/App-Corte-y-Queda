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
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cerrar sesión',
                style: TextStyle(color: Colors.red[400])),
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

  // ── EDIT → PATCH /organizations/me ──────────────────────────────────────
  void _editCompanyInfo() {
    _showEditCompanySheet();
  }

  // ══════════════════════════════════════════════════════
  //  BOTTOM SHEET: Editar empresa
  //  PATCH /organizations/me
  // ══════════════════════════════════════════════════════

  static const _orgTypes = [
    'COMPANY',
    'AGENCY',
    'FREELANCER',
    'NON_PROFIT',
    'GOVERNMENT',
  ];

  void _showEditCompanySheet() {
    final rfcCtrl =
        TextEditingController(text: organizationData?['rfc'] ?? '');
    final legalCtrl =
        TextEditingController(text: organizationData?['legal_name'] ?? '');
    final tradeCtrl =
        TextEditingController(text: organizationData?['trade_name'] ?? '');
    final descCtrl =
        TextEditingController(text: organizationData?['description'] ?? '');
    final countryCtrl = TextEditingController(
        text: organizationData?['country_code'] ?? 'MX');

    final rawType =
        organizationData?['org_type']?.toString().toUpperCase();
    String? selectedOrgType =
        (rawType != null && _orgTypes.contains(rawType)) ? rawType : null;

    bool verificationBadge =
        organizationData?['verification_badge'] ?? false;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.92,
          decoration: BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFF30363D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
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
                      child: Icon(Icons.business_outlined,
                          color: Colors.blue[400], size: 18),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Editar empresa',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text('PATCH /organizations/me',
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
              // Form
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
                      // RFC
                      _sheetInputField(
                        controller: rfcCtrl,
                        label: 'RFC',
                        hint: 'ABC120101XY2',
                        icon: Icons.verified_outlined,
                        iconColor: Colors.green[400]!,
                      ),
                      SizedBox(height: 16),

                      // Tipo de organización
                      _sheetLabel('TIPO DE ORGANIZACIÓN'),
                      SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Color(0xFF30363D)),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: selectedOrgType,
                          dropdownColor: Color(0xFF1C2128),
                          style: TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.category_outlined,
                                color: Colors.grey[600], size: 18),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            hintText: 'Selecciona un tipo',
                            hintStyle: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                          items: _orgTypes
                              .map<DropdownMenuItem<String>>(
                                  (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t,
                                            style: TextStyle(
                                                color: Colors.white)),
                                      ))
                              .toList(),
                          onChanged: (val) => setSheetState(
                              () => selectedOrgType = val),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Razón social
                      _sheetInputField(
                        controller: legalCtrl,
                        label: 'RAZÓN SOCIAL',
                        hint: 'Servicios Logísticos S.A. de C.V.',
                        icon: Icons.business_outlined,
                        iconColor: Colors.blue[400]!,
                      ),
                      SizedBox(height: 16),

                      // Nombre comercial
                      _sheetInputField(
                        controller: tradeCtrl,
                        label: 'NOMBRE COMERCIAL',
                        hint: 'LogiStaff',
                        icon: Icons.store_outlined,
                        iconColor: Colors.purple[400]!,
                      ),
                      SizedBox(height: 16),

                      // País
                      _sheetInputField(
                        controller: countryCtrl,
                        label: 'CÓDIGO DE PAÍS',
                        hint: 'MX',
                        icon: Icons.flag_outlined,
                        iconColor: Colors.orange[400]!,
                      ),
                      SizedBox(height: 16),

                      // Descripción
                      _sheetInputField(
                        controller: descCtrl,
                        label: 'DESCRIPCIÓN',
                        hint: 'Describe tu empresa...',
                        icon: Icons.notes_outlined,
                        iconColor: Colors.grey[500]!,
                        maxLines: 4,
                      ),
                      SizedBox(height: 16),

                      // Verification badge
                      Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(0xFF30363D)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: verificationBadge
                                    ? Colors.blue[900]!
                                        .withOpacity(0.3)
                                    : Color(0xFF161B22),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.verified,
                                color: verificationBadge
                                    ? Colors.blue[400]
                                    : Colors.grey[600],
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Badge de verificación',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight.w500)),
                                  Text(
                                      'Indica si la empresa está verificada',
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            Switch(
                              value: verificationBadge,
                              onChanged: (val) => setSheetState(
                                  () => verificationBadge = val),
                              activeColor: Colors.blue[400],
                              inactiveThumbColor: Colors.grey[600],
                              inactiveTrackColor: Color(0xFF30363D),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 28),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  setSheetState(() => saving = true);
                                  final ok =
                                      await _saveCompanyInfo(
                                    rfc: rfcCtrl.text.trim(),
                                    orgType: selectedOrgType,
                                    legalName: legalCtrl.text.trim(),
                                    tradeName: tradeCtrl.text.trim(),
                                    countryCode:
                                        countryCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    verificationBadge:
                                        verificationBadge,
                                  );
                                  setSheetState(() => saving = false);
                                  if (ok && ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _fetchAllCompanyData();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            disabledBackgroundColor:
                                Colors.blue[900],
                            padding:
                                EdgeInsets.symmetric(vertical: 14),
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
                                    Icon(Icons.save_outlined,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Actualizar empresa',
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
        ),
      ),
    );
  }

  Future<bool> _saveCompanyInfo({
    required String rfc,
    required String? orgType,
    required String legalName,
    required String tradeName,
    required String countryCode,
    required String description,
    required bool verificationBadge,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];
      if (token == null || baseUrl == null) return false;

      // PATCH: solo enviar campos no vacíos
      final body = <String, dynamic>{};
      if (rfc.isNotEmpty) body['rfc'] = rfc;
      if (orgType != null) body['org_type'] = orgType;
      if (legalName.isNotEmpty) body['legal_name'] = legalName;
      if (tradeName.isNotEmpty) body['trade_name'] = tradeName;
      if (countryCode.isNotEmpty) body['country_code'] = countryCode;
      if (description.isNotEmpty) body['description'] = description;
      body['verification_badge'] = verificationBadge;

      final request = http.Request(
        'PATCH',
        Uri.parse('$baseUrl/organizations/me'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(body);

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        _showSuccess('Empresa actualizada correctamente');
        return true;
      } else if (response.statusCode == 404) {
        _showError('No se encontró la organización.');
      } else if (response.statusCode == 422) {
        final err = json.decode(response.body);
        _showError('Error de validación: ${_parseValidationError(err)}');
      } else {
        _showError('Error al guardar (${response.statusCode})');
      }
      return false;
    } catch (e) {
      _showError('Error de conexión');
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _parseValidationError(Map<String, dynamic> errData) {
    try {
      final detail = errData['detail'] as List;
      return detail.map((e) => e['msg'] ?? '').join(', ');
    } catch (_) {
      return errData.toString();
    }
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

  Widget _sheetLabel(String text) {
    return Text(
      text,
      style: TextStyle(
          color: Colors.grey[400],
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4),
    );
  }

  Widget _sheetInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    Color? iconColor,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetLabel(label),
        SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            prefixIcon: icon != null
                ? Icon(icon, color: iconColor ?? Colors.grey[600], size: 18)
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

  // ══════════════════════════════════════════════════════
  //  BUILD (igual al original)
  // ══════════════════════════════════════════════════════

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
            Text('¡Bienvenido!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
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
                padding:
                    EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              icon: Icon(Icons.business, color: Colors.white),
              label: Text('Crear Perfil Empresarial',
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
                          padding: EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                Colors.blue[900]!.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            organizationData!['org_type']
                                .toString()
                                .toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue[300],
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
                icon: Icon(Icons.logout, color: Colors.red[400], size: 18),
                onPressed: _logout,
                tooltip: 'Cerrar sesión',
                padding: EdgeInsets.all(8),
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    color: Colors.blue[400], size: 18),
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
                      fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    color: Colors.blue[400], size: 16),
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
                Icon(Icons.business_outlined,
                    color: Colors.blue[400], size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    organizationData!['legal_name'],
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),
          ],
          if (organizationData?['trade_name'] != null &&
              organizationData!['trade_name'] !=
                  organizationData!['legal_name']) ...[
            _buildInfoLabel('NOMBRE COMERCIAL'),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.store_outlined,
                    color: Colors.purple[400], size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    organizationData!['trade_name'],
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
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
                  color: Colors.grey[300], fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 18),
          ],
          if (organizationData?['rfc'] != null) ...[
            _buildInfoLabel('RFC'),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.verified_outlined,
                    color: Colors.green[400], size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    organizationData!['rfc'],
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
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
                fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 18),
          if (organizationData?['org_type'] != null) ...[
            Row(children: [
              Icon(Icons.category_outlined,
                  color: Colors.grey[500], size: 14),
              SizedBox(width: 6),
              _buildInfoLabel('TIPO DE ORGANIZACIÓN'),
            ]),
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
                    child: Icon(Icons.business_center,
                        color: Colors.blue[300], size: 16),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      organizationData!['org_type']
                          .toString()
                          .toUpperCase(),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
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
                    _buildDateInfo('CREADA',
                        organizationData?['created_at'],
                        Icons.calendar_today_outlined, Colors.green[400]!),
                    SizedBox(height: 16),
                    _buildDateInfo('ACTUALIZADA',
                        organizationData?['updated_at'],
                        Icons.update_outlined, Colors.blue[400]!),
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
                          Colors.green[400]!)),
                  SizedBox(width: 12),
                  Expanded(
                      child: _buildDateInfo(
                          'ACTUALIZADA',
                          organizationData?['updated_at'],
                          Icons.update_outlined,
                          Colors.blue[400]!)),
                ],
              );
            },
          ),
          if (organizationData?['id'] != null) ...[
            SizedBox(height: 18),
            Row(children: [
              Icon(Icons.fingerprint, color: Colors.grey[500], size: 14),
              SizedBox(width: 6),
              _buildInfoLabel('ID DE ORGANIZACIÓN'),
            ]),
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
                          fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon:
                        Icon(Icons.copy, size: 14, color: Colors.grey[500]),
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
          letterSpacing: 0.5),
    );
  }

  Widget _buildDateInfo(
      String label, String? dateString, IconData icon, Color color) {
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
        Row(children: [
          Icon(icon, color: Colors.grey[500], size: 13),
          SizedBox(width: 5),
          _buildInfoLabel(label),
        ]),
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
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}