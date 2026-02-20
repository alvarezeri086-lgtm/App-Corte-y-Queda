import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import '../auth_provider.dart';
import 'entrevista.dart';

class CandidatesScreen extends StatefulWidget {
  final String positionId;
  final String organizationId;
  final String activationId;
  final double payRate;
  final String currency;

  const CandidatesScreen({
    Key? key,
    required this.positionId,
    required this.organizationId,
    required this.activationId,
    required this.payRate,
    required this.currency,
  }) : super(key: key);

  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends State<CandidatesScreen> {
  Map<String, dynamic>? positionDetails;
  List<Candidate> candidates = [];
  List<Candidate> sentCandidates = [];
  List<Candidate> selectedCandidates = [];
  String fillStage = '';
  bool isLoading = true;
  bool isSendingActivation = false;
  String? error;
  
  Map<String, InterviewDetails> _interviewDetailsCache = {};
  Timer? _autoRefreshTimer;

  List<String> _requiredRoles = [];
  List<String> _requiredTags = [];
  List<String> _requiredEquipment = [];
  
  List<String> _requiredRoleIds = [];
  List<String> _requiredTagIds = [];
  List<String> _requiredEquipmentIds = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final hasPendingInterviews = sentCandidates.any((c) {
        final status = c.interviewStatus?.toUpperCase();
        return status == 'PENDING_FREELANCER_ACCEPT' || 
               status == 'PENDING_SCHEDULE' ||
               status == 'PROPOSED' ||
               status == 'FREELANCER_REJECTED';
      });
      
      if (hasPendingInterviews && mounted) {
        _loadData(silent: true);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    
    if (!silent) {
      setState(() {
        isLoading = true;
        error = null;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];

      if (token == null || baseUrl == null) {
        throw Exception('No hay token de autenticacion');
      }

      final positionResponse = await http.get(
        Uri.parse('$baseUrl/positions/${widget.positionId}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (positionResponse.statusCode == 200) {
        final posData = json.decode(positionResponse.body);
        positionDetails = posData;

        _requiredRoles = [];
        _requiredRoleIds = [];
        
        if (posData['roles'] != null) {
          if (posData['roles'] is List) {
            final rolesList = posData['roles'] as List;
            for (var role in rolesList) {
              if (role is Map) {
                if (role['name'] != null) {
                  _requiredRoles.add(role['name'].toString());
                }
                if (role['id'] != null) {
                  _requiredRoleIds.add(role['id'].toString());
                }
              } else {
                _requiredRoles.add(role.toString());
              }
            }
          }
        } else if (posData['role_name'] != null) {
          _requiredRoles = [posData['role_name'].toString()];
        }

        _requiredTags = [];
        _requiredTagIds = [];
        _requiredEquipment = [];
        _requiredEquipmentIds = [];
        
        if (posData['activation_candidates'] != null && posData['activation_candidates'] is List) {
          final candidatesList = posData['activation_candidates'] as List;
          
          for (var candidateData in candidatesList) {
            if (candidateData is Map) {
              if (candidateData['match_summary'] != null) {
                final summary = candidateData['match_summary'] as Map;
                
                if (summary['tags_required'] != null) {
                  final tagsRequired = summary['tags_required'];
                  if (tagsRequired is int && tagsRequired > 0) {
                    if (summary['tags_required_details'] != null && summary['tags_required_details'] is List) {
                      final tagsDetails = summary['tags_required_details'] as List;
                      for (var tagDetail in tagsDetails) {
                        if (tagDetail is Map && tagDetail['name'] != null) {
                          _requiredTags.add(tagDetail['name'].toString());
                          if (tagDetail['id'] != null) {
                            _requiredTagIds.add(tagDetail['id'].toString());
                          }
                        }
                      }
                    }
                    
                    if (_requiredTags.isEmpty) {
                      for (int i = 0; i < tagsRequired; i++) {
                        _requiredTags.add('Habilidad ${i + 1}');
                      }
                    }
                  }
                }
                
                if (summary['equipment_required'] != null) {
                  final equipRequired = summary['equipment_required'];
                  if (equipRequired is int && equipRequired > 0) {
                    if (summary['equipment_required_details'] != null && summary['equipment_required_details'] is List) {
                      final equipDetails = summary['equipment_required_details'] as List;
                      for (var equipDetail in equipDetails) {
                        if (equipDetail is Map && equipDetail['name'] != null) {
                          _requiredEquipment.add(equipDetail['name'].toString());
                          if (equipDetail['id'] != null) {
                            _requiredEquipmentIds.add(equipDetail['id'].toString());
                          }
                        }
                      }
                    }
                    
                    if (_requiredEquipment.isEmpty) {
                      for (int i = 0; i < equipRequired; i++) {
                        _requiredEquipment.add('Equipo ${i + 1}');
                      }
                    }
                  }
                }
                
                if (_requiredTags.isNotEmpty || _requiredEquipment.isNotEmpty) {
                  break;
                }
              }
            }
          }
        }

        if ((_requiredTags.isEmpty || _requiredEquipment.isEmpty)) {
          final candidatesResponse = await http.get(
            Uri.parse('$baseUrl/positions/${widget.positionId}/candidates?limit=50'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 30));

          if (candidatesResponse.statusCode == 200) {
            final data = json.decode(candidatesResponse.body);
            List<dynamic> candidatesList = [];
            
            if (data is Map<String, dynamic>) {
              if (data['candidates'] != null && data['candidates'] is List) {
                candidatesList = data['candidates'] as List;
              }
            } else if (data is List) {
              candidatesList = data;
            }
            
            if (candidatesList.isNotEmpty) {
              Map<String, int> tagFrequency = {};
              Map<String, int> equipFrequency = {};
              
              for (var candidateJson in candidatesList.take(5)) {
                if (candidateJson is Map) {
                  if (candidateJson['breakdown'] is Map) {
                    final breakdown = candidateJson['breakdown'] as Map;
                    
                    if (breakdown['tags'] is Map) {
                      final tagsData = breakdown['tags'] as Map;
                      if (tagsData['required'] is List) {
                        final requiredTags = tagsData['required'] as List;
                        for (var tag in requiredTags) {
                          String tagName = tag is Map && tag['name'] != null 
                              ? tag['name'].toString() 
                              : tag.toString();
                          tagFrequency[tagName] = (tagFrequency[tagName] ?? 0) + 1;
                        }
                      }
                    }
                    
                    if (breakdown['equipment'] is Map) {
                      final equipData = breakdown['equipment'] as Map;
                      if (equipData['required'] is List) {
                        final requiredEquip = equipData['required'] as List;
                        for (var equip in requiredEquip) {
                          String equipName = equip is Map && equip['name'] != null 
                              ? equip['name'].toString() 
                              : equip.toString();
                          equipFrequency[equipName] = (equipFrequency[equipName] ?? 0) + 1;
                        }
                      }
                    }
                  }
                }
              }
              
              if (_requiredTags.isEmpty && tagFrequency.isNotEmpty) {
                var sortedTags = tagFrequency.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                _requiredTags = sortedTags.take(3).map((e) => e.key).toList();
              }
              
              if (_requiredEquipment.isEmpty && equipFrequency.isNotEmpty) {
                var sortedEquip = equipFrequency.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                _requiredEquipment = sortedEquip.take(2).map((e) => e.key).toList();
              }
            }
          }
        }

        if (_requiredRoles.isEmpty) {
          _requiredRoles = ['Rol Principal'];
        }
        if (_requiredTags.isEmpty) {
          _requiredTags = ['Habilidad 1', 'Habilidad 2', 'Habilidad 3'];
        }
        if (_requiredEquipment.isEmpty) {
          _requiredEquipment = ['Equipo 1', 'Equipo 2'];
        }

        Map<String, dynamic>? positionInterview;
        if (posData['interview'] != null && posData['interview'] is Map) {
          positionInterview = posData['interview'] as Map<String, dynamic>;
        }

        if (posData['activation_candidates'] != null &&
            posData['activation_candidates'] is List) {
          final candidatesList = posData['activation_candidates'] as List;
          sentCandidates = candidatesList
              .map((c) => Candidate.fromActivationJson(
                  c as Map<String, dynamic>, 
                  positionInterview: positionInterview))
              .toList();
        }

        fillStage = posData['fill_stage']?.toString() ?? '';
      }

      final candidatesResponse = await http.get(
        Uri.parse('$baseUrl/positions/${widget.positionId}/candidates?limit=50'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (candidatesResponse.statusCode == 200) {
        final data = json.decode(candidatesResponse.body);
        List<Candidate> candidatesList = [];

        if (data is Map<String, dynamic>) {
          if (data['fill_stage'] != null && fillStage.isEmpty) {
            fillStage = data['fill_stage'].toString();
          }
          if (data['candidates'] != null && data['candidates'] is List) {
            final rawList = data['candidates'] as List;
            candidatesList = rawList
                .cast<Map<String, dynamic>>()
                .map((c) => Candidate.fromCandidateJson(c))
                .toList();
          }
        } else if (data is List) {
          candidatesList = data
              .cast<Map<String, dynamic>>()
              .map((c) => Candidate.fromCandidateJson(c))
              .toList();
        }

        candidatesList.sort((a, b) => b.matchScore.compareTo(a.matchScore));
        candidatesList = candidatesList.where((c) => c.matchScore > 0).toList();

        if (mounted) {
          setState(() {
            candidates = candidatesList;
            if (!silent) isLoading = false;
          });
          
          final hasPending = sentCandidates.any((c) {
            final status = c.interviewStatus?.toUpperCase();
            return status == 'PENDING_FREELANCER_ACCEPT' || 
                   status == 'PENDING_SCHEDULE' ||
                   status == 'PROPOSED' ||
                   status == 'FREELANCER_REJECTED';
          });
          
          if (hasPending) {
            _startAutoRefresh();
          }
        }
      } else if (candidatesResponse.statusCode == 401) {
        await authProvider.logout();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        throw Exception('Error al cargar candidatos: ${candidatesResponse.statusCode}');
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _sendActivation() async {
    if (selectedCandidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un candidato'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2942),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Confirmar envío', style: TextStyle(color: Colors.white)),
          content: Text(
            '¿Enviar posición a ${selectedCandidates.length} candidato${selectedCandidates.length > 1 ? 's' : ''}?',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Enviar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      isSendingActivation = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;
    final baseUrl = dotenv.env['API_BASE_URL'];

    if (token == null || baseUrl == null) {
      setState(() => isSendingActivation = false);
      return;
    }

    final candidate = selectedCandidates.first;
    try {
      final payloadA = {
        'freelancer_id': candidate.id,
        'window_minutes': 180,
        'allow_any_stage': false,
      };

      final responseA = await http
          .post(
            Uri.parse('$baseUrl/positions/${widget.positionId}/send'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(payloadA),
          )
          .timeout(const Duration(seconds: 30));

      if (responseA.statusCode == 200 || responseA.statusCode == 201) {
        if (mounted) {
          setState(() => isSendingActivation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Posición enviada a ${candidate.shortId}'),
              backgroundColor: Colors.green,
            ),
          );
          selectedCandidates.clear();
          await _loadData();
        }
        return;
      }
      
      if (responseA.statusCode == 500) {
        final payloadB = {
          'freelancer_id': candidate.id,
          'rating_minutes': 60,
          'allow_any_time': false,
        };

        final responseB = await http
            .post(
              Uri.parse('$baseUrl/positions/${widget.positionId}/send'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: json.encode(payloadB),
            )
            .timeout(const Duration(seconds: 30));

        if (responseB.statusCode == 200 || responseB.statusCode == 201) {
          if (mounted) {
            setState(() => isSendingActivation = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Posición enviada a ${candidate.shortId}'),
                backgroundColor: Colors.green,
              ),
            );
            selectedCandidates.clear();
            await _loadData();
          }
          return;
        } else {
          if (mounted) {
            setState(() => isSendingActivation = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No se pudo enviar: ${responseB.statusCode}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        setState(() => isSendingActivation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar: ${responseA.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSendingActivation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleCandidateSelection(Candidate candidate) {
    setState(() {
      if (selectedCandidates.contains(candidate)) {
        selectedCandidates.clear();
      } else {
        selectedCandidates = [candidate];
      }
    });
  }

  String _getStageText(String stage) {
    switch (stage.toUpperCase()) {
      case 'LIST_READY':
        return 'LISTO PARA SELECCIONAR';
      case 'RED_RECOMMENDED':
         return 'RED RECOMENDADA';
      case 'RECOMMENDED_NETWORK':
        return 'RED RECOMENDADA';
      case 'RED_KNOWN':
          return 'RED CONOCIDA';
      case 'KNOWN_NETWORK':
        return 'RED CONOCIDA';
      case 'FILLED':
        return 'CUBIERTO';
      default:
        return stage;
    }
  }

  Color _getStageColor(String stage) {
    switch (stage.toUpperCase()) {
      case 'LIST_READY':
        return Colors.blue;
      case 'RED_RECOMMENDED':
      case 'RECOMMENDED_NETWORK':
        return Colors.green;
      case 'RED_KNOWN':
      case 'KNOWN_NETWORK':
        return Colors.orange;
      case 'FILLED':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 2000) return Colors.green;
    if (score >= 1500) return Colors.blue;
    if (score >= 1000) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String displayText;
    
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
      case 'ACCEPTED':
      case 'COVERED':
      case 'FILLED':
        color = Colors.green;
        displayText = 'CUBIERTO';
        break;
      case 'REJECTED':
      case 'DECLINED':
        color = Colors.red;
        displayText = 'RECHAZADO';
        break;
      case 'SENT':
      case 'PENDING':
      case 'PENDING_FREELANCER_ACCEPT':
        color = Colors.blue;
        displayText = 'ENVIADO';
        break;
      default:
        color = Colors.blue;
        displayText = status.toUpperCase();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        displayText,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getInterviewStatusColor(String? status) {
    if (status == null) return Colors.orange;
    
    switch (status.toUpperCase()) {
      case 'PENDING_FREELANCER_ACCEPT':
        return Colors.cyan;
      case 'PENDING_SCHEDULE':
        return Colors.blue;
      case 'PROPOSED':
        return Colors.orange;
      case 'FREELANCER_ACCEPTED':
      case 'ACCEPTED':
      case 'CONFIRMED':
      case 'COVERED':
      case 'COMPANY_ACCEPTED':
        return Colors.green;
      case 'FREELANCER_REJECTED':
        return Colors.red;
      case 'FAILED':
        return Colors.red;
      case 'SCHEDULED':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showConfigureInterviewDialog(Candidate candidate) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InterviewSchedulePage(
          interviewId: candidate.interviewId ?? '',
          activationId: candidate.id,
          candidateName: candidate.freelancerName ?? 'Candidato ${candidate.shortId}',
          candidateId: candidate.id,
        ),
      ),
    );
    
    if (result == true && mounted) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrevista configurada exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$day/$month/$year, $hour:$minute';
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatDate(DateTime date) {
    final months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 
                   'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'p.m.' : 'a.m.';
    final hour12 = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    return '$day/$month/$year, $hour12:$minute $period';
  }

  Future<InterviewDetails?> _loadInterviewDetails(Candidate candidate) async {
    try {
      if (_interviewDetailsCache.containsKey(candidate.interviewId)) {
        return _interviewDetailsCache[candidate.interviewId];
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];

      if (token == null || baseUrl == null) {
        return null;
      }

      InterviewDetails? interviewDetails;
      
      final positionResponse = await http.get(
        Uri.parse('$baseUrl/positions/${widget.positionId}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (positionResponse.statusCode == 200) {
        final positionData = json.decode(positionResponse.body);
        
        if (positionData['activation_candidates'] != null && positionData['activation_candidates'] is List) {
          final candidates = positionData['activation_candidates'] as List;
          
          final candidateData = candidates.firstWhere(
            (c) => c['id'] == candidate.id || c['freelancer_id'] == candidate.id,
            orElse: () => null,
          );
          
          if (candidateData != null) {
            if (candidateData['interview'] != null) {
              final interviewData = candidateData['interview'];
              interviewDetails = InterviewDetails.fromJson(interviewData);
            }
          }
        }
        
        if (interviewDetails == null && positionData['interview'] != null) {
          interviewDetails = InterviewDetails.fromJson(positionData['interview']);
        }
      }

      if (interviewDetails == null && candidate.interviewId != null && candidate.interviewId!.isNotEmpty) {
        final orgResponse = await http.get(
          Uri.parse('$baseUrl/interviews/organization'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));

        if (orgResponse.statusCode == 200) {
          final orgData = json.decode(orgResponse.body);
          
          if (orgData is List) {
            final interviewData = orgData.firstWhere(
              (e) => e['id'] == candidate.interviewId,
              orElse: () => null,
            );
            
            if (interviewData != null) {
              interviewDetails = InterviewDetails.fromInterviewJson(interviewData);
            }
          }
          else if (orgData['data'] != null) {
            if (orgData['data'] is List) {
              final interviewData = (orgData['data'] as List).firstWhere(
                (e) => e['id'] == candidate.interviewId,
                orElse: () => null,
              );
              
              if (interviewData != null) {
                interviewDetails = InterviewDetails.fromInterviewJson(interviewData);
              }
            } else if (orgData['data']['events'] != null && orgData['data']['events'] is List) {
              final interviewData = (orgData['data']['events'] as List).firstWhere(
                (e) => e['id'] == candidate.interviewId,
                orElse: () => null,
              );
              
              if (interviewData != null) {
                interviewDetails = InterviewDetails.fromInterviewJson(interviewData);
              }
            }
          }
        }
      }

      if (interviewDetails != null && candidate.interviewId != null) {
        _interviewDetailsCache[candidate.interviewId!] = interviewDetails;
      }

      return interviewDetails;
      
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleAcceptCandidate(Candidate candidate) async {
    if (candidate.interviewStatus?.toUpperCase() == 'FAILED') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede aceptar: la entrevista tiene estado FAILED'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2942),
        title: const Text('Aceptar Candidato', style: TextStyle(color: Colors.white)),
        content: const Text('¿Confirmar al candidato para esta posición?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Aceptar', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];

      if (token == null || baseUrl == null) {
        throw Exception('No hay token');
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/interviews/${candidate.interviewId}/decision'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'action': 'ACCEPT',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Candidato aceptado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadData();
        }
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleRejectCandidate(Candidate candidate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2942),
        title: const Text('Rechazar Candidato', style: TextStyle(color: Colors.white)),
        content: const Text('¿Está seguro de que desea rechazar este candidato?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];

      if (token == null || baseUrl == null) {
        throw Exception('No hay token');
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/interviews/${candidate.interviewId}/decision'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'action': 'REJECT',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Candidato rechazado'),
              backgroundColor: Colors.orange,
            ),
          );
          await _loadData();
        }
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al rechazar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  int _calculateRolePercentage(Candidate candidate) {
    if (_requiredRoles.isEmpty) return 0;
    
    int matches = 0;
    
    if (_requiredRoleIds.isNotEmpty && candidate.roleId != null) {
      if (_requiredRoleIds.contains(candidate.roleId)) {
        matches++;
      }
    } else {
      for (var requiredRole in _requiredRoles) {
        if (candidate.roleName?.toLowerCase().contains(requiredRole.toLowerCase()) == true) {
          matches++;
          break;
        } else if (candidate.roleScore > 0) {
          matches++;
          break;
        }
      }
    }
    
    if (candidate.roleScore > 0 && matches == 0) {
      matches = 1;
    }
    
    return ((matches / _requiredRoles.length) * 100).round();
  }

  int _calculateTagPercentage(Candidate candidate) {
    if (_requiredTags.isEmpty) return 0;
    
    if (candidate.tagMatchCount > 0) {
      int matches = candidate.tagMatchCount.clamp(0, _requiredTags.length);
      return ((matches / _requiredTags.length) * 100).round();
    }
    
    if (candidate.tags.isEmpty) {
      return 0;
    }
    
    int matches = 0;
    Set<String> matchedTags = {};
    
    for (var requiredTag in _requiredTags) {
      for (var candidateTag in candidate.tags) {
        String requiredLower = requiredTag.toLowerCase();
        String candidateLower = candidateTag.toLowerCase();
        
        if (candidateLower.contains(requiredLower) || 
            requiredLower.contains(candidateLower) ||
            candidateLower == requiredLower) {
          if (!matchedTags.contains(requiredTag)) {
            matches++;
            matchedTags.add(requiredTag);
            break;
          }
        }
      }
    }
    
    return ((matches / _requiredTags.length) * 100).round();
  }

  int _calculateEquipmentPercentage(Candidate candidate) {
    if (_requiredEquipment.isEmpty) return 0;
    
    if (candidate.equipmentMatchCount > 0) {
      int matches = candidate.equipmentMatchCount.clamp(0, _requiredEquipment.length);
      return ((matches / _requiredEquipment.length) * 100).round();
    }
    
    if (candidate.equipmentOk > 0) {
      int matches = candidate.equipmentOk.clamp(0, _requiredEquipment.length);
      return ((matches / _requiredEquipment.length) * 100).round();
    }
    
    return 0;
  }

  Widget _buildCompatibilitySection(Candidate candidate) {
    final rolePercentage = _calculateRolePercentage(candidate);
    final tagPercentage = _calculateTagPercentage(candidate);
    final equipmentPercentage = _calculateEquipmentPercentage(candidate);
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1620),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMPATIBILIDAD',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildCompatibilityRow(
            label: 'Roles (${_requiredRoles.length})',
            value: '$rolePercentage%',
            percentage: rolePercentage,
            matchedCount: candidate.roleScore > 0 ? candidate.roleScore : (rolePercentage > 0 ? 1 : 0),
            requiredCount: _requiredRoles.length,
          ),
          
          const SizedBox(height: 12),
          
          _buildCompatibilityRow(
            label: 'Habilidades (${_requiredTags.length})',
            value: '$tagPercentage%',
            percentage: tagPercentage,
            matchedCount: candidate.tagMatchCount,
            requiredCount: _requiredTags.length,
          ),
          
          const SizedBox(height: 12),
          
          _buildCompatibilityRow(
            label: 'Equipo (${_requiredEquipment.length})',
            value: '$equipmentPercentage%',
            percentage: equipmentPercentage,
            matchedCount: candidate.equipmentMatchCount,
            requiredCount: _requiredEquipment.length,
          ),
          
          if (candidate.matchScore > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars, color: Colors.amber[300], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Puntuación total: ${candidate.matchScore}',
                      style: TextStyle(
                        color: Colors.amber[300],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // VERSIÓN CORREGIDA: El botón RECHAZAR siempre visible
  Widget _buildActionButtons(Candidate candidate) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    final bool isCandidateConfirmed = 
        candidate.status?.toUpperCase() == 'FILLED' || 
        candidate.status?.toUpperCase() == 'COVERED' ||
        candidate.status?.toUpperCase() == 'ACCEPTED' ||
        candidate.status?.toUpperCase() == 'CONFIRMED';
    
    final bool isInterviewConfirmed = 
        candidate.interviewStatus?.toUpperCase() == 'COMPANY_ACCEPTED' ||
        candidate.interviewStatus?.toUpperCase() == 'CONFIRMED' ||
        candidate.interviewStatus?.toUpperCase() == 'ACCEPTED';
    
    final bool isAlreadyAccepted = isCandidateConfirmed || isInterviewConfirmed;
    
    return Column(
      children: [
        Row(
          children: [
            // Botón ACEPTAR - Solo visible si NO está ya aceptado
            if (!isAlreadyAccepted)
              Expanded(
                child: GestureDetector(
                  onTap: () => _handleAcceptCandidate(candidate),
                  child: Container(
                    height: isSmallScreen ? 48 : 56,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        isSmallScreen ? 'ACEPTAR' : 'ACEPTAR CANDIDATO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 13 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Espacio entre botones (solo si ambos están visibles)
            if (!isAlreadyAccepted) const SizedBox(width: 8),
            
            // Botón RECHAZAR - SIEMPRE VISIBLE
            Expanded(
              child: GestureDetector(
                onTap: () => _handleRejectCandidate(candidate),
                child: Container(
                  height: isSmallScreen ? 48 : 56,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      isSmallScreen ? 'RECHAZAR' : 'RECHAZAR',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // Mensaje informativo si ya fue aceptado
        if (isAlreadyAccepted)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Candidato aceptado',
                    style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInterviewProcess(Candidate candidate) {
    final bool isPendingFreelancerAccept = 
        candidate.interviewStatus?.toUpperCase() == 'PENDING_FREELANCER_ACCEPT';
    
    final bool needsScheduling = 
        candidate.interviewStatus?.toUpperCase() == 'PENDING_SCHEDULE';
    
    final bool isProposed = 
        candidate.interviewStatus?.toUpperCase() == 'PROPOSED';
    
    final _status = candidate.interviewStatus?.toUpperCase() ?? '';
    
    final bool isFreelancerAccepted =
      _status == 'FREELANCER_ACCEPTED' || 
      _status == 'ACCEPTED' || 
      _status == 'CONFIRMED' || 
      _status == 'COVERED' ||
      _status == 'COMPANY_ACCEPTED';
    
    final bool isCandidateConfirmed = 
        candidate.status?.toUpperCase() == 'CONFIRMED' || 
        candidate.status?.toUpperCase() == 'COVERED' ||
        candidate.status?.toUpperCase() == 'ACCEPTED' ||
        candidate.status?.toUpperCase() == 'FILLED';
    
    final bool isFreelancerRejected = 
        candidate.interviewStatus?.toUpperCase() == 'FREELANCER_REJECTED';
    
    final bool isFailed = candidate.interviewStatus?.toUpperCase() == 'FAILED';
    
    final bool canConfigureInterview = (needsScheduling || isFreelancerRejected) && !isFailed;
    final bool waitingForFreelancerResponse = isProposed && !isFailed;
    
    final bool interviewConfirmed = 
        (isFreelancerAccepted || candidate.companyAccepted || isCandidateConfirmed) && !isFailed;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1825),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: interviewConfirmed
              ? Colors.green.withOpacity(0.5)
              : isFailed
              ? Colors.red.withOpacity(0.5)
              : isPendingFreelancerAccept 
                  ? Colors.cyan.withOpacity(0.3)
                  : isFreelancerRejected
                  ? Colors.red.withOpacity(0.3)
                  : isProposed
                  ? Colors.orange.withOpacity(0.3)
                  : needsScheduling
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
          width: interviewConfirmed || isFailed ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: interviewConfirmed
                      ? Colors.green.withOpacity(0.15)
                      : isFailed
                      ? Colors.red.withOpacity(0.15)
                      : isFreelancerRejected
                      ? Colors.red.withOpacity(0.15)
                      : isProposed
                      ? Colors.orange.withOpacity(0.15)
                      : Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  interviewConfirmed ? Icons.check_circle :
                  isFailed ? Icons.error :
                  isFreelancerRejected ? Icons.cancel :
                  isProposed ? Icons.schedule :
                  Icons.calendar_today,
                  color: interviewConfirmed ? Colors.green :
                         isFailed ? Colors.red :
                         isFreelancerRejected ? Colors.red :
                         isProposed ? Colors.orange :
                         Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Proceso de Entrevista',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      interviewConfirmed ? 'CONFIRMADA' :
                      isFailed ? 'FALLIDA' :
                      isFreelancerRejected ? 'RECHAZADA POR CANDIDATO' :
                      isProposed ? 'HORARIO PROPUESTO' :
                      needsScheduling ? 'PENDIENTE AGENDAR' :
                      isPendingFreelancerAccept ? 'PENDIENTE ACEPTAR' :
                      'EN PROCESO',
                      style: TextStyle(
                        color: interviewConfirmed ? Colors.green :
                               isFailed ? Colors.red :
                               isFreelancerRejected ? Colors.red :
                               isProposed ? Colors.orange :
                               Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (interviewConfirmed) ...[
            FutureBuilder<InterviewDetails?>(
              future: _loadInterviewDetails(candidate),
              builder: (context, snapshot) {
                final details = snapshot.data;
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                
                if (isLoading) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                    ),
                  );
                }

                if (details != null) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (details.interviewType != null) ...[
                          _buildDetailRow(
                            icon: Icons.videocam,
                            color: Colors.blue,
                            label: 'TIPO',
                            value: details.interviewType! == 'ONLINE' ? 'EN LÍNEA' : 
                                   details.interviewType! == 'ONSITE' ? 'PRESENCIAL' : 
                                   details.interviewType!,
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        if (details.scheduledAt != null) ...[
                          _buildDetailRow(
                            icon: Icons.schedule,
                            color: Colors.orange,
                            label: 'FECHA Y HORA',
                            value: _formatDateTime(details.scheduledAt!),
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        if (details.onlineLink != null && details.onlineLink!.isNotEmpty) ...[
                          _buildDetailRow(
                            icon: Icons.link,
                            color: Colors.cyan,
                            label: 'ENLACE',
                            value: details.onlineLink!,
                            isLink: true,
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        if (details.onsiteAddress != null && details.onsiteAddress!.isNotEmpty) ...[
                          _buildDetailRow(
                            icon: Icons.location_on,
                            color: Colors.red,
                            label: 'DIRECCIÓN',
                            value: details.onsiteAddress!,
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        if (details.notes != null && details.notes!.isNotEmpty) ...[
                          _buildDetailRow(
                            icon: Icons.note,
                            color: Colors.amber,
                            label: 'NOTAS',
                            value: details.notes!,
                          ),
                        ],

                        if (details.status != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: details.status?.toUpperCase() == 'CONFIRMED' 
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Estado: ${details.status}',
                              style: TextStyle(
                                color: details.status?.toUpperCase() == 'CONFIRMED'
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[300], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Entrevista confirmada',
                              style: TextStyle(
                                color: Colors.green[300],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'El candidato ha sido confirmado. Los detalles se cargarán cuando estén disponibles.',
                              style: TextStyle(
                                color: Colors.green[200],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]
          
          else if (isFailed) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[300], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entrevista fallida',
                          style: TextStyle(
                            color: Colors.red[300],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'La entrevista no pudo completarse. Puedes intentar configurar una nueva.',
                          style: TextStyle(
                            color: Colors.red[200],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showConfigureInterviewDialog(candidate),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('CONFIGURAR NUEVA ENTREVISTA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ]
          
          else if (isPendingFreelancerAccept) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_empty, color: Colors.cyan[300], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Esperando que el freelancer acepte la solicitud de entrevista.',
                      style: TextStyle(color: Colors.cyan[300], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ]
          
          else if (canConfigureInterview) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFreelancerRejected 
                    ? Colors.red.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFreelancerRejected 
                      ? Colors.red.withOpacity(0.3)
                      : Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isFreelancerRejected ? Icons.warning : Icons.info,
                        color: isFreelancerRejected ? Colors.red[300] : Colors.blue[300],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isFreelancerRejected
                              ? 'El candidato rechazó el horario propuesto.'
                              : 'El candidato aceptó la entrevista.',
                          style: TextStyle(
                            color: isFreelancerRejected ? Colors.red[300] : Colors.blue[300],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showConfigureInterviewDialog(candidate),
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: Text(
                        isFreelancerRejected ? 'PROPONER NUEVO HORARIO' : 'CONFIGURAR ENTREVISTA',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFreelancerRejected ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
          
          else if (waitingForFreelancerResponse) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange[300], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Horario propuesto. Esperando respuesta del candidato.',
                      style: TextStyle(color: Colors.orange[300], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompatibilityRow({
    required String label,
    required String value,
    required int percentage,
    required int matchedCount,
    required int requiredCount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$matchedCount/$requiredCount ($value)',
                style: TextStyle(
                  color: _getPercentageColor(percentage),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 60,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getPercentageColor(percentage),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getPercentageColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    if (percentage >= 25) return Colors.amber;
    return Colors.red;
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    bool isLink = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (isLink)
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Enlace: $value')),
              );
            },
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
      ],
    );
  }

  // VERSIÓN CORREGIDA: Candidatos disponibles SIN la sección "Coincidencias con la Posición"
  Widget _buildAvailableCandidate(Candidate candidate, bool isSelected) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return GestureDetector(
      onTap: () => _toggleCandidateSelection(candidate),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : const Color(0xFF1A2942),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : const Color(0xFF2D3E57),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blueGrey[700],
                child: Text(
                  candidate.shortId.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Candidato ${candidate.shortId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${candidate.id.length > 13 ? candidate.id.substring(0, 13) : candidate.id}...',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getScoreColor(candidate.matchScore).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getScoreColor(candidate.matchScore),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      color: _getScoreColor(candidate.matchScore),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${candidate.matchScore}',
                      style: TextStyle(
                        color: _getScoreColor(candidate.matchScore),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: Colors.blue, size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceInfo(Map<String, dynamic> experience) {
    final entries = <Widget>[];
    
    if (experience['total_callouts'] != null) {
      entries.add(
        _buildExperienceStat(
          'Llamados',
          experience['total_callouts'].toString(),
          Colors.green,
        ),
      );
    }
    
    if (experience['total_events'] != null) {
      entries.add(
        _buildExperienceStat(
          'Eventos',
          experience['total_events'].toString(),
          Colors.green,
        ),
      );
    }
    
    if (experience['avg_rating'] != null) {
      final rating = experience['avg_rating'];
      entries.add(
        _buildExperienceStat(
          'Rating',
          rating is double ? rating.toStringAsFixed(1) : rating.toString(),
          Colors.amber,
        ),
      );
    }
    
    if (entries.isEmpty) {
      return Text(
        'Sin datos de experiencia',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries,
    );
  }

  Widget _buildExperienceStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color[300],
          fontSize: 11,
        ),
      ),
    );
  }

  bool _isCandidateConfirmed(Candidate candidate) {
    return candidate.status?.toUpperCase() == 'FILLED' || 
           candidate.status?.toUpperCase() == 'COVERED' ||
           candidate.status?.toUpperCase() == 'ACCEPTED' ||
           candidate.status?.toUpperCase() == 'CONFIRMED' ||
           candidate.interviewStatus?.toUpperCase() == 'COMPANY_ACCEPTED';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSentCandidates = sentCandidates.isNotEmpty;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1825),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2942),
        elevation: 0,
        title: isLoading
            ? const Text('Detalles de la activacion', style: TextStyle(color: Colors.white, fontSize: 16))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Detalles de la activacion', style: TextStyle(color: Colors.white, fontSize: 16)),
                  Text(
                    '${positionDetails?['role_name'] ?? 'Rol'} • ${positionDetails?['quantity_required'] ?? 1} Requeridos',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
            onPressed: isLoading ? null : _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)))
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        Text('Error al cargar datos', style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(error!, style: TextStyle(color: Colors.grey[400], fontSize: 12), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: Colors.blue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2942),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2D3E57)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('RESUMEN DE CONFIGURACION', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Pago por llamado:', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text('\$${widget.payRate.toStringAsFixed(0)} ${widget.currency}', 
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Estado del rol:', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text(
                                        fillStage.isNotEmpty ? _getStageText(fillStage) : 'N/A',
                                        style: TextStyle(
                                          color: fillStage.isNotEmpty ? _getStageColor(fillStage) : Colors.grey,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (!hasSentCandidates) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.people, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text('Seleccionar Candidato Disponible (${candidates.length})', 
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (candidates.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    const Icon(Icons.inbox, color: Colors.grey, size: 60),
                                    const SizedBox(height: 16),
                                    Text('No hay candidatos disponibles', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: candidates.length,
                              itemBuilder: (context, index) {
                                final candidate = candidates[index];
                                final isSelected = selectedCandidates.contains(candidate);
                                return _buildAvailableCandidate(candidate, isSelected);
                              },
                            ),
                        ],

                        const SizedBox(height: 32),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.send, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text('Activaciones enviadas (${sentCandidates.length})', 
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (sentCandidates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text('No hay activaciones enviadas aún', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: sentCandidates.length,
                            itemBuilder: (context, index) {
                              final candidate = sentCandidates[index];
                              final bool hasInterview = candidate.interviewId != null && candidate.interviewId!.isNotEmpty;
                              
                              final _status = candidate.interviewStatus?.toUpperCase() ?? '';
                              final bool isFreelancerAccepted =
                                _status == 'FREELANCER_ACCEPTED' || 
                                _status == 'ACCEPTED' || 
                                _status == 'CONFIRMED' || 
                                _status == 'COVERED' ||
                                _status == 'COMPANY_ACCEPTED';
                              
                              final bool isCandidateConfirmed = 
                                  candidate.status?.toUpperCase() == 'CONFIRMED' || 
                                  candidate.status?.toUpperCase() == 'COVERED' ||
                                  candidate.status?.toUpperCase() == 'ACCEPTED' ||
                                  candidate.status?.toUpperCase() == 'FILLED';
                              
                              final bool interviewConfirmed = 
                                  (isFreelancerAccepted || candidate.companyAccepted || isCandidateConfirmed);
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A2942),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF2D3E57)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: candidate.freelancerName != null ? Colors.blue[900] : Colors.grey[700],
                                          child: candidate.freelancerName != null
                                              ? Text(
                                                  candidate.freelancerName![0].toUpperCase(),
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                )
                                              : Text(
                                                  candidate.shortId[0].toUpperCase(),
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                candidate.freelancerName ?? 'Candidato ${candidate.shortId}',
                                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 4),
                                              Text('ID: ${candidate.shortId}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                              if (candidate.respondedAt != null) ...[
                                                const SizedBox(height: 4),
                                                Text('Respondido: ${_formatDate(candidate.respondedAt!)}', 
                                                    style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                              ],
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  _buildStatusBadge(candidate.status ?? 'ENVIADO'),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.star, color: Colors.orange[300], size: 12),
                                                        const SizedBox(width: 4),
                                                        Text('Puntaje: ${candidate.matchScore}', 
                                                            style: TextStyle(color: Colors.orange[300], fontSize: 11, fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    if (hasInterview)
                                      _buildInterviewProcess(candidate),
                                    
                                    _buildCompatibilitySection(candidate),
                                    
                                    // Los botones de acción se muestran SIEMPRE que tenga entrevista
                                    // El botón RECHAZAR está siempre visible (manejado internamente)
                                    if (hasInterview)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: _buildActionButtons(candidate),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: selectedCandidates.isNotEmpty && !hasSentCandidates
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2942),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: isSendingActivation ? null : _sendActivation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSendingActivation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : Text('Enviar Activacion (${selectedCandidates.length})', 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          : null,
    );
  }
}

class Candidate {
  final String id;
  final String shortId;
  final int matchScore;
  final String? status;
  final int? rankPos;
  final String? freelancerName;
  final String? interviewStatus;
  final String? interviewId;
  final DateTime? respondedAt;
  final String? scheduledAt;
  final String? proposalRejectionReason;
  final bool proposalRejected;
  final bool companyAccepted;
  
  final String? roleId;
  final String? roleName;
  final int equipmentMatchCount;
  final int experienceMatchCount;
  final Map<String, dynamic>? experience;
  final List<String> equipment;
  final List<String> tags;
  
  final String? interviewType;
  final String? interviewLink;
  final String? interviewNotes;
  
  final int roleScore;
  final int equipmentOk;
  final int tagMatchCount;

  Candidate({
    required this.id,
    required this.shortId,
    required this.matchScore,
    this.status,
    this.rankPos,
    this.freelancerName,
    this.interviewStatus,
    this.interviewId,
    this.respondedAt,
    this.scheduledAt,
    this.proposalRejectionReason,
    this.proposalRejected = false,
    this.companyAccepted = false,
    this.roleId,
    this.roleName,
    this.equipmentMatchCount = 0,
    this.experienceMatchCount = 0,
    this.experience,
    this.equipment = const [],
    this.tags = const [],
    this.interviewType,
    this.interviewLink,
    this.interviewNotes,
    this.roleScore = 0,
    this.equipmentOk = 0,
    this.tagMatchCount = 0,
  });

  factory Candidate.fromCandidateJson(Map<String, dynamic> json) {
    final rawId = json['freelancer_id']?.toString() ?? json['id']?.toString() ?? '';
    final shortId = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;
    
    int score = 0;
    final rawScore = json['score'] ?? json['match_score'] ?? json['score_total'];
    if (rawScore is int) {
      score = rawScore;
    } else if (rawScore is double) {
      score = rawScore.toInt();
    } else if (rawScore is String) {
      score = int.tryParse(rawScore) ?? 0;
    }

    String? interviewStatus;
    String? interviewId;
    if (json['interview'] is Map) {
      interviewStatus = json['interview']?['status']?.toString();
      interviewId = json['interview']?['id']?.toString();
    }
    if (interviewStatus == null && json['interview_status'] != null) {
      interviewStatus = json['interview_status']?.toString();
    }
    if (interviewId == null && json['interview_id'] != null) {
      interviewId = json['interview_id']?.toString();
    }

    String? roleId;
    String? roleName;
    int equipmentMatchCount = 0;
    int experienceMatchCount = 0;
    Map<String, dynamic>? experience;
    List<String> equipment = [];
    List<String> tags = [];
    int roleScore = 0;
    int equipmentOk = 0;
    int tagMatchCount = 0;

    if (json['role_id'] != null) {
      roleId = json['role_id'].toString();
    }
    if (json['role_name'] != null) {
      roleName = json['role_name'].toString();
    }

    if (json['breakdown'] is Map) {
      final breakdown = json['breakdown'] as Map<String, dynamic>;
      roleScore = breakdown['role_score'] is int ? breakdown['role_score'] : int.tryParse(breakdown['role_score']?.toString() ?? '0') ?? 0;
      equipmentOk = breakdown['equipment_ok'] is int ? breakdown['equipment_ok'] : int.tryParse(breakdown['equipment_ok']?.toString() ?? '0') ?? 0;
      equipmentMatchCount = breakdown['equipment_match_count'] is int ? breakdown['equipment_match_count'] : int.tryParse(breakdown['equipment_match_count']?.toString() ?? '0') ?? 0;
      tagMatchCount = breakdown['tag_match_count'] is int ? breakdown['tag_match_count'] : int.tryParse(breakdown['tag_match_count']?.toString() ?? '0') ?? 0;
      if (breakdown['role_id'] != null && roleId == null) {
        roleId = breakdown['role_id'].toString();
      }
    }

    if (json['equipment_match_count'] != null) {
      equipmentMatchCount = json['equipment_match_count'] is int
          ? json['equipment_match_count']
          : int.tryParse(json['equipment_match_count'].toString()) ?? 0;
    }
    if (json['experience_match_count'] != null) {
      experienceMatchCount = json['experience_match_count'] is int
          ? json['experience_match_count']
          : int.tryParse(json['experience_match_count'].toString()) ?? 0;
    }

    if (json['experience'] != null && json['experience'] is Map) {
      experience = json['experience'] as Map<String, dynamic>;
    }

    if (json['equipment'] != null && json['equipment'] is List) {
      equipment = (json['equipment'] as List)
          .map((e) => e.toString())
          .toList();
    }

    if (json['tags'] != null && json['tags'] is List) {
      tags = (json['tags'] as List)
          .map((e) => e.toString())
          .toList();
    }

    String? freelancerName;
    if (json['full_name'] != null) {
      freelancerName = json['full_name'].toString();
    } else if (json['freelancer_profile'] is Map) {
      final freelancer = json['freelancer_profile'] as Map;
      freelancerName = freelancer['full_name']?.toString() ?? 
                      freelancer['name']?.toString() ?? 
                      freelancer['display_name']?.toString();
    }

    return Candidate(
      id: rawId,
      shortId: shortId,
      matchScore: score,
      status: json['status']?.toString(),
      rankPos: json['rank_pos'] is int ? json['rank_pos'] as int : int.tryParse(json['rank_pos']?.toString() ?? ''),
      freelancerName: freelancerName,
      interviewStatus: interviewStatus,
      interviewId: interviewId,
      respondedAt: json['responded_at'] != null ? DateTime.tryParse(json['responded_at'].toString()) : null,
      roleId: roleId,
      roleName: roleName,
      equipmentMatchCount: equipmentMatchCount,
      experienceMatchCount: experienceMatchCount,
      experience: experience,
      equipment: equipment,
      tags: tags,
      interviewType: null,
      interviewLink: null,
      interviewNotes: null,
      roleScore: roleScore,
      equipmentOk: equipmentOk,
      tagMatchCount: tagMatchCount,
    );
  }

  factory Candidate.fromActivationJson(Map<String, dynamic> json, {Map<String, dynamic>? positionInterview}) {
    final rawId = json['id']?.toString() ?? json['freelancer_id']?.toString() ?? '';
    final shortId = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;
    
    int score = 0;
    final rawScore = json['score'] ?? json['match_score'];
    if (rawScore is int) {
      score = rawScore;
    } else if (rawScore is double) {
      score = rawScore.toInt();
    } else if (rawScore is String) {
      score = int.tryParse(rawScore) ?? 0;
    }

    String? freelancerName;
    if (json['full_name'] != null) {
      freelancerName = json['full_name'].toString();
    } else if (json['freelancer_profile'] is Map) {
      final freelancer = json['freelancer_profile'] as Map;
      freelancerName = freelancer['full_name']?.toString() ?? 
                      freelancer['name']?.toString() ?? 
                      freelancer['display_name']?.toString();
    }

    String? interviewStatus;
    String? interviewId;
    
    if (json['interview'] is Map) {
      interviewStatus = json['interview']['status']?.toString();
      interviewId = json['interview']['id']?.toString();
    } else if (positionInterview != null) {
      interviewStatus = positionInterview['status']?.toString();
      interviewId = positionInterview['id']?.toString();
    }

    DateTime? respondedAt;
    if (json['responded_at'] != null) {
      respondedAt = DateTime.tryParse(json['responded_at'].toString());
    }

    String? scheduledAt;
    String? proposalRejectionReason;
    bool proposalRejected = false;
    bool companyAccepted = false;
    String? interviewType;
    String? interviewLink;
    String? interviewNotes;
    
    if (json['interview'] is Map) {
      scheduledAt = json['interview']['scheduled_at']?.toString();
      proposalRejectionReason = json['interview']['proposal_rejection_reason']?.toString();
      proposalRejected = json['interview']['proposal_rejected'] == true;
      companyAccepted = json['interview']['status']?.toString().toUpperCase() == 'COMPANY_ACCEPTED';
      interviewType = json['interview']['interview_type']?.toString();
      interviewLink = json['interview']['online_meeting_link']?.toString();
      interviewNotes = json['interview']['notes']?.toString();
    }

    String? roleId;
    String? roleName;
    int equipmentMatchCount = 0;
    int equipmentRequired = 0;
    int tagMatchCount = 0;
    int tagRequired = 0;
    int roleMatchCount = 0;
    int roleRequired = 0;
    List<String> equipment = [];
    List<String> tags = [];

    if (json['match_summary'] is Map) {
      final summary = json['match_summary'] as Map<String, dynamic>;
      roleMatchCount = summary['roles_matched'] is int ? summary['roles_matched'] : int.tryParse(summary['roles_matched']?.toString() ?? '0') ?? 0;
      roleRequired = summary['roles_required'] is int ? summary['roles_required'] : int.tryParse(summary['roles_required']?.toString() ?? '0') ?? 0;
      tagMatchCount = summary['tags_matched'] is int ? summary['tags_matched'] : int.tryParse(summary['tags_matched']?.toString() ?? '0') ?? 0;
      tagRequired = summary['tags_required'] is int ? summary['tags_required'] : int.tryParse(summary['tags_required']?.toString() ?? '0') ?? 0;
      equipmentMatchCount = summary['equipment_matched'] is int ? summary['equipment_matched'] : int.tryParse(summary['equipment_matched']?.toString() ?? '0') ?? 0;
      equipmentRequired = summary['equipment_required'] is int ? summary['equipment_required'] : int.tryParse(summary['equipment_required']?.toString() ?? '0') ?? 0;
    }

    if (json['match_breakdown'] is Map) {
      final breakdown = json['match_breakdown'] as Map<String, dynamic>;
      
      if (breakdown['roles'] is Map) {
        final rolesData = breakdown['roles'] as Map<String, dynamic>;
        if (rolesData['matched'] is List && (rolesData['matched'] as List).isNotEmpty) {
          final firstRole = (rolesData['matched'] as List).first;
          if (firstRole is Map) {
            roleId = firstRole['id']?.toString();
            roleName = firstRole['name']?.toString();
          }
        }
      }

      if (breakdown['equipment'] is Map) {
        final equipData = breakdown['equipment'] as Map<String, dynamic>;
        if (equipData['matched'] is List) {
          equipment = (equipData['matched'] as List)
              .map((e) => (e is Map && e['name'] != null) ? e['name'].toString() : e.toString())
              .toList();
        }
      }

      if (breakdown['tags'] is Map) {
        final tagsData = breakdown['tags'] as Map<String, dynamic>;
        if (tagsData['matched'] is List) {
          tags = (tagsData['matched'] as List)
              .map((e) => (e is Map && e['name'] != null) ? e['name'].toString() : e.toString())
              .toList();
        }
      }
    }

    return Candidate(
      id: rawId,
      shortId: shortId,
      matchScore: score,
      status: json['status']?.toString(),
      rankPos: json['rank_pos'] is int ? json['rank_pos'] as int : int.tryParse(json['rank_pos']?.toString() ?? ''),
      freelancerName: freelancerName,
      interviewStatus: interviewStatus,
      interviewId: interviewId,
      respondedAt: respondedAt,
      scheduledAt: scheduledAt,
      proposalRejectionReason: proposalRejectionReason,
      proposalRejected: proposalRejected,
      companyAccepted: companyAccepted,
      roleId: roleId,
      roleName: roleName,
      equipmentMatchCount: equipmentMatchCount,
      experienceMatchCount: 0,
      experience: null,
      equipment: equipment,
      tags: tags,
      interviewType: interviewType,
      interviewLink: interviewLink,
      interviewNotes: interviewNotes,
      roleScore: roleMatchCount,
      equipmentOk: equipmentRequired,
      tagMatchCount: tagMatchCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Candidate && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class InterviewDetails {
  final String interviewId;
  final String? interviewType;
  final String? scheduledAt;
  final String? onlineLink;
  final String? onsiteAddress;
  final String? notes;
  final String? status;
  final String? proposalVersion;

  InterviewDetails({
    required this.interviewId,
    this.interviewType,
    this.scheduledAt,
    this.onlineLink,
    this.onsiteAddress,
    this.notes,
    this.status,
    this.proposalVersion,
  });

  factory InterviewDetails.fromJson(Map<String, dynamic> json) {
    return InterviewDetails(
      interviewId: json['id']?.toString() ?? '',
      interviewType: json['interview_type']?.toString(),
      scheduledAt: json['scheduled_at']?.toString(),
      onlineLink: json['online_meeting_link']?.toString(),
      onsiteAddress: json['onsite_address']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString(),
      proposalVersion: json['proposal_version']?.toString(),
    );
  }

  factory InterviewDetails.fromInterviewJson(Map<String, dynamic> json) {
    return InterviewDetails(
      interviewId: json['id']?.toString() ?? '',
      interviewType: json['interview_type']?.toString(),
      scheduledAt: json['scheduled_at']?.toString(),
      onlineLink: json['online_meeting_link']?.toString(),
      onsiteAddress: json['onsite_address']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString(),
      proposalVersion: json['proposal_version']?.toString(),
    );
  }
}