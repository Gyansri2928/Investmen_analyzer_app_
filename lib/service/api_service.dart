import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ✅ UPDATED: Points to your live Vercel Backend
static const String baseUrl = "https://property-backend-woad.vercel.app/api";
  static Future<Map<String, dynamic>> calculateProperty(
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('$baseUrl/calculate');

    try {
      print("Attempting to connect to: $url"); // Debug print
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Server Error: ${response.body}");
      }
    } catch (e) {
      print("Connection Error: $e");
      throw Exception(
        "Failed to connect. Make sure phone & PC are on same WiFi.",
      );
    }
  }
}
