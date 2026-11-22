import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const PaperTradingViewApp());
}

class PaperTradingViewApp extends StatelessWidget {
  const PaperTradingViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trading Terminal Pro',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MAIN SHELL - Bottom Navigation
// ═══════════════════════════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ChartPage(),
    const TerminalPage(),
    const PortfolioPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.candlestick_chart), label: 'Chart'),
          NavigationDestination(icon: Icon(Icons.terminal), label: 'Terminal'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CHART PAGE - Multi-Timeframe TradingView
// ═══════════════════════════════════════════════════════════════
class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  String _symbol = 'BINANCE:BTCUSDT';
  String _timeframe = '1H';
  final List<String> _symbols = ['BINANCE:BTCUSDT', 'BINANCE:ETHUSDT', 'BINANCE:BNBUSDT', 'BINANCE:SOLUSDT', 'BINANCE:XRPUSDT'];
  final List<String> _timeframes = ['1m', '5m', '15m', '30m', '1H', '4H', '1D', '1W'];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
      ))
      ..loadRequest(Uri.parse(_buildChartUrl()));
  }

  String _buildChartUrl() {
    final tf = _timeframe.toLowerCase().replaceAll('m', '').replaceAll('h', 'H').replaceAll('d', 'D').replaceAll('w', 'W');
    return 'https://www.tradingview.com/chart/?symbol=$_symbol&interval=$tf';
  }

  void _reloadChart() {
    _webViewController.loadRequest(Uri.parse(_buildChartUrl()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Timeframe Chart'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reloadChart),
        ],
      ),
      body: Column(
        children: [
          // Symbol & Timeframe selectors
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _symbol,
                    decoration: const InputDecoration(labelText: 'Symbol', border: OutlineInputBorder()),
                    items: _symbols.map((s) => DropdownMenuItem(value: s, child: Text(s.split(':')[1]))).toList(),
                    onChanged: (v) { setState(() => _symbol = v!); _reloadChart(); },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _timeframe,
                    decoration: const InputDecoration(labelText: 'Timeframe', border: OutlineInputBorder()),
                    items: _timeframes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) { setState(() => _timeframe = v!); _reloadChart(); },
                  ),
                ),
              ],
            ),
          ),
          // Quick timeframe chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: _timeframes.map((tf) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(tf),
                  selected: _timeframe == tf,
                  onSelected: (_) { setState(() => _timeframe = tf); _reloadChart(); },
                ),
              )).toList(),
            ),
          ),
          // WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (_isLoading) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TERMINAL PAGE - CLI with Paper & Real Trading
