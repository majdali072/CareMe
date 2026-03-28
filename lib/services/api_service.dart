import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/app_models.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator, localhost for web/desktop
  static const String _baseUrl = 'http://localhost:8000/api';
  static String? _token;
  static String? _userId;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static bool get isLoggedIn => _token != null;

  static void setBaseUrl(String url) {
    // For switching between emulator/device/web
  }

  static void logout() {
    _token = null;
    _userId = null;
  }

  // ---------- Auth ----------

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      _token = data['token'];
      _userId = data['user']['id'];
      return data;
    }
    throw ApiException(data['error'] ?? 'Registration failed');
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      _token = data['token'];
      _userId = data['user']['id'];
      return data;
    }
    throw ApiException(data['error'] ?? 'Login failed');
  }

  // ---------- Profile ----------

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/profile/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw ApiException('Failed to load profile');
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    String? dateOfBirth,
    String? address,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (dateOfBirth != null) body['dateOfBirth'] = dateOfBirth;
    if (address != null) body['address'] = address;

    final response = await http.put(
      Uri.parse('$_baseUrl/users/profile/'),
      headers: _headers,
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw ApiException(data['error'] ?? 'Failed to update profile');
  }

  // ---------- Medications ----------

  static Future<List<Medication>> getMedications() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/medications/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((m) => Medication.fromJson(m)).toList();
    }
    throw ApiException('Failed to load medications');
  }

  static Future<Medication> addMedication(Medication med) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/medications/'),
      headers: _headers,
      body: jsonEncode(med.toJson()),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return Medication.fromJson(data);
    }
    throw ApiException(data['error'] ?? 'Failed to add medication');
  }

  static Future<Medication> updateMedication(String id, Medication med) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/medications/$id/'),
      headers: _headers,
      body: jsonEncode(med.toJson()),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Medication.fromJson(data);
    }
    throw ApiException(data['error'] ?? 'Failed to update medication');
  }

  static Future<void> deleteMedication(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/medications/$id/'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to delete medication');
    }
  }

  // ---------- Lab Tests ----------

  static Future<List<LabTest>> getLabTests() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/lab-tests/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((l) => LabTest.fromJson(l)).toList();
    }
    throw ApiException('Failed to load lab tests');
  }

  static Future<LabTest> addLabTest(LabTest lab, {Uint8List? fileBytes, String? pickedFileName}) async {
    if (fileBytes != null && pickedFileName != null) {
      // Multipart upload
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/lab-tests/'));
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      request.fields['name'] = lab.name;
      request.fields['date'] = lab.date;
      request.fields['doctor'] = lab.doctor;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: pickedFileName,
        contentType: MediaType('application', 'octet-stream'),
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return LabTest.fromJson(data);
      }
      throw ApiException(data['error'] ?? 'Failed to add lab test');
    } else {
      final response = await http.post(
        Uri.parse('$_baseUrl/lab-tests/'),
        headers: _headers,
        body: jsonEncode(lab.toJson()),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return LabTest.fromJson(data);
      }
      throw ApiException(data['error'] ?? 'Failed to add lab test');
    }
  }

  static Future<Uint8List> downloadLabTestFile(String labId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/lab-tests/$labId/file/'),
      headers: {if (_token != null) 'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw ApiException('Failed to download file');
  }

  static Future<void> deleteLabTest(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/lab-tests/$id/'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to delete lab test');
    }
  }

  // ---------- Chat ----------

  static Future<String> sendChatMessage(String message, List<Map<String, dynamic>> history) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/'),
      headers: _headers,
      body: jsonEncode({'message': message, 'history': history}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['reply'];
    }
    throw ApiException(data['error'] ?? 'Failed to get response');
  }

  // ---------- Account ----------

  static Future<void> deleteAccount() async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/delete/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      _token = null;
      _userId = null;
      return;
    }
    final data = jsonDecode(response.body);
    throw ApiException(data['error'] ?? 'Failed to delete account');
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
