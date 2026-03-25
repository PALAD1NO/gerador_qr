import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _primaryBlue = Color(0xFF0052FF);
const _secondaryInk = Color(0xFF1E293B);
const _surface = Color(0xFFF3F6FB);
const _card = Color(0xFFFFFFFF);
const _line = Color(0xFFD8E0EC);
const _muted = Color(0xFF667085);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    runApp(const MyApp());
    return;
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((
    _,
  ) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gerador QR',
      theme: ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: _surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryBlue,
          primary: _primaryBlue,
          secondary: _secondaryInk,
          surface: _card,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _surface,
          foregroundColor: _secondaryInk,
          elevation: 0,
          centerTitle: true,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _card,
          indicatorColor: _primaryBlue,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const PaginaGeradorQR(),
    );
  }
}

class PaginaGeradorQR extends StatefulWidget {
  const PaginaGeradorQR({super.key});

  @override
  State<PaginaGeradorQR> createState() => _PaginaGeradorQRState();
}

class _PaginaGeradorQRState extends State<PaginaGeradorQR> {
  final TextEditingController _cont1 = TextEditingController();
  final TextEditingController _cont2 = TextEditingController();
  final TextEditingController _cont3 = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();

  String _dadosParaQR = '';
  List<String> _historico = [];
  int _paginaAtual = 0;

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  @override
  void dispose() {
    _cont1.dispose();
    _cont2.dispose();
    _cont3.dispose();
    super.dispose();
  }

