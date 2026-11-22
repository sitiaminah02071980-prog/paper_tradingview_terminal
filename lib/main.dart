import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PaperTerminalChartApp());
}

class PaperTerminalChartApp extends StatelessWidget {
  const PaperTerminalChartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paper TradingView Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF22C55E),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF111827),
        ),
      ),
      home: const PaperChartTerminalPage(),
    );
  }
}

class PendingPaperOrder {
  final String side;
  final String symbol;
  final double qty;
  final double price;
  final double total;

  PendingPaperOrder({
    required this.side,
    required this.symbol,
    required this.qty,
    required this.price,
    required this.total,
  });
}

class CustomCmdButton {
  final String label;
  final String command;

  const CustomCmdButton({
    required this.label,
    required this.command,
  });

  Map<String, String> toMap() => {'label': label, 'command': command};

  factory CustomCmdButton.fromMap(Map<String, dynamic> map) {
    return CustomCmdButton(
      label: (map['label'] ?? '').toString(),
      command: (map['command'] ?? '').toString(),
    );
  }
}

class PaperChartTerminalPage extends StatefulWidget {
  const PaperChartTerminalPage({super.key});

  @override
  State<PaperChartTerminalPage> createState() => _PaperChartTerminalPageState();
}

class _PaperChartTerminalPageState extends State<PaperChartTerminalPage> {
  static const String _customBtnStorageKey = 'paper_custom_cmd_buttons_v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final WebViewController _tvController;
  final TextEditingController _cmdCtrl = TextEditingController();

  String _activeSymbol = 'BTCUSDT';
  final String _interval = '15';
  double _balanceUsd = 10000.0;
  String _accountId = 'TRD-PAPER';
  bool _hasApiKey = false;

  final Map<String, double> _prices = {
    'BTCUSDT': 88420.50,
    'ETHUSDT': 3120.00,
    'SOLUSDT': 195.40,
  };

  final Map<String, double> _positions = {
    'BTCUSDT': 0.05,
  };

  PendingPaperOrder? _pendingOrder;
  String _lastStatus =
      'PAPER MODE aktif. Gunakan tombol di bawah atau ketik perintah.';

  final List<CustomCmdButton> _defaultButtons = const [
    CustomCmdButton(label: 'Price', command: 'price'),
    CustomCmdButton(label: 'Balance', command: 'balance'),
    CustomCmdButton(label: 'Buy 0.01 BTC', command: 'buy 0.01 btc'),
    CustomCmdButton(label: 'Env', command: 'env'),
  ];

  List<CustomCmdButton> _customButtons = [];

