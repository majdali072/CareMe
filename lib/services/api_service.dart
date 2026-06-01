import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

class ApiService {
  // Public tunnel via ngrok. Change when the tunnel URL rotates.
  static const String _baseUrl = 'https://rimmed-width-versus.ngrok-free.dev/api';
  static String? _token;
  static String? _refreshToken;
  static String? _userId;
  static String? _userName;
  static String? _userEmail;
  static bool _isAdmin = false;
  // Two-letter language code (e.g. 'en', 'ar'). Sent as Accept-Language so
  // the backend can localise error messages and tell Gemini what language
  // to reply in.
  static String _localeCode = 'en';

  static const _kToken = 'auth_token';
  static const _kRefresh = 'auth_refresh';
  static const _kUserId = 'auth_user_id';
  static const _kName = 'auth_user_name';
  static const _kEmail = 'auth_user_email';
  static const _kIsAdmin = 'auth_is_admin';

  static String? get userName => _userName;
  static String? get userEmail => _userEmail;
  static bool get isAdmin => _isAdmin;

  static Future<void> _persistSession({
    required String token,
    required String refresh,
    required String userId,
    required String name,
    required String email,
    required bool isAdmin,
  }) async {
    _token = token;
    _refreshToken = refresh;
    _userId = userId;
    _userName = name;
    _userEmail = email;
    _isAdmin = isAdmin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kRefresh, refresh);
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kName, name);
    await prefs.setString(_kEmail, email);
    await prefs.setBool(_kIsAdmin, isAdmin);
  }

  static Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    if (token == null) return false;
    _token = token;
    _refreshToken = prefs.getString(_kRefresh);
    _userId = prefs.getString(_kUserId);
    _userName = prefs.getString(_kName);
    _userEmail = prefs.getString(_kEmail);
    _isAdmin = prefs.getBool(_kIsAdmin) ?? false;
    return true;
  }

  static Future<void> _clearSession() async {
    _token = null;
    _refreshToken = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _isAdmin = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUserId);
    await prefs.remove(_kName);
    await prefs.remove(_kEmail);
    await prefs.remove(_kIsAdmin);
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': '1',
        'Accept-Language': _localeCode,
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static bool get isLoggedIn => _token != null;

  static void setBaseUrl(String url) {
    // For switching between emulator/device/web
  }

  /// Set the user's preferred language. Used for the Accept-Language header
  /// so Gemini and Django can answer in the right language. Called from
  /// LocaleController.
  static void setLocale(String code) {
    final c = code.trim().toLowerCase();
    _localeCode = c.isEmpty ? 'en' : c;
  }

  static String get localeCode => _localeCode;

  static Future<void> logout() async {
    if (_refreshToken != null) {
      http.post(
        Uri.parse('$_baseUrl/auth/logout/'),
        headers: _headers,
        body: jsonEncode({'refresh_token': _refreshToken}),
      ).catchError((_) => http.Response('', 200));
    }
    await _clearSession();
  }

  // ---------- Token Refresh ----------

  /// Attempt to refresh the access token using the refresh token.
  /// Returns true if successful, false if re-login is needed.
  static Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh-token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _refreshToken = data['refresh_token'];
        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString(_kToken, _token!);
        if (_refreshToken != null) await prefs.setString(_kRefresh, _refreshToken!);
        return true;
      }
    } catch (_) {}

    await _clearSession();
    return false;
  }

  /// Make an authenticated request with automatic token refresh on 401.
  static Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function() request,
  ) async {
    var response = await request();

    // If token expired, try refreshing
    if (response.statusCode == 401) {
      final body = jsonDecode(response.body);
      if (body['code'] == 'token_expired' && await _refreshAccessToken()) {
        // Retry with new token
        response = await request();
      }
    }

    return response;
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
      await _persistSession(
        token: data['token'],
        refresh: data['refresh_token'],
        userId: data['user']['id'],
        name: data['user']['name'] ?? '',
        email: data['user']['email'] ?? '',
        isAdmin: data['user']['is_admin'] == true,
      );
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
      await _persistSession(
        token: data['token'],
        refresh: data['refresh_token'],
        userId: data['user']['id'],
        name: data['user']['name'] ?? '',
        email: data['user']['email'] ?? '',
        isAdmin: data['user']['is_admin'] == true,
      );
      return data;
    }
    if (data['code'] == 'account_deactivated') {
      throw DeactivatedAccountException(
        email: email,
        isGoogleAccount: data['is_google_account'] == true,
      );
    }
    throw ApiException(data['error'] ?? 'Login failed');
  }

  static Future<Map<String, dynamic>> googleAuth({
    required String name,
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/google/'),
      headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': '1'},
      body: jsonEncode({'name': name, 'email': email}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await _persistSession(
        token: data['token'],
        refresh: data['refresh_token'],
        userId: data['user']['id'],
        name: data['user']['name'] ?? '',
        email: data['user']['email'] ?? '',
        isAdmin: data['user']['is_admin'] == true,
      );
      return data;
    }
    if (data['code'] == 'account_deactivated') {
      throw DeactivatedAccountException(
        email: email,
        isGoogleAccount: data['is_google_account'] == true,
      );
    }
    throw ApiException(data['error'] ?? 'Google authentication failed');
  }

  /// Re-enable a deactivated account. Returns the same shape as `login` and
  /// persists the session, so the caller can route straight to the home screen.
  static Future<Map<String, dynamic>> reactivateAccount({
    required String email,
    required String otpCode,
    String? password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/reactivate/'),
      headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': '1'},
      body: jsonEncode({
        'email': email,
        'otp_code': otpCode,
        if (password != null) 'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await _persistSession(
        token: data['token'],
        refresh: data['refresh_token'],
        userId: data['user']['id'],
        name: data['user']['name'] ?? '',
        email: data['user']['email'] ?? '',
        isAdmin: data['user']['is_admin'] == true,
      );
      return data;
    }
    throw ApiException(data['error'] ?? 'Failed to reactivate account');
  }

  // ---------- OTP ----------

  static Future<void> sendOtp(String email, {String? purpose}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/send-otp/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        if (purpose != null) 'purpose': purpose,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'Failed to send OTP');
    }
  }

  static Future<void> verifyOtp(String email, String code) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/verify-otp/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'Invalid OTP');
    }
  }

  // ---------- Change Password ----------

  static Future<void> changePassword(String newPassword) async {
    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/auth/change-password/'),
      headers: _headers,
      body: jsonEncode({'new_password': newPassword}),
    ));

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'Failed to change password');
    }

    // Password changed — tokens revoked server-side, must re-login
    _token = null;
    _refreshToken = null;
  }

  // ---------- Profile ----------

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$_baseUrl/users/profile/'),
      headers: _headers,
    ));

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
    double? latitude,
    double? longitude,
    String? country,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (dateOfBirth != null) body['dateOfBirth'] = dateOfBirth;
    if (address != null) body['address'] = address;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (country != null) body['country'] = country;

    final response = await _authenticatedRequest(() => http.put(
      Uri.parse('$_baseUrl/users/profile/'),
      headers: _headers,
      body: jsonEncode(body),
    ));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw ApiException(data['error'] ?? 'Failed to update profile');
  }

  // ---------- Medications ----------

  static Future<List<Medication>> getMedications() async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$_baseUrl/medications/'),
      headers: _headers,
    ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((m) => Medication.fromJson(m)).toList();
    }
    throw ApiException('Failed to load medications');
  }

  static Future<Medication> addMedication(Medication med) async {
    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/medications/'),
      headers: _headers,
      body: jsonEncode(med.toJson()),
    ));

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return Medication.fromJson(data);
    }
    throw ApiException(data['error'] ?? 'Failed to add medication');
  }

  static Future<Medication> updateMedication(String id, Medication med) async {
    final response = await _authenticatedRequest(() => http.put(
      Uri.parse('$_baseUrl/medications/$id/'),
      headers: _headers,
      body: jsonEncode(med.toJson()),
    ));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Medication.fromJson(data);
    }
    throw ApiException(data['error'] ?? 'Failed to update medication');
  }

  static Future<void> deleteMedication(String id) async {
    final response = await _authenticatedRequest(() => http.delete(
      Uri.parse('$_baseUrl/medications/$id/'),
      headers: _headers,
    ));

    if (response.statusCode != 200) {
      throw ApiException('Failed to delete medication');
    }
  }

  // ---------- Medication AI Suggestions ----------

  /// Typeahead suggestions for the Add Medication name field.
  static Future<List<String>> suggestMedicationNames(String prefix) async {
    final q = prefix.trim();
    if (q.length < 2) return const [];
    try {
      final response = await _authenticatedRequest(() => http.post(
            Uri.parse('$_baseUrl/medications/suggest-names/'),
            headers: _headers,
            body: jsonEncode({'q': q}),
          ));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = data['names'];
      if (raw is List) {
        return raw.map((n) => n.toString()).where((s) => s.isNotEmpty).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Inline completions for the chatbot input. Returns up to 3 short
  /// follow-up phrases the user might want to type next; empty list on any
  /// failure so the UI just hides the chip strip.
  static Future<List<String>> chatSuggest(
    String partial,
    List<Map<String, dynamic>> history,
  ) async {
    if (partial.trim().length < 2) return const [];
    try {
      final response = await _authenticatedRequest(() => http.post(
            Uri.parse('$_baseUrl/chat/suggest/'),
            headers: _headers,
            body: jsonEncode({'q': partial, 'history': history}),
          ));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = data['suggestions'];
      if (raw is List) {
        return raw
            .map((n) => n.toString().trim())
            .where((s) => s.isNotEmpty)
            .take(3)
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Ask the AI for a short title summarizing a chat conversation.
  /// Returns an empty string on any failure so the caller keeps the existing
  /// (first-message) preview title.
  static Future<String> generateChatTitle(
    List<Map<String, dynamic>> history,
  ) async {
    if (history.isEmpty) return '';
    try {
      final response = await _authenticatedRequest(() => http.post(
            Uri.parse('$_baseUrl/chat/title/'),
            headers: _headers,
            body: jsonEncode({'history': history}),
          ));
      if (response.statusCode != 200) return '';
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['title'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  /// Ask the AI to fill purpose/sideEffects for a known med.
  /// Returns an empty map on failure so callers can leave fields untouched.
  static Future<Map<String, String>> suggestMedicationFields(String name) async {
    final n = name.trim();
    if (n.isEmpty) return const {};
    try {
      final response = await _authenticatedRequest(() => http.post(
            Uri.parse('$_baseUrl/medications/suggest-fields/'),
            headers: _headers,
            body: jsonEncode({'name': n}),
          ));
      if (response.statusCode != 200) return const {};
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'purpose': (data['purpose'] ?? '').toString(),
        'sideEffects': (data['sideEffects'] ?? '').toString(),
      };
    } catch (_) {
      return const {};
    }
  }

  // ---------- Lab Tests ----------

  static Future<List<LabTest>> getLabTests() async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$_baseUrl/lab-tests/'),
      headers: _headers,
    ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((l) => LabTest.fromJson(l)).toList();
    }
    throw ApiException('Failed to load lab tests');
  }

  static Future<LabTest> addLabTest(LabTest lab, {Uint8List? fileBytes, String? pickedFileName}) async {
    if (fileBytes != null && pickedFileName != null) {
      // Multipart upload
      Future<http.Response> doUpload() async {
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
        return http.Response.fromStream(streamed);
      }

      var response = await doUpload();
      if (response.statusCode == 401) {
        final body = jsonDecode(response.body);
        if (body['code'] == 'token_expired' && await _refreshAccessToken()) {
          response = await doUpload();
        }
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return LabTest.fromJson(data);
      }
      throw ApiException(data['error'] ?? 'Failed to add lab test');
    } else {
      final response = await _authenticatedRequest(() => http.post(
        Uri.parse('$_baseUrl/lab-tests/'),
        headers: _headers,
        body: jsonEncode(lab.toJson()),
      ));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return LabTest.fromJson(data);
      }
      throw ApiException(data['error'] ?? 'Failed to add lab test');
    }
  }

  static Future<Uint8List> downloadLabTestFile(String labId) async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$_baseUrl/lab-tests/$labId/file/'),
      headers: {if (_token != null) 'Authorization': 'Bearer $_token'},
    ));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw ApiException('Failed to download file');
  }

  static Future<void> deleteLabTest(String id) async {
    final response = await _authenticatedRequest(() => http.delete(
      Uri.parse('$_baseUrl/lab-tests/$id/'),
      headers: _headers,
    ));

    if (response.statusCode != 200) {
      throw ApiException('Failed to delete lab test');
    }
  }

  // ---------- Chat ----------

  static Future<String> sendChatMessage(String message, List<Map<String, dynamic>> history) async {
    final client = http.Client();
    try {
      final response = await _authenticatedRequest(() async {
        final request = http.Request('POST', Uri.parse('$_baseUrl/chat/'));
        request.headers.addAll(_headers);
        request.body = jsonEncode({'message': message, 'history': history});
        final streamed = await client.send(request).timeout(
          const Duration(seconds: 60),
        );
        return http.Response.fromStream(streamed);
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['reply'];
      }
      throw ApiException(data['error'] ?? 'Failed to get response');
    } finally {
      client.close();
    }
  }

  /// Streaming chat. Yields text chunks as the backend forwards them from
  /// Gemini's SSE stream. The caller appends each chunk to the visible reply
  /// so the user sees tokens arrive in real time.
  ///
  /// `attachment`, when provided, is sent as `{mimeType, data}` (data is
  /// base64-encoded) so Gemini can read the image / document inline.
  static Stream<String> streamChatMessage(
    String message,
    List<Map<String, dynamic>> history, {
    Map<String, String>? attachment,
  }) async* {
    // One client owns this whole stream. We close it in `finally` so that
    // cancelling the consumer's subscription (the chatbot's stop button)
    // tears down the underlying HTTP connection instead of leaking it.
    final client = http.Client();
    try {
      Future<http.StreamedResponse> open() async {
        final request = http.Request('POST', Uri.parse('$_baseUrl/chat/stream/'));
        request.headers.addAll(_headers);
        request.headers['Accept'] = 'text/event-stream';
        request.body = jsonEncode({
          'message': message,
          'history': history,
          if (attachment != null) 'attachment': attachment,
        });
        return client.send(request);
      }

      var streamed = await open().timeout(const Duration(seconds: 30));

      // Refresh token + retry once on 401.
      if (streamed.statusCode == 401 && await _refreshAccessToken()) {
        streamed = await open().timeout(const Duration(seconds: 30));
      }

      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        String msg;
        try {
          msg = jsonDecode(body)['error'] ?? body;
        } catch (_) {
          msg = body;
        }
        throw ApiException(msg.isNotEmpty ? msg : 'Stream failed');
      }

      final lines = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        try {
          final obj = jsonDecode(payload) as Map<String, dynamic>;
          if (obj['error'] != null) {
            throw ApiException(obj['error'].toString());
          }
          if (obj['done'] == true) return;
          final text = obj['text'] as String?;
          if (text != null && text.isNotEmpty) yield text;
        } catch (e) {
          if (e is ApiException) rethrow;
          // malformed line — skip
        }
      }
    } finally {
      client.close();
    }
  }

  // ---------- Export Data ----------

  static Future<Uint8List> exportData(List<Map<String, dynamic>> appointments) async {
    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/users/export-data/'),
      headers: _headers,
      body: jsonEncode({'appointments': appointments}),
    ));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    final data = jsonDecode(response.body);
    throw ApiException(data['error'] ?? 'Failed to export data');
  }

  // ---------- Profile Photo ----------

  static Future<Uint8List?> getProfilePhoto() async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$_baseUrl/users/profile-photo/'),
      headers: {if (_token != null) 'Authorization': 'Bearer $_token'},
    ));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  static Future<bool> uploadProfilePhoto(Uint8List photoBytes) async {
    Future<http.Response> doUpload() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/users/profile-photo/'),
      );
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: 'profile.jpg',
      ));
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }

    var response = await doUpload();
    if (response.statusCode == 401) {
      final body = jsonDecode(response.body);
      if (body['code'] == 'token_expired' && await _refreshAccessToken()) {
        response = await doUpload();
      }
    }
    return response.statusCode == 200;
  }

  static Future<bool> deleteProfilePhoto() async {
    final response = await _authenticatedRequest(() => http.delete(
      Uri.parse('$_baseUrl/users/profile-photo/'),
      headers: _headers,
    ));
    return response.statusCode == 200;
  }

  // ---------- FCM Push Notifications ----------

  static Future<void> registerFcmToken(String token) async {
    await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/fcm/register/'),
      headers: _headers,
      body: jsonEncode({'fcm_token': token}),
    ));
  }

  static Future<String> testFcmNotification() async {
    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/fcm/test/'),
      headers: _headers,
    ));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['message'] ?? 'Sent';
    }
    throw ApiException(data['error'] ?? 'Failed to send test notification');
  }

  // ---------- Account ----------

  static Future<void> deactivateAccount() async {
    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/users/deactivate/'),
      headers: _headers,
    ));

    if (response.statusCode == 200) {
      await _clearSession();
      return;
    }
    final data = jsonDecode(response.body);
    throw ApiException(data['error'] ?? 'Failed to deactivate account');
  }

  static Future<void> deleteAccount() async {
    final response = await _authenticatedRequest(() => http.post(
      Uri.parse('$_baseUrl/users/delete/'),
      headers: _headers,
    ));

    if (response.statusCode == 200) {
      await _clearSession();
      return;
    }
    final data = jsonDecode(response.body);
    throw ApiException(data['error'] ?? 'Failed to delete account');
  }

  // ---------- Doctors & Pharmacies (admin-managed directory) ----------

  static Future<List<ContactEntry>> getDoctors() =>
      _getContacts('doctors');

  static Future<List<ContactEntry>> getPharmacies() =>
      _getContacts('pharmacies');

  static Future<ContactEntry> addDoctor(ContactEntry c) =>
      _addContact('doctors', c);

  static Future<ContactEntry> addPharmacy(ContactEntry c) =>
      _addContact('pharmacies', c);

  static Future<ContactEntry> updateDoctor(String id, ContactEntry c) =>
      _updateContact('doctors', id, c);

  static Future<ContactEntry> updatePharmacy(String id, ContactEntry c) =>
      _updateContact('pharmacies', id, c);

  static Future<void> deleteDoctor(String id) =>
      _deleteContact('doctors', id);

  static Future<void> deletePharmacy(String id) =>
      _deleteContact('pharmacies', id);

  static Future<List<ContactEntry>> _getContacts(String path) async {
    final response = await _authenticatedRequest(() => http.get(
          Uri.parse('$_baseUrl/$path/'),
          headers: _headers,
        ));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      return items.map(ContactEntry.fromJson).toList();
    }
    final data = jsonDecode(response.body);
    throw ApiException(data['error'] ?? 'Failed to load');
  }

  static Future<ContactEntry> _addContact(String path, ContactEntry c) async {
    final response = await _authenticatedRequest(() => http.post(
          Uri.parse('$_baseUrl/$path/'),
          headers: _headers,
          body: jsonEncode(c.toJson()),
        ));
    if (response.statusCode == 201) {
      return ContactEntry.fromJson(jsonDecode(response.body));
    }
    final data = jsonDecode(response.body);
    throw ApiException(data['error'] ?? 'Failed to add');
  }

  static Future<ContactEntry> _updateContact(
      String path, String id, ContactEntry c) async {
    final response = await _authenticatedRequest(() => http.put(
          Uri.parse('$_baseUrl/$path/$id/'),
          headers: _headers,
          body: jsonEncode(c.toJson()),
        ));
    if (response.statusCode == 200) {
      return ContactEntry.fromJson(jsonDecode(response.body));
    }
    final data = jsonDecode(response.body);
    throw ApiException(data['error'] ?? 'Failed to update');
  }

  static Future<void> _deleteContact(String path, String id) async {
    final response = await _authenticatedRequest(() => http.delete(
          Uri.parse('$_baseUrl/$path/$id/'),
          headers: _headers,
        ));
    if (response.statusCode == 200) return;
    final data = jsonDecode(response.body);
    throw ApiException(data['error'] ?? 'Failed to delete');
  }
}

