import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _primaryBlue = Color(0xFF0C63E7);
const _primaryBlueDark = Color(0xFF0847A6);
const _secondaryInk = Color(0xFF1F2937);
const _surface = Color(0xFFF4F7FC);
const _surfaceBlue = Color(0xFFEAF2FF);
const _card = Color(0xFFFFFFFF);
const _line = Color(0xFFD7E1F0);
const _muted = Color(0xFF6B7280);

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
    final base = ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: _surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryBlue,
        primary: _primaryBlue,
        secondary: _secondaryInk,
        surface: _card,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gerador QR',
      theme: base.copyWith(
        textTheme: base.textTheme.apply(
          bodyColor: _secondaryInk,
          displayColor: _secondaryInk,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _secondaryInk,
          elevation: 0,
          centerTitle: false,
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
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(86),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: _topHeader(),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FAFF), Color(0xFFF1F5FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: IndexedStack(
            index: _paginaAtual,
            children: [_telaGerador(), _telaHistorico()],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: _barraNavegacao(),
      ),
    );
  }

  Widget _topHeader() {
    final icon = _paginaAtual == 0 ? Icons.qr_code_2_rounded : Icons.history;
    final subtitle = _paginaAtual == 0
        ? 'Monte, salve e compartilhe seus codigos'
        : 'Historico recente dos codigos gerados';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final iconBoxSize = compact ? 48.0 : 58.0;
        final iconSize = compact ? 24.0 : 30.0;

        return Row(
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: _surfaceBlue,
                borderRadius: BorderRadius.circular(compact ? 16 : 18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140C63E7),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: _primaryBlue, size: iconSize),
            ),
            SizedBox(width: compact ? 12 : 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Gerador QR',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w800,
                      color: _secondaryInk,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: _muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _barraNavegacao() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _navItem(
              icon: Icons.qr_code_2_rounded,
              label: 'Gerar',
              selected: _paginaAtual == 0,
              onTap: () => setState(() => _paginaAtual = 0),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _navItem(
              icon: Icons.history_rounded,
              label: 'Historico',
              selected: _paginaAtual == 1,
              onTap: () => setState(() => _paginaAtual = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _surfaceBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? _primaryBlue : _muted, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? _primaryBlue : _muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _telaGerador() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 390;
        final horizontalPadding = width >= 720 ? 28.0 : 16.0;
        final cardMaxWidth = width >= 920 ? 760.0 : double.infinity;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            126,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardMaxWidth),
              child: Column(
                children: [
                  _heroGerador(compact: compact),
                  const SizedBox(height: 18),
                  _atalhosSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heroGerador({required bool compact}) {
    final qrSize = compact ? 190.0 : 240.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 18,
        compact ? 16 : 20,
        compact ? 14 : 18,
        compact ? 18 : 22,
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _codigoInputPanel(compact: compact),
          const SizedBox(height: 18),
          _dadosParaQR.isEmpty
              ? _estadoVazioGerador(compact: compact)
              : _previewGerador(qrSize: qrSize, compact: compact),
        ],
      ),
    );
  }

  Widget _codigoInputPanel({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Codigo de identificacao',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final isTight = availableWidth < 330;
              final separatorWidth = isTight ? 14.0 : 18.0;
              final gapWidth = isTight ? 6.0 : 10.0;
              final totalSpacing = (gapWidth * 1) + (separatorWidth * 2);
              final itemWidth = ((availableWidth - totalSpacing) / 4).clamp(
                52.0,
                compact ? 62.0 : 70.0,
              );

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _blocoPrefixoA(size: itemWidth),
                  SizedBox(width: gapWidth),
                  _campoNumerico(_cont1, size: itemWidth),
                  _separadorCodigo(width: separatorWidth, tight: isTight),
                  _campoNumerico(_cont2, size: itemWidth),
                  _separadorCodigo(width: separatorWidth, tight: isTight),
                  _campoNumerico(_cont3, size: itemWidth),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _blocoPrefixoA({required double size}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryBlue, _primaryBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFFB6C4D7)),
        ),
      ),
      child: Text(
        'A',
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _estadoVazioGerador({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 24,
        vertical: compact ? 30 : 40,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9FBFF), Color(0xFFF1F6FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Container(
            width: compact ? 84 : 96,
            height: compact ? 84 : 96,
            decoration: BoxDecoration(
              color: _surfaceBlue,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              size: 46,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Digite ou use um atalho',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _secondaryInk,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'O codigo sera montado automaticamente e o QR aparecera aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _previewGerador({required double qrSize, required bool compact}) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 16 : 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFDFEFF), Color(0xFFF5F9FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: _line),
          ),
          child: Column(
            children: [
              Screenshot(
                controller: _screenshotController,
                child: _quadroQr(qrSize),
              ),
              const SizedBox(height: 22),
              Text(
                _dadosParaQR,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 30 : 38,
                  fontWeight: FontWeight.w900,
                  color: _primaryBlue,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'CODIGO DE IDENTIFICACAO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _acoesGerador(compact: compact),
      ],
    );
  }

  Widget _quadroQr(double qrSize) {
    final moldura = qrSize + 74;

    return Container(
      width: moldura,
      height: moldura,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140052FF),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFCFE0FF), width: 2),
                ),
              ),
            ),
          ),
          Container(
            width: qrSize + 16,
            height: qrSize + 16,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2B2B),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(6, 6),
                ),
              ],
            ),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(data: _dadosParaQR, size: qrSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _acoesGerador({required bool compact}) {
    final salvar = _botaoAcao(
      Icons.save_outlined,
      'Salvar',
      _salvarNoHistorico,
    );
    final enviar = _botaoAcao(
      Icons.share_outlined,
      'Enviar',
      _compartilharImagem,
      isPrimary: false,
    );

    if (compact) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: salvar),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: enviar),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: salvar),
        const SizedBox(width: 14),
        Expanded(child: enviar),
      ],
    );
  }

  Widget _atalhosSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FC),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE3EBF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ATALHOS RAPIDOS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _muted,
                letterSpacing: 0.9,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(width: double.infinity),
          Wrap(
            spacing: 10,
            runSpacing: 10,
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
    );
  }

  Widget _telaHistorico() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding = width >= 720 ? 28.0 : 16.0;
        final maxWidth = width >= 1080 ? 980.0 : double.infinity;

        if (_historico.isEmpty) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              126,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _historicoVazio(),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            126,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _gridHistorico(width),
            ),
          ),
        );
      },
    );
  }

  Widget _historicoVazio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: _surfaceBlue,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.history, size: 46, color: _primaryBlue),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum codigo salvo ainda',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _secondaryInk,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gere um QR, toque em salvar e ele aparecera aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _gridHistorico(double width) {
    final crossAxisCount = width >= 900
        ? 4
        : width >= 620
        ? 3
        : 2;
    final childAspectRatio = width >= 900
        ? 0.9
        : width >= 620
        ? 0.84
        : width < 390
        ? 0.70
        : 0.76;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
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
            final card = _cardHistorico(codigo, index, highlighted: isHovering);

            if (kIsWeb) {
              return Draggable<int>(
                data: index,
                maxSimultaneousDrags: 1,
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: width >= 620 ? 200 : 160,
                    child: _cardHistorico(
                      codigo,
                      index,
                      compact: true,
                      highlighted: true,
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: card),
                child: card,
              );
            }

            return LongPressDraggable<int>(
              data: index,
              maxSimultaneousDrags: 1,
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: width >= 620 ? 200 : 160,
                  child: _cardHistorico(
                    codigo,
                    index,
                    compact: true,
                    highlighted: true,
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.35, child: card),
              child: card,
            );
          },
        );
      },
    );
  }

  Widget _botaoAtalho(String label) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _secondaryInk,
        side: const BorderSide(color: Color(0xFFC8D4E7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      onPressed: () => _gerarAtalho(label),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _campoNumerico(
    TextEditingController controller, {
    required double size,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: _secondaryInk,
        ),
        onChanged: (_) => _atualizarCodigo(),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFB6C4D7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFB6C4D7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: _primaryBlue, width: 2),
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
    return SizedBox(
      height: 58,
      child: ElevatedButton.icon(
        onPressed: acao,
        icon: Icon(icone),
        label: Text(
          rotulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? _primaryBlue : Colors.white,
          foregroundColor: isPrimary ? Colors.white : _secondaryInk,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: isPrimary
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFB7C6DA)),
          ),
        ),
      ),
    );
  }

  Widget _separadorCodigo({required double width, required bool tight}) {
    return SizedBox(
      width: width,
      child: Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: tight ? 22 : 28,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFB3BDC9),
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
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: highlighted ? _primaryBlue : const Color(0xFFE5ECF5),
            width: highlighted ? 2 : 1.5,
          ),
          boxShadow: [
            const BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
            if (highlighted)
              const BoxShadow(
                color: Color(0x220C63E7),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.drag_indicator_rounded,
                  color: Color(0xFFB0BAC7),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _removerDoHistorico(index),
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded, size: 26, color: _muted),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Container(
                width: compact ? 72 : 86,
                height: compact ? 72 : 86,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: _primaryBlue,
                  size: 38,
                ),
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
            Center(
              child: Text(
                codigo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: _secondaryInk,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Toque para abrir',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: _muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
