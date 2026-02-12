import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class ApiErrorHandler {
  static String handleNetworkException(dynamic error) {
    if (error is SocketException) {
      return 'No hay conexión a internet. Verifica tu red.';
    } else if (error is http.ClientException) {
      return 'Error de conexión con el servidor.';
    } else if (error is TimeoutException || error.toString().contains('TimeoutException') || error.toString().contains('tiempo de espera')) {
      return 'El servidor tardó demasiado en responder.';
    } else {
      return 'Ocurrió un error inesperado: $error';
    }
  }

  // Método de compatibilidad
  static String handleHttpError(dynamic error, {int? statusCode}) {
    if (statusCode != null) {
      switch (statusCode) {
        case 400: return 'Solicitud incorrecta.';
        case 401: return 'Sesión expirada.';
        case 403: return 'Acceso denegado.';
        case 404: return 'Recurso no encontrado.';
        case 500: return 'Error interno del servidor.';
        default: return 'Error del servidor ($statusCode).';
      }
    }
    return handleNetworkException(error);
  }

  static Widget buildErrorWidget({required String message, required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

extension ResponseExtension on http.Response {
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  String get friendlyErrorMessage {
    if (isSuccess) return '';
    
    try {
      final body = jsonDecode(this.body);
      if (body is Map<String, dynamic>) {
        if (body.containsKey('detail')) return body['detail'].toString();
        if (body.containsKey('message')) return body['message'].toString();
        if (body.containsKey('error')) return body['error'].toString();
      }
    } catch (_) {}
    
    switch (statusCode) {
      case 400: return 'Solicitud incorrecta.';
      case 401: return 'Sesión expirada. Inicia sesión nuevamente.';
      case 403: return 'No tienes permisos para realizar esta acción.';
      case 404: return 'Recurso no encontrado.';
      case 500: return 'Error interno del servidor.';
      default: return 'Error desconocido ($statusCode).';
    }
  }
}