  @override
  void initState() {
    super.initState();
    _loadState();
    _tvController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0E14))
      ..loadHtmlString(_buildTradingViewHtml(_activeSymbol, _interval));
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customBtnStorageKey);
    final savedAcc = await _secureStorage.read(key: 'trd_account_id');
    final savedKey = await _secureStorage.read(key: 'trd_api_key');

    setState(() {
      if (savedAcc != null && savedAcc.isNotEmpty) {
        _accountId = savedAcc;
      }
      _hasApiKey = savedKey != null && savedKey.isNotEmpty;
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as List<dynamic>;
          _customButtons = decoded
              .map((item) =>
                  CustomCmdButton.fromMap(Map<String, dynamic>.from(item as Map)))
              .where((b) => b.label.isNotEmpty && b.command.isNotEmpty)
              .toList();
        } catch (_) {}
      }
    });
  }

  Future<void> _persistCustomButtons() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_customButtons.map((b) => b.toMap()).toList());
    await prefs.setString(_customBtnStorageKey, encoded);
  }

  Future<void> _openAccountApiDialog() async {
    final accCtrl = TextEditingController(text: _accountId);
    final keyCtrl = TextEditingController(
      text: (await _secureStorage.read(key: 'trd_api_key')) ?? '',
    );
    final secretCtrl = TextEditingController(
      text: (await _secureStorage.read(key: 'trd_api_secret')) ?? '',
    );

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: const Text(
            'Akun & API Vault (Paper Mode)',
            style: TextStyle(fontFamily: 'monospace', fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: accCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ID Akun Trading',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'API Key (Opsional di Paper Mode)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: secretCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Secret',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            FilledButton(
              onPressed: () async {
                final acc = accCtrl.text.trim();
                final key = keyCtrl.text.trim();
                final sec = secretCtrl.text.trim();
                if (acc.isNotEmpty) {
                  await _secureStorage.write(key: 'trd_account_id', value: acc);
                }
                if (key.isNotEmpty) {
                  await _secureStorage.write(key: 'trd_api_key', value: key);
                } else {
                  await _secureStorage.delete(key: 'trd_api_key');
                }
                if (sec.isNotEmpty) {
                  await _secureStorage.write(key: 'trd_api_secret', value: sec);
                } else {
                  await _secureStorage.delete(key: 'trd_api_secret');
                }
                setState(() {
                  if (acc.isNotEmpty) _accountId = acc;
                  _hasApiKey = key.isNotEmpty;
                  _lastStatus =
                      'Konfigurasi akun ($_accountId) & API vault diperbarui.';
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCreateButtonDialog() async {
    final labelCtrl = TextEditingController();
    final cmdCtrl = TextEditingController();

    final created = await showDialog<CustomCmdButton>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: const Text(
            'Buat Tombol Kustom',
            style: TextStyle(fontFamily: 'monospace', fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Tombol (cth: Buy SOL)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cmdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Perintah Terminal (cth: buy 1 sol)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                final command = cmdCtrl.text.trim();
                if (label.isEmpty || command.isEmpty) return;
                Navigator.pop(
                    ctx, CustomCmdButton(label: label, command: command));
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (created != null) {
      setState(() {
        _customButtons.add(created);
        _lastStatus =
            'Tombol "${created.label}" ditambahkan -> `${created.command}`';
      });
      await _persistCustomButtons();
    }
  }

  Future<void> _removeCustomButton(int index) async {
    final removed = _customButtons[index];
    setState(() {
      _customButtons.removeAt(index);
      _lastStatus = 'Tombol kustom "${removed.label}" dihapus.';
    });
    await _persistCustomButtons();
  }

  String _buildTradingViewHtml(String symbol, String interval) {
    final tvSymbol = 'BINANCE:$symbol';
    final config = jsonEncode({
      'autosize': true,
      'symbol': tvSymbol,
      'interval': interval,
      'timezone': 'Asia/Jakarta',
      'theme': 'dark',
      'style': '1',
      'locale': 'id',
      'enable_publishing': false,
      'hide_top_toolbar': false,
      'allow_symbol_change': false,
      'save_image': false,
      'backgroundColor': 'rgba(10, 14, 20, 1)',
    });

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body, #tv_wrap {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background-color: #0A0E14;
      overflow: hidden;
    }
  </style>
</head>
<body>
  <div id="tv_wrap">
    <div class="tradingview-widget-container" style="width:100%;height:100%;">
      <div id="tv_chart" style="width:100%;height:100%;"></div>
      <script type="text/javascript" src="https://s3.tradingview.com/tv.js"></script>
      <script type="text/javascript">
        new TradingView.widget($config);
      </script>
    </div>
  </div>
</body>
</html>
''';
  }

  void _setChartSymbol(String symbol) {
    if (!_prices.containsKey(symbol)) return;
    setState(() {
      _activeSymbol = symbol;
      _lastStatus =
          'Chart dialihkan ke $symbol (\$${_prices[symbol]!.toStringAsFixed(2)})';
    });
    _tvController.loadHtmlString(_buildTradingViewHtml(_activeSymbol, _interval));
  }

  String _normalizeSymbol(String raw) {
    final upper = raw.toUpperCase().replaceAll('/', '');
    if (_prices.containsKey(upper)) return upper;
    final withUsdt = '${upper}USDT';
    if (_prices.containsKey(withUsdt)) return withUsdt;
    return upper;
  }

  void _submitCommand(String raw) {
    final cmd = raw.trim();
    if (cmd.isEmpty) return;
    _cmdCtrl.clear();
    final lower = cmd.toLowerCase();

    if (_pendingOrder != null) {
      if (lower == 'y' || lower == 'ya' || lower == 'yes') {
        final o = _pendingOrder!;
        setState(() {
          _pendingOrder = null;
          if (o.side == 'BUY') {
            _balanceUsd -= o.total;
            _positions[o.symbol] = (_positions[o.symbol] ?? 0.0) + o.qty;
          } else {
            _positions[o.symbol] = (_positions[o.symbol] ?? 0.0) - o.qty;
            _balanceUsd += o.total;
          }
          _lastStatus =
              '[PAPER EXEC] ${o.side} ${o.qty} ${o.symbol} @ \$${o.price.toStringAsFixed(2)} | Kas: \$${_balanceUsd.toStringAsFixed(2)}';
        });
        return;
      } else if (lower == 'n' || lower == 'batal' || lower == 'no') {
        setState(() {
          _pendingOrder = null;
          _lastStatus = '[PAPER CANCEL] Order dibatalkan.';
        });
        return;
      } else {
        setState(() {
          _lastStatus =
              'Konfirmasi order aktif: ketik `y` untuk eksekusi atau `n` untuk batal.';
        });
        return;
      }
    }

    if (lower == 'env') {
      setState(() {
        _lastStatus =
            'ACCOUNT=$_accountId | MODE=PAPER | API=${_hasApiKey ? "SET" : "NONE"}';
      });
      return;
    }

    if (lower == 'balance' || lower == 'saldo') {
      final posText = _positions.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key}:${e.value}')
          .join(', ');
      setState(() {
        _lastStatus =
            'Kas: \$${_balanceUsd.toStringAsFixed(2)} | Posisi: ${posText.isEmpty ? "-" : posText}';
      });
      return;
    }

    if (lower.startsWith('price')) {
      final parts = lower.split(RegExp(r'\s+'));
      final sym = parts.length > 1 ? _normalizeSymbol(parts[1]) : _activeSymbol;
      final px = _prices[sym];
      setState(() {
        _lastStatus = px != null
            ? '$sym => \$${px.toStringAsFixed(2)} (PAPER)'
            : 'Simbol $sym tidak tersedia (btc, eth, sol).';
      });
      return;
    }

    if (lower.startsWith('chart ')) {
      final parts = lower.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final sym = _normalizeSymbol(parts[1]);
        if (_prices.containsKey(sym)) {
          _setChartSymbol(sym);
          return;
        }
      }
      setState(() {
        _lastStatus = 'Format: chart <btc|eth|sol>';
      });
      return;
    }

    if (lower.startsWith('buy ') || lower.startsWith('sell ')) {
      final parts = lower.split(RegExp(r'\s+'));
      if (parts.length < 3) {
        setState(() {
          _lastStatus = 'Format: buy <qty> <symbol> atau sell <qty> <symbol>';
        });
        return;
      }
      final side = parts[0].toUpperCase();
      final qty = double.tryParse(parts[1]);
      final sym = _normalizeSymbol(parts[2]);
      final px = _prices[sym];

      if (qty == null || qty <= 0 || px == null) {
        setState(() {
          _lastStatus = 'Perintah tidak valid. Contoh: buy 0.05 btc';
        });
        return;
      }

      final total = qty * px;
      if (side == 'BUY' && total > _balanceUsd) {
        setState(() {
          _lastStatus =
              'Ditolak: butuh \$${total.toStringAsFixed(2)}, saldo \$${_balanceUsd.toStringAsFixed(2)}.';
        });
        return;
      }

      final currentQty = _positions[sym] ?? 0.0;
      if (side == 'SELL' && qty > currentQty) {
        setState(() {
          _lastStatus = 'Ditolak: posisi $sym hanya $currentQty.';
        });
        return;
      }

      if (_activeSymbol != sym) {
        _setChartSymbol(sym);
      }

      setState(() {
        _pendingOrder = PendingPaperOrder(
          side: side,
          symbol: sym,
          qty: qty,
          price: px,
          total: total,
        );
        _lastStatus =
            'Preview $side $qty $sym @ ~\$${px.toStringAsFixed(2)} (Total \$${total.toStringAsFixed(2)}) -> ketik `y` atau `n`';
      });
      return;
    }

    setState(() {
      _lastStatus =
          'Perintah: env | price [sym] | balance | chart <sym> | buy <qty> <sym> | sell <qty> <sym>';
    });
  }

  Widget _buildPillButton({
    required String label,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Color bgColor = const Color(0xFF1E293B),
    Color borderColor = const Color(0xFF334155),
    Color textColor = const Color(0xFFE2E8F0),
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: textColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: const Color(0xFF111827),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14532D),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PAPER',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _prices.keys.map((sym) {
                          final active = sym == _activeSymbol;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                sym,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              selected: active,
                              onSelected: (_) => _setChartSymbol(sym),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Akun & API Vault',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.vpn_key_outlined,
                      size: 18,
                      color: _hasApiKey
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF94A3B8),
                    ),
                    onPressed: _openAccountApiDialog,
                  ),
                ],
              ),
            ),
            Expanded(
              child: WebViewWidget(controller: _tvController),
            ),
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _lastStatus,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF93C5FD),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._defaultButtons.map(
                          (btn) => _buildPillButton(
                            label: btn.label,
                            onTap: () => _submitCommand(btn.command),
                          ),
                        ),
                        ...List.generate(_customButtons.length, (index) {
                          final btn = _customButtons[index];
                          return _buildPillButton(
                            label: btn.label,
                            bgColor: const Color(0xFF0C4A6E),
                            borderColor: const Color(0xFF0284C7),
                            textColor: const Color(0xFFE0F2FE),
                            onTap: () => _submitCommand(btn.command),
                            onLongPress: () => _removeCustomButton(index),
                          );
                        }),
                        _buildPillButton(
                          label: 'Tombol',
                          icon: Icons.add,
                          bgColor: const Color(0xFF14532D),
                          borderColor: const Color(0xFF22C55E),
                          textColor: const Color(0xFFDCFCE7),
                          onTap: _openCreateButtonDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        'paper@term:~\$ ',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _cmdCtrl,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'input perintah...',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: InputBorder.none,
                          ),
                          onSubmitted: _submitCommand,
                        ),
                      ),
                      if (_pendingOrder != null) ...[
                        _buildPillButton(
                          label: 'Y',
                          bgColor: const Color(0xFF14532D),
                          borderColor: const Color(0xFF22C55E),
                          textColor: const Color(0xFF4ADE80),
                          onTap: () => _submitCommand('y'),
                        ),
                        _buildPillButton(
                          label: 'N',
                          bgColor: const Color(0xFF450A0A),
                          borderColor: const Color(0xFFEF4444),
                          textColor: const Color(0xFFFCA5A5),
                          onTap: () => _submitCommand('n'),
                        ),
                      ] else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.play_arrow,
                              color: Color(0xFF22C55E)),
                          onPressed: () => _submitCommand(_cmdCtrl.text),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
