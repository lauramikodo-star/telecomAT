import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiApi {
  final String apiKey;

  GeminiApi(this.apiKey);

  Future<String> extractVoucherCode(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent?key=$apiKey');

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": "Extract the 16-digit voucher code. Return ONLY the digits."},
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Image,
              }
            }
          ]
        }
      ]
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['candidates'][0]['content']['parts'][0]['text'] ?? '';
      final code = text.replaceAll(RegExp(r'[^0-9]'), '');
      if (code.length == 16) {
        return code;
      } else {
        throw Exception('AI found "$code" (Length: ${code.length})');
      }
    } else {
      final error = jsonDecode(response.body)['error'];
      throw Exception('AI Error: ${error['message'] ?? 'Unknown'}');
    }
  }
}