/// A single day's opening window for a doctor or pharmacy, e.g.
/// {day: "Monday", from: "09:00", to: "17:00"}. Mirrors the medication
/// schedule pattern (day + times) but stores a from–till range instead of
/// individual times.
class AvailabilityEntry {
  final String day;
  String from; // HH:MM (24h)
  String to; // HH:MM (24h)

  AvailabilityEntry({required this.day, required this.from, required this.to});

  factory AvailabilityEntry.fromJson(Map<String, dynamic> json) =>
      AvailabilityEntry(
        day: json['day'] as String? ?? '',
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'day': day, 'from': from, 'to': to};
}

class ContactEntry {
  final String? id;
  final String name;
  final String address;
  final String phone;
  final double? latitude;
  final double? longitude;
  final String specialty;
  final String country;
  final List<AvailabilityEntry> availability;

  ContactEntry({
    this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.latitude,
    this.longitude,
    this.specialty = '',
    this.country = '',
    this.availability = const [],
  });

  factory ContactEntry.fromJson(Map<String, dynamic> json) => ContactEntry(
        id: json['id'] as String?,
        name: json['name'] ?? '',
        address: json['address'] ?? '',
        phone: json['phone'] ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        specialty: json['specialty'] ?? '',
        country: json['country'] ?? '',
        availability: ((json['availability'] as List?) ?? [])
            .whereType<Map>()
            .map((e) =>
                AvailabilityEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'phone': phone,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (specialty.isNotEmpty) 'specialty': specialty,
        if (country.isNotEmpty) 'country': country,
        if (availability.isNotEmpty)
          'availability': availability.map((e) => e.toJson()).toList(),
      };
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Thrown when login returns 403 because the account has been deactivated.
/// Carries the data the reactivation flow needs.
class DeactivatedAccountException extends ApiException {
  final String email;
  final bool isGoogleAccount;

  DeactivatedAccountException({
    required this.email,
    required this.isGoogleAccount,
  }) : super('This account has been deactivated.');
}
