import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import '../auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];

      if (token == null || baseUrl == null) {
        throw Exception('No hay token de autenticacion');
      }

      // 1. Cargar detalles de la posicion
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

        if (posData['activation_candidates'] != null &&
            posData['activation_candidates'] is List) {
          sentCandidates = (posData['activation_candidates'] as List)
              .map((c) => Candidate.fromActivationJson(c))
              .toList();
        }

        fillStage = posData['fill_stage']?.toString() ?? '';
      }

      // 2. Cargar candidatos disponibles
      final candidatesResponse = await http.get(
        Uri.parse(
            '$baseUrl/positions/${widget.positionId}/candidates?limit=50'),
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
            candidatesList = (data['candidates'] as List)
                .map((c) => Candidate.fromCandidateJson(c))
                .toList();
          }
        } else if (data is List) {
          candidatesList =
              data.map((c) => Candidate.fromCandidateJson(c)).toList();
        }

        // Ordenar por score descendente
        candidatesList.sort((a, b) => b.matchScore.compareTo(a.matchScore));

        // Filtrar candidatos sin match score
        candidatesList =
            candidatesList.where((c) => c.matchScore > 0).toList();

        setState(() {
          candidates = candidatesList;
          isLoading = false;
        });
      } else if (candidatesResponse.statusCode == 401) {
        await authProvider.logout();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        throw Exception(
            'Error al cargar candidatos: ${candidatesResponse.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Confirmar envio',
              style: TextStyle(color: Colors.white)),
          content: Text(
            'Enviar posicion a ${selectedCandidates.length} candidato${selectedCandidates.length > 1 ? 's' : ''}?',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child:
                  const Text('Enviar', style: TextStyle(color: Colors.white)),
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

    int successCount = 0;

    try {
      for (var candidate in selectedCandidates) {
        try {
          final response = await http
              .post(
                Uri.parse('$baseUrl/positions/${widget.positionId}/send'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: json.encode({
                  'freelancer_id': candidate.id,
                  'rating_minutes': 60,
                  'allow_any_time': false,
                }),
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200 || response.statusCode == 201) {
            successCount++;
          }
        } catch (e) {
          print('Error enviando a ${candidate.shortId}: $e');
        }
      }

      setState(() => isSendingActivation = false);

      if (mounted && successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Posicion enviada a $successCount candidato${successCount > 1 ? 's' : ''}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        setState(() => selectedCandidates.clear());
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          await _loadData();
        }
      } else if (mounted && successCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar a ningun candidato'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isSendingActivation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleCandidateSelection(Candidate candidate) {
    setState(() {
      if (selectedCandidates.contains(candidate)) {
        selectedCandidates.remove(candidate);
      } else {
        selectedCandidates.add(candidate);
      }
    });
  }

  String _getStageText(String stage) {
    switch (stage.toUpperCase()) {
      case 'LIST_READY':
        return 'LISTO PARA SELECCIONAR';
      case 'RED_RECOMMENDED':
      case 'RECOMMENDED_NETWORK':
        return 'RED RECOMENDADA';
      case 'RED_KNOWN':
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
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
      case 'ACCEPTED':
        color = Colors.green;
        break;
      case 'REJECTED':
      case 'DECLINED':
        color = Colors.red;
        break;
      default:
        color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase() == 'PENDING' ? 'ENVIADO' : status.toUpperCase(),
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1825),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2942),
        elevation: 0,
        title: isLoading
            ? const Text(
                'Detalles de la activacion',
                style: TextStyle(color: Colors.white, fontSize: 16),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Detalles de la activacion',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    '${positionDetails?['role_name'] ?? 'Rol'} • ${positionDetails?['quantity_required'] ?? 1} Requeridos',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar datos',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue),
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
                        // Resumen de configuracion
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
                              const Text(
                                'RESUMEN DE CONFIGURACION',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pago por llamado:',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${widget.payRate.toStringAsFixed(0)} ${widget.currency}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Estado del rol:',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fillStage.isNotEmpty
                                            ? _getStageText(fillStage)
                                            : 'N/A',
                                        style: TextStyle(
                                          color: fillStage.isNotEmpty
                                              ? _getStageColor(fillStage)
                                              : Colors.grey,
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

                        // Seccion candidatos disponibles
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.people,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Seleccionar Candidato Disponible (${candidates.length})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                                  const Icon(Icons.inbox,
                                      color: Colors.grey, size: 60),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hay candidatos disponibles',
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: candidates.length,
                            itemBuilder: (context, index) {
                              final candidate = candidates[index];
                              final isSelected =
                                  selectedCandidates.contains(candidate);

                              return GestureDetector(
                                onTap: () =>
                                    _toggleCandidateSelection(candidate),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF1E3A5F)
                                        : const Color(0xFF1A2942),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue
                                          : const Color(0xFF2D3E57),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.blueGrey[700],
                                        child: Text(
                                          candidate.shortId
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Candidato ${candidate.shortId}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.star,
                                                    color: Colors.amber[600],
                                                    size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Match Score: ${candidate.matchScore}',
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _getScoreColor(
                                                  candidate.matchScore)
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _getScoreColor(
                                                candidate.matchScore),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${candidate.matchScore}',
                                          style: TextStyle(
                                            color: _getScoreColor(
                                                candidate.matchScore),
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.check_circle,
                                            color: Colors.blue, size: 22),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 32),

                        // Seccion activaciones enviadas
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.people,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Activaciones enviadas (${sentCandidates.length})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (sentCandidates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              'No hay activaciones enviadas aun',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: sentCandidates.length,
                            itemBuilder: (context, index) {
                              final candidate = sentCandidates[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A2942),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF2D3E57)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey[700],
                                      child: const Icon(Icons.person,
                                          color: Colors.grey, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Candidato ${candidate.shortId}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ID: ${candidate.shortId}',
                                            style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 12),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              _buildStatusBadge(
                                                  candidate.status ??
                                                      'ENVIADO'),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Puntaje: ${candidate.matchScore}',
                                                style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (candidate.rankPos != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Rango #${candidate.rankPos}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
      bottomNavigationBar: selectedCandidates.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2942),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: isSendingActivation ? null : _sendActivation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSendingActivation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Enviar Activacion (${selectedCandidates.length})',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
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

  Candidate({
    required this.id,
    required this.shortId,
    required this.matchScore,
    this.status,
    this.rankPos,
  });

  factory Candidate.fromCandidateJson(Map<String, dynamic> json) {
    final rawId = json['freelancer_id']?.toString() ??
        json['id']?.toString() ??
        '';

    final shortId = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;

    int score = 0;
    final rawScore =
        json['score'] ?? json['match_score'] ?? json['score_total'];
    if (rawScore is int) {
      score = rawScore;
    } else if (rawScore is double) {
      score = rawScore.toInt();
    } else if (rawScore is String) {
      score = int.tryParse(rawScore) ?? 0;
    }

    return Candidate(
      id: rawId,
      shortId: shortId,
      matchScore: score,
      status: json['status']?.toString(),
      rankPos: json['rank_pos'] is int
          ? json['rank_pos'] as int
          : int.tryParse(json['rank_pos']?.toString() ?? ''),
    );
  }

  factory Candidate.fromActivationJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ??
        json['freelancer_id']?.toString() ??
        '';

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

    return Candidate(
      id: rawId,
      shortId: shortId,
      matchScore: score,
      status: json['status']?.toString(),
      rankPos: json['rank_pos'] is int
          ? json['rank_pos'] as int
          : int.tryParse(json['rank_pos']?.toString() ?? ''),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Candidate &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}