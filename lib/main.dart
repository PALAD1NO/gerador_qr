import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    runApp(const MyApp());
    return;
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
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
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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

  Future<void> _carregarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _historico = prefs.getStringList('historico_qr') ?? [];
    });
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
        await Share.shareXFiles(
          [
            XFile.fromData(
              image,
              mimeType: 'image/png',
              name: 'qrcode_gerado.png',
            ),
          ],
          text: 'Codigo: $_dadosParaQR',
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final imagePath =
          await File('${directory.path}/qrcode_gerado.png').create();
      await imagePath.writeAsBytes(image);
      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Codigo: $_dadosParaQR',
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_paginaAtual == 0 ? 'Gerador QR' : 'Historico recente'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _paginaAtual,
          children: [
            _telaGerador(),
            _telaHistorico(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _paginaAtual,
        onDestinationSelected: (index) {
          setState(() {
            _paginaAtual = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            selectedIcon: Icon(Icons.qr_code_2),
            label: 'Gerar',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historico',
          ),
        ],
      ),
    );
  }

  Widget _telaGerador() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'A',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _campoNumerico(_cont1),
                        const Text(' - ', style: TextStyle(fontSize: 20)),
                        _campoNumerico(_cont2),
                        const Text(' - ', style: TextStyle(fontSize: 20)),
                        _campoNumerico(_cont3),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 350),
                    child: Center(
                      child: _dadosParaQR.isEmpty
                          ? const Text(
                              'Digite ou use um atalho',
                              style: TextStyle(fontSize: 16),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Screenshot(
                                  controller: _screenshotController,
                                  child: Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(15),
                                    child: QrImageView(
                                      data: _dadosParaQR,
                                      size: 250,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _dadosParaQR,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _botaoAcao(
                                      Icons.save,
                                      'Salvar',
                                      _salvarNoHistorico,
                                    ),
                                    const SizedBox(width: 20),
                                    _botaoAcao(
                                      Icons.share,
                                      'Enviar',
                                      _compartilharImagem,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                  const Spacer(),
                  const Divider(),
                  const Text(
                    'ATALHOS RAPIDOS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    child: Wrap(
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
                  ),
                  const SizedBox(height: 16),
                ],
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Nenhum codigo salvo ainda',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gere um QR, toque em salvar e ele aparecera aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
        ),
        itemCount: _historico.length,
        itemBuilder: (context, index) {
          final codigo = _historico[index];
          return GestureDetector(
            onTap: () => _abrirCodigoDoHistorico(codigo),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  codigo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _botaoAtalho(String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.blue.shade900,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: () => _gerarAtalho(label),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        onChanged: (_) => _atualizarCodigo(),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          counterText: '',
        ),
      ),
    );
  }

  Widget _botaoAcao(IconData icone, String rotulo, VoidCallback acao) {
    return ElevatedButton.icon(
      onPressed: acao,
      icon: Icon(icone),
      label: Text(rotulo, style: const TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
