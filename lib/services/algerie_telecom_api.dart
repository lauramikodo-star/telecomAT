import 'dart:convert';
import 'package:http/http.dart' as http;

/// Algerie Telecom HTTP client for 4GLTE and ADSL/FTTH
/// Note: These endpoints are intended for the official mobile app.
/// They return JSON with text/html content-type and sometimes with BOM.
class AlgerieTelecomApi {
  static const String _base = 'https://paiement.algerietelecom.dz/AndroidApp/';

  // Captured headers from the official app (from your screenshots)
  static const Map<String, String> _baseHeaders = {
    'Authorization': 'Basic VEdkNzJyOTozUjcjd2FiRHNfSGpDNzg3IQ==',
    'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 10; vivo X21A Build/QD4A.200805.003)',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    'Connection': 'Keep-Alive',
    'Accept-Encoding': 'gzip',
    'Host': 'paiement.algerietelecom.dz',
  };

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, String> body) async {
    final uri = Uri.parse('$_base$endpoint');
    final res = await http.post(uri, headers: _baseHeaders, body: body).timeout(const Duration(seconds: 20));
    // Trim BOM and spaces then try decode to JSON
    final raw = res.body;
    final cleaned = raw.replaceAll('\uFEFF', '').trim();
    try {
      final jsonMap = json.decode(cleaned) as Map<String, dynamic>;
      return jsonMap;
    } catch (_) {
      return {'succes': '0', 'message': 'Invalid server response', 'raw': cleaned};
    }
  }

  /// Try to resolve a line. First ADSL/FTTH, then 4G LTE.
  /// Returns map with found(bool), system('ADSL'|'4G'), type('FTTH'|'ADSL'|'4GLTE'), ncli, offer, client.
  Future<Map<String, dynamic>> getLineInfo(String number) async {
    // 1) Try ADSL/FTTH lookup
    final adsl = await _post('internet_recharge.php', {
      'validerADSLco20': 'Confirmer',
      'ndco20': number,
    });
    if (adsl['succes'] == '1') {
      return {
        'found': true,
        'system': 'ADSL',
        'type': adsl['type'] ?? 'ADSL',
        'ncli': adsl['ncli']?.toString() ?? '',
        'offer': adsl['offre']?.toString() ?? 'Unknown',
        'client': adsl['type_client']?.toString() ?? 'Residential',
      };
    }

    // 2) Try 4G LTE lookup
    final lte = await _post('voucher_internet_suite.php', {
      'dahabiaco20': 'Confirmer',
      'nd_4gco20': number,
    });
    if (lte['succes'] == '1') {
      return {
        'found': true,
        'system': '4G',
        'type': lte['type']?.toString() ?? '4GLTE',
        'ncli': lte['ncli']?.toString() ?? '',
        'offer': lte['offre']?.toString() ?? 'Unknown',
        'client': '4G Subscriber',
      };
    }

    return {'found': false, 'message': adsl['message'] ?? lte['message'] ?? 'Not found'};
  }

  /// Get 4G LTE line info.
  Future<Map<String, dynamic>> get4gLineInfo(String number) async {
    final res = await _post('voucher_internet.php', {
      'dahabiaco20': 'Confirmer',
      'nd_4gco20': number,
    });
    return res;
  }

  /// Check debt for ADSL/FTTH lines. 4G returns not applicable.
  Future<Map<String, dynamic>> checkDebt(String number) async {
    final res = await _post('dette_paiement.php', {
      'ndco20': number,
      'validerco20': 'Confirmer',
      'nfactco20': '',
    });
    return res;
  }

  /// Recharge by voucher. Detects line type first.
  Future<Map<String, dynamic>> recharge({required String number, required String voucher}) async {
    final info = await getLineInfo(number);
    if (info['found'] != true) {
      return {'succes': '0', 'message': 'Line not found. Check the number.'};
    }

    final is4g = (info['system'] == '4G');
    final endpoint = is4g ? 'voucher_lte_suite.php' : 'internet_recharge.php';

    final body = {
      'rechargeco20': 'Recharger',
      'typeco20': info['type'].toString(), // e.g. 4GLTE or FTTH/ADSL
      'ndco20': number,
      'nclico20': info['ncli'].toString(),
      'voucherco20': voucher,
    };

    final res = await _post(endpoint, body);
    return res;
  }
}