  Future<void> _carregarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _historico = prefs.getStringList('historico_qr') ?? [];
    });
  }

  Future<void> _persistirHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('historico_qr', _historico);
  }

  Future<void> _salvarNoHistorico() async {
    if (_dadosParaQR.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (!_historico.contains(_dadosParaQR)) {
        _historico.insert(0, _dadosParaQR);
        if (_historico.length > 12) {
          _historico.removeLast();
        }
      }
    });
    await prefs.setStringList('historico_qr', _historico);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Salvo no historico!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _gerarAtalho(String codigo) {
    setState(() {
      _cont1.clear();
      _cont2.clear();
      _cont3.clear();
      _dadosParaQR = codigo;
    });
  }

  void _atualizarCodigo() {
    setState(() {
      final c1 = _cont1.text;
      final c2 = _cont2.text;
      final c3 = _cont3.text;

      if (c1.isEmpty && c2.isEmpty) {
        _dadosParaQR = '';
      } else {
        _dadosParaQR = 'A$c1-$c2${c3.isNotEmpty ? '-$c3' : ''}';
      }
    });
  }

  Future<void> _compartilharImagem() async {
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image == null) return;

      if (kIsWeb) {
        await Share.shareXFiles([
          XFile.fromData(
            image,
            mimeType: 'image/png',
            name: 'qrcode_gerado.png',
          ),
        ], text: 'Codigo: $_dadosParaQR');
        return;
      }

      final directory = await getTemporaryDirectory();
      final imagePath = await File(
        '${directory.path}/qrcode_gerado.png',
      ).create();
      await imagePath.writeAsBytes(image);
      await Share.shareXFiles([
        XFile(imagePath.path),
      ], text: 'Codigo: $_dadosParaQR');
    } catch (e) {
      debugPrint('Erro ao compartilhar: $e');
    }
  }

  void _abrirCodigoDoHistorico(String codigo) {
    setState(() {
      _dadosParaQR = codigo;
      _paginaAtual = 0;
    });
  }

  Future<void> _removerDoHistorico(int index) async {
    final codigo = _historico[index];
    setState(() {
      _historico.removeAt(index);
    });
    await _persistirHistorico();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$codigo removido do historico.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _moverItemHistorico(int fromIndex, int toIndex) async {
    if (fromIndex == toIndex) return;

    setState(() {
      final item = _historico.removeAt(fromIndex);
      _historico.insert(toIndex, item);
    });

    await _persistirHistorico();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_paginaAtual == 0 ? 'Gerador QR' : '')),
      body: SafeArea(
        child: IndexedStack(
          index: _paginaAtual,
          children: [_telaGerador(), _telaHistorico()],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: _paginaAtual,
            onDestinationSelected: (index) {
              setState(() {
                _paginaAtual = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.qr_code_2_outlined),
                selectedIcon: Icon(Icons.qr_code_2, color: Colors.white),
                label: 'Gerar',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history, color: Colors.white),
                label: 'Historico',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _telaGerador() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _line),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _line),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _primaryBlue,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  'A',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _campoNumerico(_cont1),
                              _separadorCodigo(),
                              _campoNumerico(_cont2),
                              _separadorCodigo(),
                              _campoNumerico(_cont3),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 350),
                          child: Center(
                            child: _dadosParaQR.isEmpty
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          color: _surface,
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          border: Border.all(color: _line),
                                        ),
                                        child: const Icon(
                                          Icons.qr_code_2_rounded,
                                          size: 48,
                                          color: _primaryBlue,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      const Text(
                                        'Digite ou use um atalho',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: _secondaryInk,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'O codigo sera montado automaticamente.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _muted,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Screenshot(
                                        controller: _screenshotController,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                            border: Border.all(color: _line),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x100052FF),
                                                blurRadius: 20,
                                                offset: Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.all(18),
                                          child: QrImageView(
                                            data: _dadosParaQR,
                                            size: 250,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _dadosParaQR,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: _primaryBlue,
                                          letterSpacing: -0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _botaoAcao(
                                            Icons.save_outlined,
                                            'Salvar',
                                            _salvarNoHistorico,
                                          ),
                                          const SizedBox(width: 16),
                                          _botaoAcao(
                                            Icons.share_outlined,
                                            'Enviar',
                                            _compartilharImagem,
                                            isPrimary: false,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'ATALHOS RAPIDOS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _botaoAtalho('A5-EXP'),
                              _botaoAtalho('A6-EXP'),
                              _botaoAtalho('A7-EXP'),
                              _botaoAtalho('A8-EXP'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _telaHistorico() {
    if (_historico.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.history,
                    size: 46,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nenhum codigo salvo ainda',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _secondaryInk,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gere um QR, toque em salvar e ele aparecera aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.history, color: _primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Historico recente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _secondaryInk,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Toque em um item para abrir no gerador.',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.35,
                ),
                itemCount: _historico.length,
                itemBuilder: (context, index) {
                  final codigo = _historico[index];
                  return DragTarget<int>(
                    onWillAcceptWithDetails: (details) => details.data != index,
                    onAcceptWithDetails: (details) {
                      _moverItemHistorico(details.data, index);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovering = candidateData.isNotEmpty;
                      final card = _cardHistorico(
                        codigo,
                        index,
                        highlighted: isHovering,
                      );

                      if (kIsWeb) {
                        return Draggable<int>(
                          data: index,
                          maxSimultaneousDrags: 1,
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: 140,
                              child: _cardHistorico(
                                codigo,
                                index,
                                compact: true,
                                highlighted: true,
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.35,
                            child: _cardHistorico(
                              codigo,
                              index,
                              highlighted: true,
                            ),
                          ),
                          child: card,
                        );
                      }

                      return LongPressDraggable<int>(
                        data: index,
                        maxSimultaneousDrags: 1,
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 140,
                            child: _cardHistorico(
                              codigo,
                              index,
                              compact: true,
                              highlighted: true,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _cardHistorico(
                            codigo,
                            index,
                            highlighted: true,
                          ),
                        ),
                        child: card,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botaoAtalho(String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE8F0FF),
        foregroundColor: _primaryBlue,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFC9D7F2)),
        ),
      ),
      onPressed: () => _gerarAtalho(label),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _campoNumerico(TextEditingController controller) {
    return SizedBox(
      width: 65,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _secondaryInk,
        ),
        onChanged: (_) => _atualizarCodigo(),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryBlue, width: 1.6),
          ),
          counterText: '',
        ),
      ),
    );
  }

  Widget _botaoAcao(
    IconData icone,
    String rotulo,
    VoidCallback acao, {
    bool isPrimary = true,
  }) {
    return ElevatedButton.icon(
      onPressed: acao,
      icon: Icon(icone),
      label: Text(rotulo, style: const TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? _primaryBlue : Colors.white,
        foregroundColor: isPrimary ? Colors.white : _secondaryInk,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isPrimary ? BorderSide.none : const BorderSide(color: _line),
        ),
      ),
    );
  }

  Widget _separadorCodigo() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '-',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _muted,
        ),
      ),
    );
  }

  Widget _cardHistorico(
    String codigo,
    int index, {
    bool highlighted = false,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: () => _abrirCodigoDoHistorico(codigo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF4F7FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted ? _primaryBlue : _line,
            width: highlighted ? 2 : 1.5,
          ),
          boxShadow: [
            const BoxShadow(
              color: Color(0x0E0F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
            if (highlighted)
              const BoxShadow(
                color: Color(0x220052FF),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
          ],
        ),
        padding: EdgeInsets.all(compact ? 10 : 12),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        size: 18,
                        color: _primaryBlue,
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _line),
                      ),
                      child: const Icon(
                        Icons.drag_indicator_rounded,
                        size: 18,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  codigo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w800,
                    color: _secondaryInk,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: () => _removerDoHistorico(index),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE4E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Color(0xFFBE123C),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