// ═══════════════════════════════════════════════════════════════
class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final TextEditingController _cliController = TextEditingController();
  final List<String> _terminalOutput = [];
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final NotificationService _notifService = NotificationService();

  bool _isRealMode = false;
  double _paperBalance = 10000.0;
  String _binanceApiKey = '';
  String _binanceSecret = '';
  String _mt5Login = '';
  String _mt5Password = '';
  String _mt5Server = '';
  String _aiApiKey = '';
  String _aiProvider = 'openai'; // openai, claude, gemini
  final List<Map<String, dynamic>> _positions = [];
  final List<Map<String, dynamic>> _tradeHistory = [];
  final List<Map<String, String>> _aiChatHistory = [];
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _notifService.init();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _paperBalance = prefs.getDouble('paper_balance') ?? 10000.0;
      _isRealMode = prefs.getBool('real_mode') ?? false;
    });
    _binanceApiKey = await _secureStorage.read(key: 'binance_api_key') ?? '';
    _binanceSecret = await _secureStorage.read(key: 'binance_secret') ?? '';
    _mt5Login = await _secureStorage.read(key: 'mt5_login') ?? '';
    _mt5Password = await _secureStorage.read(key: 'mt5_password') ?? '';
    _mt5Server = await _secureStorage.read(key: 'mt5_server') ?? '';
    _aiApiKey = await _secureStorage.read(key: 'ai_api_key') ?? '';
    _aiProvider = await _secureStorage.read(key: 'ai_provider') ?? 'openai';
  }

  Future<void> _savePaperBalance(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('paper_balance', v);
    setState(() => _paperBalance = v);
  }

  void _log(String msg) => setState(() => _terminalOutput.add(msg));

  void _executeCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    _log('> $trimmed');
    final parts = trimmed.split(RegExp(r'\s+'));
    final cmd = parts[0].toLowerCase();

    switch (cmd) {
      case 'buy': _handleBuy(parts); break;
      case 'sell': _handleSell(parts); break;
      case 'balance': _handleBalance(); break;
      case 'positions': _handlePositions(); break;
      case 'history': _handleHistory(); break;
      case 'mode': _handleMode(parts); break;
      case 'vault': _handleVault(parts); break;
      case 'ai': _handleAI(parts); break;
      case 'signal': _handleSignal(parts); break;
      case 'clear': setState(() => _terminalOutput.clear()); break;
      case 'help': _handleHelp(); break;
      default: _log('Unknown command: $cmd. Type "help".');
    }
    _cliController.clear();
  }

  void _handleBuy(List<String> parts) {
    if (parts.length < 3) { _log('Usage: buy <symbol> <amount>'); return; }
    final symbol = parts[1].toUpperCase();
    final amount = double.tryParse(parts[2]) ?? 0;
    if (_isRealMode) {
      _log('🔴 REAL MODE: Executing buy $amount $symbol via broker...');
      _executeRealOrder('BUY', symbol, amount);
    } else {
      final cost = amount * 100;
      if (cost > _paperBalance) { _log('Insufficient balance. Current: \$${_paperBalance.toStringAsFixed(2)}'); return; }
      _savePaperBalance(_paperBalance - cost);
      _positions.add({'symbol': symbol, 'side': 'BUY', 'amount': amount, 'price': 100.0, 'time': DateTime.now()});
      _tradeHistory.add({'action': 'BUY', 'symbol': symbol, 'amount': amount, 'price': 100.0, 'time': DateTime.now(), 'mode': 'PAPER'});
      _log('PAPER BUY: $amount $symbol @ \$100.00 = \$${cost.toStringAsFixed(2)}');
      _log('New balance: \$${_paperBalance.toStringAsFixed(2)}');
      _notifService.show('Paper Buy Executed', '$amount $symbol @ \$100.00');
    }
  }

  void _handleSell(List<String> parts) {
    if (parts.length < 3) { _log('Usage: sell <symbol> <amount>'); return; }
    final symbol = parts[1].toUpperCase();
    final amount = double.tryParse(parts[2]) ?? 0;
    if (_isRealMode) {
      _log('🔴 REAL MODE: Executing sell $amount $symbol via broker...');
      _executeRealOrder('SELL', symbol, amount);
    } else {
      final proceeds = amount * 100;
      _savePaperBalance(_paperBalance + proceeds);
      _positions.add({'symbol': symbol, 'side': 'SELL', 'amount': amount, 'price': 100.0, 'time': DateTime.now()});
      _tradeHistory.add({'action': 'SELL', 'symbol': symbol, 'amount': amount, 'price': 100.0, 'time': DateTime.now(), 'mode': 'PAPER'});
      _log('PAPER SELL: $amount $symbol @ \$100.00 = \$${proceeds.toStringAsFixed(2)}');
      _log('New balance: \$${_paperBalance.toStringAsFixed(2)}');
      _notifService.show('Paper Sell Executed', '$amount $symbol @ \$100.00');
    }
  }

  Future<void> _executeRealOrder(String action, String symbol, double amount) async {
    // Binance API integration
    if (_binanceApiKey.isNotEmpty) {
      try {
        final url = Uri.parse('https://api.binance.com/api/v3/order');
        final response = await http.post(url, headers: {
          'X-MBX-APIKEY': _binanceApiKey,
        }, body: {
          'symbol': symbol,
          'side': action,
          'type': 'MARKET',
          'quantity': amount.toString(),
        });
        if (response.statusCode == 200) {
          _log('✅ Order executed on Binance: $action $amount $symbol');
          _notifService.show('Real Order Executed', '$action $amount $symbol on Binance');
          _tradeHistory.add({'action': action, 'symbol': symbol, 'amount': amount, 'price': 0.0, 'time': DateTime.now(), 'mode': 'REAL'});
        } else {
          _log('❌ Binance error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        _log('❌ Binance connection error: $e');
      }
    } else if (_mt5Login.isNotEmpty) {
      _log('MT5 integration: Use metatrader-terminal MCP for order execution');
      _log('Command: $action $symbol $amount (send via MT5 terminal)');
    } else {
      _log('⚠️ No broker configured. Set API keys in Settings → Vault.');
    }
  }

  void _handleBalance() {
    _log('Mode: ${_isRealMode ? "🔴 REAL" : "🟢 PAPER"}');
    _log('Paper Balance: \$${_paperBalance.toStringAsFixed(2)}');
    _log('Open Positions: ${_positions.length}');
  }

  void _handlePositions() {
    if (_positions.isEmpty) { _log('No open positions.'); return; }
    _log('--- Open Positions ---');
    for (final p in _positions) {
      _log('${p['side']} ${p['amount']} ${p['symbol']} @ \$${p['price']} (${p['time']})');
    }
  }

  void _handleHistory() {
    if (_tradeHistory.isEmpty) { _log('No trade history.'); return; }
    _log('--- Trade History (last 10) ---');
    for (final t in _tradeHistory.reversed.take(10)) {
      _log('${t['mode']} ${t['action']} ${t['amount']} ${t['symbol']} @ \$${t['price']} (${t['time']})');
    }
  }

  void _handleMode(List<String> parts) {
    if (parts.length < 2) {
      _log('Usage: mode paper | mode real');
      _log('Current mode: ${_isRealMode ? "REAL" : "PAPER"}');
      return;
    }
    final mode = parts[1].toLowerCase();
    if (mode == 'real') {
      if (_binanceApiKey.isEmpty && _mt5Login.isEmpty) {
        _log('⚠️ No broker API configured. Set credentials in Settings first.');
        return;
      }
      setState(() => _isRealMode = true);
      SharedPreferences.getInstance().then((p) => p.setBool('real_mode', true));
      _log('🔴 Switched to REAL trading mode.');
      _notifService.show('Mode Changed', 'Switched to REAL trading mode');
    } else {
      setState(() => _isRealMode = false);
      SharedPreferences.getInstance().then((p) => p.setBool('real_mode', false));
      _log('🟢 Switched to PAPER trading mode.');
    }
  }

  void _handleVault(List<String> parts) {
    if (parts.length < 2) {
      _log('Usage: vault binance set <api_key> <secret> | vault mt5 set <login> <password> <server> | vault ai set <api_key> [openai|claude|gemini] | vault show | vault clear');
      return;
    }
    final sub = parts[1].toLowerCase();
    if (sub == 'binance' && parts.length >= 5 && parts[2] == 'set') {
      _secureStorage.write(key: 'binance_api_key', value: parts[3]);
      _secureStorage.write(key: 'binance_secret', value: parts[4]);
      setState(() { _binanceApiKey = parts[3]; _binanceSecret = parts[4]; });
      _log('✅ Binance API credentials saved.');
    } else if (sub == 'mt5' && parts.length >= 6 && parts[2] == 'set') {
      _secureStorage.write(key: 'mt5_login', value: parts[3]);
      _secureStorage.write(key: 'mt5_password', value: parts[4]);
      _secureStorage.write(key: 'mt5_server', value: parts[5]);
      setState(() { _mt5Login = parts[3]; _mt5Password = parts[4]; _mt5Server = parts[5]; });
      _log('✅ MT5 credentials saved.');
    } else if (sub == 'ai' && parts.length >= 4 && parts[2] == 'set') {
      _secureStorage.write(key: 'ai_api_key', value: parts[3]);
      final provider = parts.length >= 5 ? parts[4].toLowerCase() : 'openai';
      _secureStorage.write(key: 'ai_provider', value: provider);
      setState(() { _aiApiKey = parts[3]; _aiProvider = provider; });
      _log('✅ AI API key saved. Provider: $provider');
    } else if (sub == 'show') {
      _log('Binance API: ${_binanceApiKey.isEmpty ? "(not set)" : "${_binanceApiKey.substring(0, 6)}..."}');
      _log('MT5 Login: ${_mt5Login.isEmpty ? "(not set)" : _mt5Login}');
      _log('MT5 Server: ${_mt5Server.isEmpty ? "(not set)" : _mt5Server}');
      _log('AI API Key: ${_aiApiKey.isEmpty ? "(not set)" : "****${_aiApiKey.substring(_aiApiKey.length - 4)}"}');
      _log('AI Provider: $_aiProvider');
    } else if (sub == 'clear') {
      _secureStorage.deleteAll();
      setState(() { _binanceApiKey = ''; _binanceSecret = ''; _mt5Login = ''; _mt5Password = ''; _mt5Server = ''; _aiApiKey = ''; _aiProvider = 'openai'; });
      _log('✅ All credentials cleared.');
    } else {
      _log('Unknown vault command.');
    }
  }

  void _handleSignal(List<String> parts) {
    if (parts.length < 3) {
      _log('Usage: signal <symbol> <BUY|SELL> [price]');
      return;
    }
    final symbol = parts[1].toUpperCase();
    final signal = parts[2].toUpperCase();
    final price = parts.length > 3 ? parts[3] : 'market';
    _log('📡 Signal sent: $signal $symbol @ $price');
    _notifService.show('Trading Signal', '$signal $symbol @ $price');
  }

  void _handleAI(List<String> parts) {
    if (parts.length < 2) {
      _log('Usage: ai <question> | ai analyze <symbol> | ai signal <symbol> | ai explain <topic>');
      _log('AI Provider: $_aiProvider');
      _log('AI API Key: ${_aiApiKey.isEmpty ? "(not set)" : "****${_aiApiKey.substring(_aiApiKey.length - 4)}"}');
      return;
    }
    final sub = parts[1].toLowerCase();
    if (sub == 'analyze' && parts.length >= 3) {
      final symbol = parts[2].toUpperCase();
      _aiAnalyzeMarket(symbol);
    } else if (sub == 'signal' && parts.length >= 3) {
      final symbol = parts[2].toUpperCase();
      _aiGenerateSignal(symbol);
    } else if (sub == 'explain' && parts.length >= 3) {
      final topic = parts.sublist(2).join(' ');
      _aiExplain(topic);
    } else {
      final question = parts.sublist(1).join(' ');
      _aiChat(question);
    }
  }

  Future<void> _aiChat(String question) async {
    if (_aiApiKey.isEmpty) {
      _log('⚠️ AI API key not set. Use: vault ai set <api_key> [provider]');
      _log('Supported providers: openai, claude, gemini');
      return;
    }
    _log('🤖 AI: Thinking...');
    setState(() => _aiLoading = true);
    try {
      final response = await _callAI(
        'You are an expert trading assistant. Answer concisely and helpfully. '
        'The user is a trader using a Flutter trading terminal app. '
        'Current mode: ${_isRealMode ? "REAL" : "PAPER"}. '
        'Paper balance: \$${_paperBalance.toStringAsFixed(2)}. '
        'Open positions: ${_positions.length}.',
        question,
      );
      _log('🤖 AI: $response');
      _aiChatHistory.add({'role': 'user', 'content': question});
      _aiChatHistory.add({'role': 'assistant', 'content': response});
      _notifService.show('AI Response', response.length > 100 ? '${response.substring(0, 100)}...' : response);
    } catch (e) {
      _log('❌ AI Error: $e');
    }
    setState(() => _aiLoading = false);
  }

  Future<void> _aiAnalyzeMarket(String symbol) async {
    if (_aiApiKey.isEmpty) { _log('⚠️ Set AI API key first.'); return; }
    _log('🤖 AI: Analyzing $symbol market...');
    setState(() => _aiLoading = true);
    try {
      final response = await _callAI(
        'You are a professional market analyst. Provide a concise technical analysis. '
        'Include: trend direction, support/resistance levels, key indicators, and risk assessment. '
        'Format with bullet points. Keep it under 200 words.',
        'Analyze the current market conditions for $symbol. Consider price action, volume, and momentum. '
        'Current paper balance: \$${_paperBalance.toStringAsFixed(2)}. Mode: ${_isRealMode ? "REAL" : "PAPER"}.',
      );
      _log('📊 AI Market Analysis [$symbol]:');
      _log(response);
    } catch (e) {
      _log('❌ AI Error: $e');
    }
    setState(() => _aiLoading = false);
  }

  Future<void> _aiGenerateSignal(String symbol) async {
    if (_aiApiKey.isEmpty) { _log('⚠️ Set AI API key first.'); return; }
    _log('🤖 AI: Generating trading signal for $symbol...');
    setState(() => _aiLoading = true);
    try {
      final response = await _callAI(
        'You are a trading signal generator. Output a clear, actionable signal. '
        'Format: SIGNAL: BUY/SELL/HOLD, ENTRY: price, SL: price, TP: price, CONFIDENCE: X%, REASON: brief explanation. '
        'Keep it concise.',
        'Generate a trading signal for $symbol. Consider current market conditions, support/resistance, and momentum. '
        'Risk level: moderate. Account balance: \$${_paperBalance.toStringAsFixed(2)}.',
      );
      _log('📡 AI Signal [$symbol]:');
      _log(response);
      _notifService.show('AI Trading Signal', response.length > 100 ? '${response.substring(0, 100)}...' : response);
    } catch (e) {
      _log('❌ AI Error: $e');
    }
    setState(() => _aiLoading = false);
  }

  Future<void> _aiExplain(String topic) async {
    if (_aiApiKey.isEmpty) { _log('⚠️ Set AI API key first.'); return; }
    _log('🤖 AI: Explaining "$topic"...');
    setState(() => _aiLoading = true);
    try {
      final response = await _callAI(
        'You are a trading educator. Explain concepts clearly and concisely for a beginner-to-intermediate trader. '
        'Use simple language and practical examples. Keep under 150 words.',
        'Explain: $topic',
      );
      _log('📚 AI Explanation:');
      _log(response);
    } catch (e) {
      _log('❌ AI Error: $e');
    }
    setState(() => _aiLoading = false);
  }

  Future<String> _callAI(String systemPrompt, String userMessage) async {
    if (_aiProvider == 'openai') {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_aiApiKey',
      }, body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'max_tokens': 500,
        'temperature': 0.7,
      }));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? 'No response';
      } else {
        throw Exception('OpenAI API error: ${response.statusCode} - ${response.body}');
      }
    } else if (_aiProvider == 'claude') {
      final url = Uri.parse('https://api.anthropic.com/v1/messages');
      final response = await http.post(url, headers: {
        'Content-Type': 'application/json',
        'x-api-key': _aiApiKey,
        'anthropic-version': '2023-06-01',
      }, body: jsonEncode({
        'model': 'claude-3-haiku-20240307',
        'max_tokens': 500,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userMessage},
        ],
      }));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'] ?? 'No response';
      } else {
        throw Exception('Claude API error: ${response.statusCode} - ${response.body}');
      }
    } else if (_aiProvider == 'gemini') {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_aiApiKey');
      final response = await http.post(url, headers: {
        'Content-Type': 'application/json',
      }, body: jsonEncode({
        'contents': [
          {'parts': [{'text': '$systemPrompt\n\n$userMessage'}]},
        ],
        'generationConfig': {'maxOutputTokens': 500, 'temperature': 0.7},
      }));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ?? 'No response';
      } else {
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    }
    throw Exception('Unknown AI provider: $_aiProvider');
  }

  void _handleHelp() {
    _log('--- Available Commands ---');
    _log('  buy <symbol> <amount>     - Buy (paper or real)');
    _log('  sell <symbol> <amount>    - Sell (paper or real)');
    _log('  balance                   - Show balance & mode');
    _log('  positions                 - Show open positions');
    _log('  history                   - Show trade history');
    _log('  mode paper|real           - Switch trading mode');
    _log('  vault binance set <key> <secret>');
    _log('  vault mt5 set <login> <pass> <server>');
    _log('  vault show|clear          - Manage credentials');
    _log('  signal <symbol> <BUY|SELL> [price] - Send trading signal');
    _log('  ai <question>             - Ask AI anything');
    _log('  ai analyze <symbol>       - AI market analysis');
    _log('  ai signal <symbol>        - AI trading signal');
    _log('  ai explain <topic>        - AI concept explanation');
    _log('  vault ai set <key> [provider] - Set AI API key');
    _log('  clear                     - Clear terminal');
    _log('  help                      - Show this help');
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
        title: Text('Terminal ${_isRealMode ? "🔴 REAL" : "🟢 PAPER"}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                itemCount: _terminalOutput.length,
                itemBuilder: (context, index) => Text(
                  _terminalOutput[index],
                  style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[900],
            child: Row(
              children: [
                const Text('\$ ', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                Expanded(
                  child: TextField(
                    controller: _cliController,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter command...'),
                    onSubmitted: _executeCommand,
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.cyanAccent), onPressed: () => _executeCommand(_cliController.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PORTFOLIO PAGE - Dashboard with Charts
// ═══════════════════════════════════════════════════════════════
class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  double _totalBalance = 10000.0;
  double _totalPnL = 0.0;
  final List<Map<String, dynamic>> _holdings = [];
  final List<FlSpot> _pnlHistory = [];

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalBalance = prefs.getDouble('paper_balance') ?? 10000.0;
    });
    // Sample PnL history
    for (int i = 0; i < 7; i++) {
      _pnlHistory.add(FlSpot(i.toDouble(), (i * 150.0 + (i % 3) * 50)));
    }
    // Sample holdings
    _holdings.addAll([
      {'symbol': 'BTC', 'amount': 0.05, 'avgPrice': 65000.0, 'currentPrice': 67500.0},
      {'symbol': 'ETH', 'amount': 0.5, 'avgPrice': 3200.0, 'currentPrice': 3450.0},
      {'symbol': 'SOL', 'amount': 10.0, 'avgPrice': 145.0, 'currentPrice': 165.0},
    ]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = _holdings.fold<double>(0, (sum, h) => sum + (h['amount'] * h['currentPrice']));
    final totalCost = _holdings.fold<double>(0, (sum, h) => sum + (h['amount'] * h['avgPrice']));
    final pnl = totalValue - totalCost;
    final pnlPercent = totalCost > 0 ? (pnl / totalCost * 100) : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            Row(
              children: [
                _kpiCard('Total Value', '\$${totalValue.toStringAsFixed(2)}', Colors.cyanAccent),
                const SizedBox(width: 8),
                _kpiCard('Total P&L', '\$${pnl.toStringAsFixed(2)} (${pnlPercent.toStringAsFixed(1)}%)', pnl >= 0 ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 8),
                _kpiCard('Cash Balance', '\$${_totalBalance.toStringAsFixed(2)}', Colors.amberAccent),
              ],
            ),
            const SizedBox(height: 16),
            // PnL Chart
            const Text('P&L History (7 days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('D${v.toInt() + 1}', style: const TextStyle(fontSize: 10)))),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('\$${v.toInt()}', style: const TextStyle(fontSize: 10)))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _pnlHistory,
                      isCurved: true,
                      color: Colors.cyanAccent,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Colors.cyanAccent.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Holdings Table
            const Text('Holdings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._holdings.map((h) {
              final value = h['amount'] * h['currentPrice'];
              final cost = h['amount'] * h['avgPrice'];
              final pnl = value - cost;
              final pnlPct = cost > 0 ? (pnl / cost * 100) : 0;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(h['symbol'][0])),
                  title: Text('${h['symbol']} (${h['amount']})'),
                  subtitle: Text('Avg: \$${h['avgPrice']} → Now: \$${h['currentPrice']}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${pnl >= 0 ? "+" : ""}\$${pnl.toStringAsFixed(2)} (${pnlPct.toStringAsFixed(1)}%)', style: TextStyle(color: pnl >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SETTINGS PAGE - API Vault & Notifications
// ═══════════════════════════════════════════════════════════════
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final TextEditingController _binanceKeyCtrl = TextEditingController();
  final TextEditingController _binanceSecretCtrl = TextEditingController();
  final TextEditingController _mt5LoginCtrl = TextEditingController();
  final TextEditingController _mt5PassCtrl = TextEditingController();
  final TextEditingController _mt5ServerCtrl = TextEditingController();
  final TextEditingController _aiKeyCtrl = TextEditingController();
  String _aiProvider = 'openai';
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _binanceKeyCtrl.text = await _secureStorage.read(key: 'binance_api_key') ?? '';
    _binanceSecretCtrl.text = await _secureStorage.read(key: 'binance_secret') ?? '';
    _mt5LoginCtrl.text = await _secureStorage.read(key: 'mt5_login') ?? '';
    _mt5PassCtrl.text = await _secureStorage.read(key: 'mt5_password') ?? '';
    _mt5ServerCtrl.text = await _secureStorage.read(key: 'mt5_server') ?? '';
    _aiKeyCtrl.text = await _secureStorage.read(key: 'ai_api_key') ?? '';
    _aiProvider = await _secureStorage.read(key: 'ai_provider') ?? 'openai';
    final prefs = await SharedPreferences.getInstance();
    setState(() => _notificationsEnabled = prefs.getBool('notifications') ?? true);
  }

  Future<void> _saveSettings() async {
    await _secureStorage.write(key: 'binance_api_key', value: _binanceKeyCtrl.text);
    await _secureStorage.write(key: 'binance_secret', value: _binanceSecretCtrl.text);
    await _secureStorage.write(key: 'mt5_login', value: _mt5LoginCtrl.text);
    await _secureStorage.write(key: 'mt5_password', value: _mt5PassCtrl.text);
    await _secureStorage.write(key: 'mt5_server', value: _mt5ServerCtrl.text);
    await _secureStorage.write(key: 'ai_api_key', value: _aiKeyCtrl.text);
    await _secureStorage.write(key: 'ai_provider', value: _aiProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', _notificationsEnabled);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & API Vault')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔔 Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('Trading Signal Notifications'),
              value: _notificationsEnabled,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
            ),
            const Divider(),
            const Text('🟡 Binance API', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: _binanceKeyCtrl, decoration: const InputDecoration(labelText: 'API Key')),
            TextField(controller: _binanceSecretCtrl, decoration: const InputDecoration(labelText: 'API Secret'), obscureText: true),
            const SizedBox(height: 16),
            const Text('🔵 MetaTrader 5', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: _mt5LoginCtrl, decoration: const InputDecoration(labelText: 'Login')),
            TextField(controller: _mt5PassCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            TextField(controller: _mt5ServerCtrl, decoration: const InputDecoration(labelText: 'Server')),
            const SizedBox(height: 16),
            const Text('🤖 AI Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: _aiKeyCtrl, decoration: const InputDecoration(labelText: 'AI API Key'), obscureText: true),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _aiProvider,
              decoration: const InputDecoration(labelText: 'AI Provider', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'openai', child: Text('OpenAI (GPT-4o-mini)')),
                DropdownMenuItem(value: 'claude', child: Text('Anthropic (Claude Haiku)')),
                DropdownMenuItem(value: 'gemini', child: Text('Google (Gemini Flash)')),
              ],
              onChanged: (v) => setState(() => _aiProvider = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NOTIFICATION SERVICE
// ═══════════════════════════════════════════════════════════════
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
  }

  Future<void> show(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'trading_signals',
      'Trading Signals',
      channelDescription: 'Notifications for trading signals and order executions',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }
}