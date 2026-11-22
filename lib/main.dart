import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(const PaperTradingViewApp());
}

class PaperTradingViewApp extends StatelessWidget {
  const PaperTradingViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paper TradingView Terminal',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const TerminalHomePage(),
    );
  }
}

class TerminalHomePage extends StatefulWidget {
  const TerminalHomePage({super.key});

  @override
  State<TerminalHomePage> createState() => _TerminalHomePageState();
}

class _TerminalHomePageState extends State<TerminalHomePage> {
  late final WebViewController _webViewController;
  final TextEditingController _cliController = TextEditingController();
  final List<String> _terminalOutput = [];
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = true;
  String _apiKey = '';
  double _paperBalance = 10000.0;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _loadSettings();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse('https://www.tradingview.com/chart/'));
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _paperBalance = prefs.getDouble('paper_balance') ?? 10000.0;
    });
    final key = await _secureStorage.read(key: 'api_key');
    if (key != null) {
      setState(() => _apiKey = key);
    }
  }

  Future<void> _savePaperBalance(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('paper_balance', value);
    setState(() => _paperBalance = value);
  }

  Future<void> _saveApiKey(String key) async {
    await _secureStorage.write(key: 'api_key', value: key);
    setState(() => _apiKey = key);
  }

  void _executeCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _terminalOutput.add('> $trimmed');
    });

    final parts = trimmed.split(RegExp(r'\s+'));
    final cmd = parts[0].toLowerCase();

    switch (cmd) {
      case 'buy':
        _handleBuy(parts);
        break;
      case 'sell':
        _handleSell(parts);
        break;
      case 'balance':
        _handleBalance();
        break;
      case 'vault':
        _handleVault(parts);
        break;
      case 'clear':
        setState(() => _terminalOutput.clear());
        break;
      case 'help':
        _handleHelp();
        break;
      default:
        setState(() {
          _terminalOutput.add('Unknown command: $cmd. Type "help" for available commands.');
        });
    }

    _cliController.clear();
  }

  void _handleBuy(List<String> parts) {
    if (parts.length < 3) {
      setState(() => _terminalOutput.add('Usage: buy <symbol> <amount>'));
      return;
    }
    final symbol = parts[1].toUpperCase();
    final amount = double.tryParse(parts[2]) ?? 0;
    final cost = amount * 100; // simplified price
    if (cost > _paperBalance) {
      setState(() => _terminalOutput.add('Insufficient paper balance. Current: \$${_paperBalance.toStringAsFixed(2)}'));
      return;
    }
    _savePaperBalance(_paperBalance - cost);
    setState(() {
      _terminalOutput.add('PAPER BUY: $amount $symbol @ \$100.00 = \$${cost.toStringAsFixed(2)}');
      _terminalOutput.add('New paper balance: \$${_paperBalance.toStringAsFixed(2)}');
    });
  }

  void _handleSell(List<String> parts) {
    if (parts.length < 3) {
      setState(() => _terminalOutput.add('Usage: sell <symbol> <amount>'));
      return;
    }
    final symbol = parts[1].toUpperCase();
    final amount = double.tryParse(parts[2]) ?? 0;
    final proceeds = amount * 100; // simplified price
    _savePaperBalance(_paperBalance + proceeds);
    setState(() {
      _terminalOutput.add('PAPER SELL: $amount $symbol @ \$100.00 = \$${proceeds.toStringAsFixed(2)}');
      _terminalOutput.add('New paper balance: \$${_paperBalance.toStringAsFixed(2)}');
    });
  }

  void _handleBalance() {
    setState(() {
      _terminalOutput.add('Paper Balance: \$${_paperBalance.toStringAsFixed(2)}');
    });
  }

  void _handleVault(List<String> parts) {
    if (parts.length < 2) {
      setState(() {
        _terminalOutput.add('Usage: vault set <api_key> | vault show | vault clear');
      });
      return;
    }
    final sub = parts[1].toLowerCase();
    switch (sub) {
      case 'set':
        if (parts.length < 3) {
          setState(() => _terminalOutput.add('Usage: vault set <api_key>'));
          return;
        }
        _saveApiKey(parts[2]);
        setState(() => _terminalOutput.add('API key saved securely.'));
        break;
      case 'show':
        setState(() {
          _terminalOutput.add('API Key: ${_apiKey.isEmpty ? "(not set)" : "${_apiKey.substring(0, 4)}...${_apiKey.substring(_apiKey.length - 4)}"}');
        });
        break;
      case 'clear':
        _secureStorage.delete(key: 'api_key');
        setState(() {
          _apiKey = '';
          _terminalOutput.add('API key cleared.');
        });
        break;
      default:
        setState(() => _terminalOutput.add('Unknown vault command: $sub'));
    }
  }

  void _handleHelp() {
    setState(() {
      _terminalOutput.addAll([
        'Available commands:',
        '  buy <symbol> <amount>   - Paper buy',
        '  sell <symbol> <amount>  - Paper sell',
        '  balance                 - Show paper balance',
        '  vault set <key>         - Save API key securely',
        '  vault show              - Show masked API key',
        '  vault clear             - Clear API key',
        '  clear                   - Clear terminal',
        '  help                    - Show this help',
      ]);
    });
  }

  @override
  void dispose() {
    _cliController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper TradingView Terminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          // TradingView WebView
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          // CLI Terminal
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _terminalOutput.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _terminalOutput[index],
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        '\$ ',
                        style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _cliController,
                          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter command...',
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          onSubmitted: _executeCommand,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.cyanAccent),
                        onPressed: () => _executeCommand(_cliController.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Custom Buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _webViewController.loadRequest(
                    Uri.parse('https://www.tradingview.com/chart/?symbol=BINANCE:BTCUSDT'),
                  ),
                  icon: const Icon(Icons.currency_bitcoin),
                  label: const Text('BTC'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _webViewController.loadRequest(
                    Uri.parse('https://www.tradingview.com/chart/?symbol=BINANCE:ETHUSDT'),
                  ),
                  icon: const Icon(Icons.token),
                  label: const Text('ETH'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _executeCommand('balance'),
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Balance'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _executeCommand('help'),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Help'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}