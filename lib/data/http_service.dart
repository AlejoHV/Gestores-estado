import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class TimeoutException extends ApiException {
  TimeoutException() : super('Request timeout');
}

class HttpService {
  //! URL Base de la API
  static const String baseUrl = 'http://localhost:3000';
  //! Timeout de la API
  static const Duration timeout = Duration(seconds: 10);

  //! Método privado para hacer peticiones HTTP
  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    String? requestId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
      };

      if (requestId != null) {
        requestHeaders['Idempotency-Key'] = requestId;
      }

      http.Response response;

      //! Métodos HTTP, Get, Post, Put, Delete
      //? GET: Obtiene datos
      //? POST: Crea datos
      //? PUT: Actualiza datos
      //? DELETE: Elimina datos
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(uri, headers: requestHeaders)
              .timeout(timeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: requestHeaders, body: body)
              .timeout(timeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: requestHeaders, body: body)
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: requestHeaders)
              .timeout(timeout);
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }

      return response;
    } on SocketException {
      throw NetworkException('No internet connection');
    } on HttpException {
      throw NetworkException('HTTP error occurred');
    } on TimeoutException {
      throw TimeoutException();
    } catch (e) {
      throw NetworkException('Unexpected error: $e');
    }
  }

  //! Manejo de respuestas
  void _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'Request failed';
    try {
      final errorBody = jsonDecode(response.body);
      message = errorBody['message'] ?? errorBody['error'] ?? message;
    } catch (e) {
      // If JSON parsing fails, use default message
    }

    if (response.statusCode >= 400 && response.statusCode < 500) {
      throw ApiException('Client error: $message', response.statusCode);
    } else if (response.statusCode >= 500) {
      throw ApiException('Server error: $message', response.statusCode);
    } else {
      throw ApiException(message, response.statusCode);
    }
  }

  Future<List<Task>> getTasks() async {
    try {
      final response = await _makeRequest('GET', '/tasks');
      _handleResponse(response);

      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      throw ApiException('Failed to get tasks: $e');
    }
  }

  Future<Task> getTask(String id) async {
    try {
      final response = await _makeRequest('GET', '/tasks/$id');
      _handleResponse(response);

      final Map<String, dynamic> json = jsonDecode(response.body);
      return Task.fromJson(json);
    } catch (e) {
      throw ApiException('Failed to get task: $e');
    }
  }

  Future<Task> createTask(Task task, {String? requestId}) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/tasks',
        body: jsonEncode(task.toJson()),
        requestId: requestId,
      );
      _handleResponse(response);

      final Map<String, dynamic> json = jsonDecode(response.body);
      return Task.fromJson(json);
    } catch (e) {
      throw ApiException('Failed to create task: $e');
    }
  }

  Future<Task> updateTask(Task task, {String? requestId}) async {
    try {
      final response = await _makeRequest(
        'PUT',
        '/tasks/${task.id}',
        body: jsonEncode(task.toJson()),
        requestId: requestId,
      );
      _handleResponse(response);

      final Map<String, dynamic> json = jsonDecode(response.body);
      return Task.fromJson(json);
    } catch (e) {
      throw ApiException('Failed to update task: $e');
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      final response = await _makeRequest('DELETE', '/tasks/$id');
      _handleResponse(response);
    } catch (e) {
      throw ApiException('Failed to delete task: $e');
    }
  }
}
