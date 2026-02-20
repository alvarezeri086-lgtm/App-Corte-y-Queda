import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'dart:convert';
import '../auth_provider.dart';
import 'package:dio/dio.dart' as dio_pkg;

class FreelancerDocumentUploadScreen extends StatefulWidget {
  final List<dynamic> existingDocuments;

  const FreelancerDocumentUploadScreen({
    Key? key,
    this.existingDocuments = const [],
  }) : super(key: key);

  @override
  State<FreelancerDocumentUploadScreen> createState() =>
      _FreelancerDocumentUploadScreenState();
}

class _FreelancerDocumentUploadScreenState
    extends State<FreelancerDocumentUploadScreen> {

  List<dynamic> uploadedDocuments = [];
  
  Map<String, File?> selectedFiles = {
    'ACTA_NACIMIENTO': null,
    'COMPROBANTE_DOMICILIO': null,
    'CURP': null,
    'CONSTANCIA_FISCAL': null,
    'ESTADO_CUENTA': null,
  };
  
  List<File?> ineFiles = [null, null];
  bool ineCombined = false;

  Map<String, String> documentTypeIds = {};

  bool isLoadingDocumentTypes = false;
  bool isUploading = false;

  final Color primaryBlue = const Color(0xFF2563EB);
  final Color darkBg = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);

  final Map<String, Map<String, dynamic>> documentInfo = {
    'ACTA_NACIMIENTO': {'title': 'Acta de Nacimiento', 'subtitle': 'Copia certificada', 'icon': Icons.description_rounded, 'code': 'ACTA_NACIMIENTO'},
    'COMPROBANTE_DOMICILIO': {'title': 'Comprobante domicilio', 'subtitle': 'No mayor a 3 meses', 'icon': Icons.home_rounded, 'code': 'COMPROBANTE_DOMICILIO'},
    'CURP': {'title': 'CURP', 'subtitle': 'Formato actualizado', 'icon': Icons.badge_rounded, 'code': 'CURP'},
    'CONSTANCIA_FISCAL': {'title': 'Constancia Fiscal', 'subtitle': 'No mayor a 3 meses', 'icon': Icons.assignment_rounded, 'code': 'CONSTANCIA_FISCAL'},
    'ESTADO_CUENTA': {'title': 'Estado de Cuenta', 'subtitle': 'No mayor a 3 meses', 'icon': Icons.account_balance_rounded, 'code': 'ESTADO_CUENTA'},
  };

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Deduplicar documentos al cargar para evitar mostrar duplicados
    uploadedDocuments = _deduplicateDocuments(List.from(widget.existingDocuments));
    _loadDocumentTypes();
  }

  // ✅ FIX: Deduplica documentos por tipo — conserva solo el más reciente por código
  List<dynamic> _deduplicateDocuments(List<dynamic> docs) {
    final Map<String, dynamic> seen = {};
    for (var doc in docs) {
      final code = doc['document_type']?['code']?.toString() ?? doc['id'].toString();
      // Para INE se permiten máximo 2 (frente y reverso)
      if (code == 'INE') continue;
      seen[code] = doc;
    }
    // Agregar los INE por separado (máx 2)
    final ineList = docs.where((d) => d['document_type']?['code'] == 'INE').toList();
    final ineDeduped = ineList.length > 2 ? ineList.sublist(0, 2) : ineList;
    return [...seen.values.toList(), ...ineDeduped];
  }

  Future<void> _loadDocumentTypes() async {
    setState(() => isLoadingDocumentTypes = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final baseUrl = dotenv.env['API_BASE_URL'];
      
      final response = await http.get(
        Uri.parse('$baseUrl/documents/types/'),
        headers: {'Authorization': 'Bearer ${authProvider.accessToken}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> types = jsonDecode(response.body);
        for (var type in types) {
          documentTypeIds[type['code'] as String] = type['id'].toString();
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando tipos: $e');
    } finally {
      if (mounted) setState(() => isLoadingDocumentTypes = false);
    }
  }

  List<String> _getMissingDocuments() {
    List<String> missing = [];
    
    for (var entry in documentInfo.entries) {
      final code = entry.value['code'] as String;
      bool found = uploadedDocuments.any((doc) => 
        doc['document_type']?['code'] == code
      );
      if (!found) {
        missing.add(entry.value['title'] as String);
      }
    }
    
    // ✅ FIX: Solo pide INE si NO hay ninguno subido (no compara con 2)
    int ineCount = uploadedDocuments.where((doc) => 
      doc['document_type']?['code'] == 'INE'
    ).length;
    
    if (ineCount == 0) {
      missing.add('INE');
    }
    
    return missing;
  }

  Future<void> _uploadDocuments() async {
    bool hasAnyDocument = selectedFiles.values.any((file) => file != null) || ineFiles[0] != null;
    
    if (!hasAnyDocument) {
      _showErrorDialog('Debes seleccionar al menos un documento');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final baseUrl = dotenv.env['API_BASE_URL'];
    
    setState(() => isUploading = true);
    
    try {
      var dio = dio_pkg.Dio();
      dio.options.headers['Authorization'] = 'Bearer ${authProvider.accessToken}';
      var formData = dio_pkg.FormData();
      List<String> allTypeIds = [];
      
      for (var entry in selectedFiles.entries) {
        if (entry.value != null) {
          final typeId = documentTypeIds[entry.key];
          if (typeId != null) {
            formData.files.add(MapEntry(
              'files',
              await dio_pkg.MultipartFile.fromFile(
                entry.value!.path,
                filename: entry.value!.path.split('/').last,
              ),
            ));
            allTypeIds.add(typeId);
          }
        }
      }
      
      if (ineFiles[0] != null) {
        final ineTypeId = documentTypeIds['INE'];
        if (ineTypeId != null) {
          if (ineCombined) {
            // ✅ FIX: Con archivo combinado solo se sube UNA vez (era el bug de duplicados)
            formData.files.add(MapEntry(
              'files',
              await dio_pkg.MultipartFile.fromFile(
                ineFiles[0]!.path,
                filename: ineFiles[0]!.path.split('/').last,
              ),
            ));
            allTypeIds.add(ineTypeId);
          } else {
            // Frente del INE
            formData.files.add(MapEntry(
              'files',
              await dio_pkg.MultipartFile.fromFile(
                ineFiles[0]!.path,
                filename: ineFiles[0]!.path.split('/').last,
              ),
            ));
            allTypeIds.add(ineTypeId);
            // Reverso del INE (solo si existe)
            if (ineFiles[1] != null) {
              formData.files.add(MapEntry(
                'files',
                await dio_pkg.MultipartFile.fromFile(
                  ineFiles[1]!.path,
                  filename: ineFiles[1]!.path.split('/').last,
                ),
              ));
              allTypeIds.add(ineTypeId);
            }
          }
        }
      }
      
      for (var typeId in allTypeIds) {
        formData.fields.add(MapEntry('document_type_ids', typeId));
      }
      
      final response = await dio.post(
        '$baseUrl/documents/freelancer/upload-multiple',
        data: formData,
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (response.data['successful_uploads'] != null) {
          setState(() {
            final newDocs = List<dynamic>.from(response.data['successful_uploads']);
            uploadedDocuments.addAll(newDocs);
            // ✅ Deduplicar después de agregar
            uploadedDocuments = _deduplicateDocuments(uploadedDocuments);
            // Limpiar archivos seleccionados
            selectedFiles.updateAll((key, value) => null);
            ineFiles = [null, null];
            ineCombined = false;
          });
        }
        
        _showSuccessSnack('Documentos guardados correctamente');
        await authProvider.refreshUserInfo();
      }
    } on dio_pkg.DioException catch (e) {
      debugPrint('❌ Error upload: ${e.response?.data}');
      _showErrorDialog('Error al guardar los documentos');
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> _updateDocument(String documentId, String documentName) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      if (result == null || result.files.single.path == null) return;
      
      final file = File(result.files.single.path!);
      final fileSize = await file.length();
      
      if (fileSize > 10 * 1024 * 1024) {
        _showErrorSnack('Archivo muy grande (máx 10MB)');
        return;
      }
      
      setState(() => isUploading = true);
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final baseUrl = dotenv.env['API_BASE_URL'];
      
      var dio = dio_pkg.Dio();
      var formData = dio_pkg.FormData.fromMap({
        'file': await dio_pkg.MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });
      
      final response = await dio.put(
        '$baseUrl/documents/freelancer/$documentId/file',
        data: formData,
        options: dio_pkg.Options(
          headers: {'Authorization': 'Bearer ${authProvider.accessToken}'},
        ),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          final index = uploadedDocuments.indexWhere((d) => d['id'] == documentId);
          if (index != -1) {
            uploadedDocuments[index] = response.data;
          }
        });
        
        _showSuccessSnack('Documento actualizado');
        await authProvider.refreshUserInfo();
      }
    } on dio_pkg.DioException catch (e) {
      debugPrint('❌ Error update: ${e.response?.data}');
      _showErrorDialog('Error al actualizar');
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> _deleteDocument(String documentId, String documentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text('Eliminar documento', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
          ],
        ),
        content: Text('¿Eliminar "$documentName"?\n\nEsta acción no se puede deshacer.', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => isUploading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final baseUrl = dotenv.env['API_BASE_URL'];
      
      var dio = dio_pkg.Dio();
      await dio.delete(
        '$baseUrl/documents/freelancer/$documentId',
        options: dio_pkg.Options(
          headers: {'Authorization': 'Bearer ${authProvider.accessToken}'},
        ),
      );
      
      setState(() {
        uploadedDocuments.removeWhere((d) => d['id'] == documentId);
      });
      
      _showSuccessSnack('Documento eliminado');
      await authProvider.refreshUserInfo();
    } on dio_pkg.DioException catch (e) {
      debugPrint('❌ Error delete: ${e.response?.data}');
      _showErrorDialog('Error al eliminar');
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> _pickINE() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          final fileSize = await File(file.path!).length();
          if (fileSize > 10 * 1024 * 1024) {
            _showErrorSnack('Archivo muy grande (máx 10MB)');
            return;
          }
        }

        setState(() {
          if (result.files.length == 1) {
            ineFiles[0] = File(result.files.first.path!);
            ineFiles[1] = null;
            ineCombined = true;
          } else {
            ineFiles[0] = File(result.files[0].path!);
            ineFiles[1] = File(result.files[1].path!);
            ineCombined = false;
          }
        });

        _showSuccessSnack('INE seleccionado');
      }
    } catch (e) {
      _showErrorSnack('Error al seleccionar archivo');
    }
  }

  void _removeINE() => setState(() { ineFiles = [null, null]; ineCombined = false; });

  Future<void> _pickFile(String code) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if ((await file.length()) > 10 * 1024 * 1024) {
          _showErrorSnack('El archivo supera el límite de 10MB');
          return;
        }
        setState(() => selectedFiles[code] = file);
        _showSuccessSnack('Archivo seleccionado');
      }
    } catch (e) {
      _showErrorSnack('Error al seleccionar archivo');
    }
  }

  void _removeFile(String code) => setState(() => selectedFiles[code] = null);
  bool _canSave() => selectedFiles.values.any((file) => file != null) || ineFiles[0] != null;

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.error_rounded, color: Colors.red[400], size: 20),
          const SizedBox(width: 8),
          const Text('Error', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido', style: TextStyle(color: Color(0xFF2563EB))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final padding = isMobile ? 12.0 : 16.0;
    
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: isMobile ? 22 : 24),
          onPressed: () => Navigator.pop(context, uploadedDocuments.isNotEmpty),
        ),
        title: Text(
          'Verificación de identidad',
          style: TextStyle(color: Colors.white, fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: isLoadingDocumentTypes
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : uploadedDocuments.isNotEmpty
              ? _buildMixedView(isMobile, padding)
              : _buildUploadForm(isMobile, padding),
    );
  }

  // ──────────────────────────────────────────────────────────
  // FORMULARIO INICIAL (sin documentos subidos)
  // ──────────────────────────────────────────────────────────
  Widget _buildUploadForm(bool isMobile, double padding) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(padding),
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 8 : 10),
                      decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.verified_rounded, color: primaryBlue, size: isMobile ? 20 : 24),
                    ),
                    SizedBox(width: isMobile ? 10 : 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Documentos requeridos', style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Solo archivos PDF', style: TextStyle(color: Colors.white70, fontSize: isMobile ? 11 : 12)),
                    ])),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 10 : 12),
              ...documentInfo.entries.map((e) => _buildDocCard(e.key, e.value, isMobile)).toList(),
              _buildINECard(isMobile),
              SizedBox(height: isMobile ? 80 : 90),
            ],
          ),
        ),
        // ✅ BOTONES MEJORADOS
        _buildBottomBar(isMobile),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // ✅ BOTTOM BAR CON DISEÑO MEJORADO
  // ──────────────────────────────────────────────────────────
  Widget _buildBottomBar(bool isMobile, {bool showOnlyContinue = false, bool hasAll = false}) {
    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 20, 14, isMobile ? 16 : 20, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: showOnlyContinue
            ? SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (!isUploading && _canSave())
                      ? _uploadDocuments
                      : (hasAll && !isUploading ? () => Navigator.pop(context, true) : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF334155),
                    disabledForegroundColor: Colors.white38,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isUploading
                      ? _loadingRow('Guardando...')
                      : Text(
                          _canSave() ? 'Guardar documentos' : 'Continuar',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                        ),
                ),
              )
            : Row(
                children: [
                  // Botón Cancelar
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: isUploading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        disabledForegroundColor: Colors.white24,
                        side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: isMobile ? 17 : 19),
                          const SizedBox(width: 6),
                          Text('Cancelar', style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 10 : 14),
                  // Botón Guardar
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_canSave() && !isUploading) ? _uploadDocuments : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF334155),
                          disabledForegroundColor: Colors.white38,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isUploading
                            ? _loadingRow('Guardando...')
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_rounded, size: isMobile ? 17 : 19),
                                  const SizedBox(width: 8),
                                  Text('Guardar', style: TextStyle(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _loadingRow(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDocCard(String code, Map<String, dynamic> info, bool isMobile) {
    final isSelected = selectedFiles[code] != null;
    final fileName = isSelected ? selectedFiles[code]!.path.split('/').last : '';
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? primaryBlue : Colors.white.withOpacity(0.06), width: 1.5),
      ),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          child: Row(children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(info['icon'] as IconData, color: primaryBlue, size: isMobile ? 16 : 18),
            ),
            SizedBox(width: isMobile ? 8 : 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info['title'] as String, style: TextStyle(color: Colors.white, fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(info['subtitle'] as String, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
          ]),
        ),
        if (isSelected)
          Container(
            margin: EdgeInsets.fromLTRB(isMobile ? 10 : 12, 0, isMobile ? 10 : 12, isMobile ? 10 : 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: () => _removeFile(code),
                child: Icon(Icons.close_rounded, color: Colors.red[400], size: 17),
              ),
            ]),
          )
        else
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 10 : 12, 0, isMobile ? 10 : 12, isMobile ? 10 : 12),
            child: InkWell(
              onTap: () => _pickFile(code),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: darkBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryBlue.withOpacity(0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.upload_rounded, color: primaryBlue, size: isMobile ? 16 : 17),
                  const SizedBox(width: 6),
                  Text('Seleccionar PDF', style: TextStyle(color: primaryBlue, fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildINECard(bool isMobile) {
    final hasFile = ineFiles[0] != null;
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasFile ? primaryBlue : Colors.white.withOpacity(0.06), width: 1.5),
      ),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          child: Row(children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.credit_card_rounded, color: primaryBlue, size: isMobile ? 16 : 18),
            ),
            SizedBox(width: isMobile ? 8 : 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('INE', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(
                hasFile ? (ineCombined ? '1 PDF (ambos lados)' : 'Frente y reverso') : 'Ambos lados del INE',
                style: TextStyle(color: hasFile ? primaryBlue : Colors.white60, fontSize: 11),
              ),
            ])),
          ]),
        ),
        if (hasFile)
          Container(
            margin: EdgeInsets.fromLTRB(isMobile ? 10 : 12, 0, isMobile ? 10 : 12, isMobile ? 10 : 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text(ineFiles[0]!.path.split('/').last, style: const TextStyle(color: Colors.white, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: _removeINE,
                child: Icon(Icons.close_rounded, color: Colors.red[400], size: 17),
              ),
            ]),
          )
        else
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 10 : 12, 0, isMobile ? 10 : 12, isMobile ? 10 : 12),
            child: InkWell(
              onTap: _pickINE,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: darkBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryBlue.withOpacity(0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.upload_rounded, color: primaryBlue, size: isMobile ? 16 : 17),
                  const SizedBox(width: 6),
                  Text('Seleccionar INE', style: TextStyle(color: primaryBlue, fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────
  // ✅ VISTA MIXTA CORREGIDA
  // ──────────────────────────────────────────────────────────
  Widget _buildMixedView(bool isMobile, double padding) {
    final missing = _getMissingDocuments();
    final hasAll = missing.isEmpty;

    // ✅ FIX: Determinar si el INE ya está subido para NO mostrar el card de subida
    final ineAlreadyUploaded = uploadedDocuments.any((doc) =>
      doc['document_type']?['code'] == 'INE'
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(padding),
            children: [
              // Banner de estado
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasAll
                        ? [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.05)]
                        : [Colors.orange.withOpacity(0.15), Colors.orange.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasAll ? Colors.green.withOpacity(0.35) : Colors.orange.withOpacity(0.35),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasAll ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasAll ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        color: hasAll ? Colors.green : Colors.orange,
                        size: isMobile ? 22 : 26,
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          hasAll ? 'Documentos completos' : 'Documentos incompletos',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasAll
                              ? '${uploadedDocuments.length} documentos guardados'
                              : 'Faltan ${missing.length} documento${missing.length > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),

              // ✅ Lista de documentos faltantes
              if (!hasAll) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.info_outline, color: Colors.orange[400], size: 16),
                        const SizedBox(width: 8),
                        Text('Pendientes:', style: TextStyle(color: Colors.orange[400], fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 8),
                      ...missing.map((docName) => Padding(
                        padding: const EdgeInsets.only(left: 24, top: 4),
                        child: Row(children: [
                          Icon(Icons.circle, color: Colors.orange[400], size: 5),
                          const SizedBox(width: 8),
                          Text(docName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                      )),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Documentos ya subidos
              ...uploadedDocuments.map((doc) => _buildUploadedDocCard(doc, isMobile)).toList(),

              // ✅ FIX: Sección para subir faltantes (excluye los ya subidos y el INE si ya existe)
              if (!hasAll) ...[
                SizedBox(height: isMobile ? 12 : 16),
                Text(
                  'Sube los documentos faltantes:',
                  style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),

                // Solo muestra cards de los documentos que realmente faltan
                ...documentInfo.entries.where((entry) {
                  final code = entry.value['code'] as String;
                  return !uploadedDocuments.any((doc) => doc['document_type']?['code'] == code);
                }).map((entry) => _buildDocCard(entry.key, entry.value, isMobile)).toList(),

                // ✅ FIX: Solo muestra INE si NO hay ninguno subido
                if (!ineAlreadyUploaded) _buildINECard(isMobile),
              ],

              SizedBox(height: isMobile ? 70 : 80),
            ],
          ),
        ),

        // ✅ Botón inferior mejorado
        _buildBottomBar(isMobile, showOnlyContinue: true, hasAll: hasAll),
      ],
    );
  }

  Widget _buildUploadedDocCard(dynamic doc, bool isMobile) {
    final docId = doc['id']?.toString() ?? '';
    final docType = doc['document_type'];
    final docName = docType?['name'] ?? docType?['code'] ?? 'Documento';
    final fileName = doc['file_name'] ?? doc['file_path']?.toString().split('/').last ?? 'archivo.pdf';

    IconData icon = Icons.description_rounded;
    documentInfo.forEach((key, info) {
      if (info['code'] == docType?['code']) {
        icon = info['icon'] as IconData;
      }
    });
    if (docType?['code'] == 'INE') icon = Icons.credit_card_rounded;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.25), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 7 : 9),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: Colors.green[400], size: isMobile ? 18 : 20),
            ),
            SizedBox(width: isMobile ? 10 : 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(docName, style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(fileName, style: const TextStyle(color: Colors.white60, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            // Botón editar
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isUploading ? null : () => _updateDocument(docId, docName),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 7 : 8),
                  child: Icon(Icons.edit_rounded, size: isMobile ? 18 : 20, color: primaryBlue),
                ),
              ),
            ),
            const SizedBox(width: 2),
            // Botón eliminar
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isUploading ? null : () => _deleteDocument(docId, docName),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 7 : 8),
                  child: Icon(Icons.delete_outline_rounded, size: isMobile ? 18 : 20, color: Colors.red[400]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}