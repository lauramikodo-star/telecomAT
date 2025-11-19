import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_ocr/flutter_native_ocr.dart';
import '../services/algerie_telecom_api.dart';

class AppState extends ChangeNotifier {
  final api = AlgerieTelecomApi();
  Map<String, dynamic>? lineInfo;
  String? lastMessage;
  bool loading = false;

  Future<void> fetchInfo(String number) async {
    loading = true; notifyListeners();
    lineInfo = await api.getLineInfo(number);
    loading = false; notifyListeners();
  }

  Future<Map<String, dynamic>> pay(String number, String voucher) async {
    loading = true; notifyListeners();
    final res = await api.recharge(number: number, voucher: voucher);
    loading = false; notifyListeners();
    return res;
  }

  Future<Map<String, dynamic>> debt(String number) async {
    loading = true; notifyListeners();
    final res = await api.checkDebt(number);
    loading = false; notifyListeners();
    return res;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _numberCtrl = TextEditingController();
  final _voucherCtrl = TextEditingController();

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _scanVoucher() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final ocr = FlutterNativeOcr();
      try {
        String text = await ocr.recognizeText(image.path);
        // Extract the first 16-digit number from the recognized text
        final RegExp regExp = RegExp(r'\d{16}');
        final Match? match = regExp.firstMatch(text);
        if (match != null) {
          _voucherCtrl.text = match.group(0)!;
          _showSnack('Voucher scanned');
        } else {
          _showSnack('No 16-digit number found', color: Colors.red);
        }
      } catch (e) {
        _showSnack('Error recognizing text: $e', color: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('AT DZ Recharge')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _numberCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone / Line number',
                  hintText: '021.. or 05..',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voucherCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Voucher code',
                        prefixIcon: Icon(Icons.confirmation_number),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _scanVoucher,
                    icon: const Icon(Icons.image_search),
                    tooltip: 'Scan from image',
                  )
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: state.loading ? null : () async {
                      final n = _numberCtrl.text.trim();
                      if (n.isEmpty) return _showSnack('Enter number');
                      await state.fetchInfo(n);
                      final info = state.lineInfo;
                      if (info?['found'] == true) {
                        _showSnack('Found ${info!['type']} | NCLI: ${info['ncli']}');
                      } else {
                        _showSnack('Not found', color: Colors.red);
                      }
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Line infos'),
                  ),
                  ElevatedButton.icon(
                    onPressed: state.loading ? null : () async {
                      final n = _numberCtrl.text.trim();
                      final v = _voucherCtrl.text.trim();
                      if (n.isEmpty || v.isEmpty) return _showSnack('Enter number and voucher');
                      final res = await state.pay(n, v);
                      if (res['succes'] == '1') {
                        _showSnack('Recharge OK: ${res['num_trans'] ?? ''}', color: Colors.green);
                      } else {
                        _showSnack(res['message']?.toString() ?? 'Recharge failed', color: Colors.red);
                      }
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text('Recharge'),
                  ),
                  ElevatedButton.icon(
                    onPressed: state.loading ? null : () async {
                      final n = _numberCtrl.text.trim();
                      if (n.isEmpty) return _showSnack('Enter number');
                      final res = await state.debt(n);
                      if (res['succes'] == '1') {
                        _showSnack('Debt exists', color: Colors.orange);
                      } else {
                        _showSnack(res['message']?.toString() ?? 'No debt', color: Colors.green);
                      }
                    },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Debt info'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.loading) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              if (state.lineInfo != null) _InfoCard(data: state.lineInfo!),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data['found'] != true) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.account_circle),
              const SizedBox(width: 8),
              Text('${data['system']} - ${data['type']}', style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            Text('NCLI: ${data['ncli']}'),
            Text('Offer: ${data['offer']}'),
            Text('Client: ${data['client']}'),
          ],
        ),
      ),
    );
  }
}

