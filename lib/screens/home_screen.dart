import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/algerie_telecom_api.dart';
import '../services/gemini_api.dart';

class AppState extends ChangeNotifier {
  final api = AlgerieTelecomApi();
  // TODO: Replace with your actual Gemini API key.
  final geminiApi = GeminiApi("YOUR_GEMINI_API_KEY");
  Map<String, dynamic>? lineInfo;
  Map<String, dynamic>? line4gInfo;
  String? lastMessage;
  bool loading = false;
  String? _authToken;
  Map<String, dynamic>? accountInfo;

  bool get isLoggedIn => _authToken != null;

  Future<void> fetchInfo(String number) async {
    loading = true;
    notifyListeners();
    lineInfo = await api.getLineInfo(number);
    loading = false;
    notifyListeners();
  }

  Future<void> fetch4gInfo(String number) async {
    loading = true;
    notifyListeners();
    line4gInfo = await api.get4gLineInfo(number);
    loading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> pay(String number, String voucher) async {
    loading = true;
    notifyListeners();
    final res = await api.recharge(number: number, voucher: voucher);
    loading = false;
    notifyListeners();
    return res;
  }

  Future<Map<String, dynamic>> debt(String number) async {
    loading = true;
    notifyListeners();
    final res = await api.checkDebt(number);
    loading = false;
    notifyListeners();
    return res;
  }

  Future<Map<String, dynamic>> login(String number, String password) async {
    loading = true;
    notifyListeners();
    final res = await api.login(number, password);
    if (res['code'] == 0) {
      _authToken = res['authorisation']['token'];
      accountInfo = await api.getAccountInfo(_authToken!);
    }
    loading = false;
    notifyListeners();
    return res;
  }

  void logout() {
    _authToken = null;
    accountInfo = null;
    notifyListeners();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _numberCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _voucherCtrl = TextEditingController();
  final _4gNumberCtrl = TextEditingController();

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _scanVoucher() async {
    final state = context.read<AppState>();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _showSnack('⚡ Scanning with AI...', color: Colors.orange);
      try {
        final code = await state.geminiApi.extractVoucherCode(File(image.path));
        _voucherCtrl.text = code;
        _showSnack('✅ Voucher code found!', color: Colors.green);
      } catch (e) {
        _showSnack('❌ Error: $e', color: Colors.red);
      }
    }
  }

  void _showApiResponseDialog(Map<String, dynamic> response) {
    final bool isSuccess = response['succes'] == '1' || response.containsKey('num_trans') || response['code'] == 0;
    final String title = isSuccess ? '✅ Successful!' : '❌ Failed';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: response.entries.map((entry) {
              final key = entry.key.replaceAll('_', ' ').toUpperCase();
              final value = entry.value?.toString() ?? 'N/A';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      TextSpan(text: '$key: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: value),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AT DZ Recharge'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
            Tab(text: 'ADSL/Fibre', icon: Icon(Icons.router)),
            Tab(text: '4G LTE', icon: Icon(Icons.four_g_mobiledata)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildDashboardTab(state),
          _buildAdslFibreTab(state),
          _build4gLteTab(state),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(AppState state) {
    if (state.isLoggedIn) {
      return _buildAccountInfo(state);
    } else {
      return _buildLoginForm(state);
    }
  }

  Widget _buildLoginForm(AppState state) {
    return SingleChildScrollView(
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
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: state.loading
                ? null
                : () async {
                    final n = _numberCtrl.text.trim();
                    final p = _passwordCtrl.text.trim();
                    if (n.isEmpty || p.isEmpty) {
                      return _showSnack('Enter number and password');
                    }
                    final res = await state.login(n, p);
                    if (res['code'] != 0) {
                      _showApiResponseDialog(res);
                    }
                  },
            icon: const Icon(Icons.login),
            label: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfo(AppState state) {
    final info = state.accountInfo!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Welcome, ${info['prenom']} ${info['nom']}!', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _InfoCard(data: info),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: state.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildAdslFibreTab(AppState state) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              const Text("IDOOM INTERNET (ADSL / Fibre)"),
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
                    onPressed: state.loading
                        ? null
                        : () async {
                            final n = _numberCtrl.text.trim();
                            if (n.isEmpty) return _showSnack('Enter number');
                            await state.fetchInfo(n);
                            final info = state.lineInfo;
                            if (info?['found'] == true) {
                              _showSnack(
                                  'Found ${info!['type']} | NCLI: ${info['ncli']}');
                            } else {
                              _showSnack('Not found', color: Colors.red);
                            }
                          },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Line infos'),
                  ),
                  ElevatedButton.icon(
                    onPressed: state.loading
                        ? null
                        : () async {
                            final n = _numberCtrl.text.trim();
                            final v = _voucherCtrl.text.trim();
                            if (n.isEmpty || v.isEmpty) {
                              return _showSnack('Enter number and voucher');
                            }
                            final res = await state.pay(n, v);
                      _showApiResponseDialog(res);
                          },
                    icon: const Icon(Icons.payment),
                    label: const Text('Recharge'),
                  ),
                  ElevatedButton.icon(
                    onPressed: state.loading
                        ? null
                        : () async {
                            final n = _numberCtrl.text.trim();
                            if (n.isEmpty) return _showSnack('Enter number');
                            final res = await state.debt(n);
                            if (res['succes'] == '1') {
                              _showSnack('Debt exists', color: Colors.orange);
                            } else {
                              _showSnack(
                                  res['message']?.toString() ?? 'No debt',
                                  color: Colors.green);
                            }
                          },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Debt info'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.lineInfo != null) _InfoCard(data: state.lineInfo!),
            ],
          ),
        ),
    );
  }

  Widget _build4gLteTab(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("IDOOM 4G LTE"),
          TextField(
            controller: _4gNumberCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '4G LTE Line number',
              hintText: '213...',
              prefixIcon: Icon(Icons.phone_android),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: state.loading
                ? null
                : () async {
                    final n = _4gNumberCtrl.text.trim();
                    if (n.isEmpty) return _showSnack('Enter 4G number');
                    await state.fetch4gInfo(n);
                    final info = state.line4gInfo;
                    if (info?['succes'] == '1') {
                      _showSnack('Found ${info!['type']} | NCLI: ${info['ncli']}');
                    } else {
                      _showSnack('Not found', color: Colors.red);
                    }
                  },
            icon: const Icon(Icons.info_outline),
            label: const Text('Get 4G LTE Info'),
          ),
          const SizedBox(height: 16),
          if (state.loading) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          if (state.line4gInfo != null)
            _4gInfoCard(data: state.line4gInfo!),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.account_circle),
              const SizedBox(width: 8),
              Text('${data['offre'] ?? data['type']}',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            if (data.containsKey('ncli')) Text('NCLI: ${data['ncli']}'),
            if (data.containsKey('client')) Text('Client: ${data['client']}'),
            if (data.containsKey('adresse')) Text('Address: ${data['adresse']}'),
            if (data.containsKey('status')) Text('Status: ${data['status']}'),
            if (data.containsKey('dette')) Text('Debt: ${data['dette']}'),
            if (data.containsKey('credit')) Text('Credit: ${data['credit']}'),
            if (data.containsKey('balance')) Text('Balance: ${data['balance']}'),
            if (data.containsKey('dateexp')) Text('Expiry Date: ${data['dateexp']}'),
            if (data.containsKey('mobile')) Text('Mobile: ${data['mobile']}'),
          ],
        ),
      ),
    );
  }
}

class _4gInfoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _4gInfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data['succes'] != '1') return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.four_g_mobiledata),
              const SizedBox(width: 8),
              Text('${data['type']}',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            Text('NCLI: ${data['ncli']}'),
          ],
        ),
      ),
    );
  }
}
