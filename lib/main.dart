import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necessário para travar orientação e limite
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  // PASSO 1: Travar a orientação vertical
  WidgetsFlutterBinding.ensureInitialized();
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
      title: 'Gerador QR Pro 2.0',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
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
  
  String _dadosParaQR = "";
  List<String> _historico = [];

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  void _carregarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historico = prefs.getStringList('historico_qr') ?? [];
    });
  }

  void _salvarNoHistorico() async {
    if (_dadosParaQR.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (!_historico.contains(_dadosParaQR)) {
        _historico.insert(0, _dadosParaQR);
        if (_historico.length > 10) _historico.removeLast();
      }
    });
    await prefs.setStringList('historico_qr', _historico);
  }

  // Função para os Atalhos Rápidos (A5-EXP, etc)
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
      String c1 = _cont1.text;
      String c2 = _cont2.text;
      String c3 = _cont3.text;
      if (c1.isEmpty && c2.isEmpty) {
        _dadosParaQR = "";
      } else {
        _dadosParaQR = "A$c1-$c2${c3.isNotEmpty ? '-$c3' : ''}";
      }
    });
  }

  Future<void> _compartilharImagem() async {
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/qrcode_gerado.png').create();
        await imagePath.writeAsBytes(image);
        await Share.shareXFiles([XFile(imagePath.path)], text: 'Código: $_dadosParaQR');
      }
    } catch (e) {
      debugPrint("Erro ao compartilhar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerador QR 2.0"), centerTitle: true),
      body: Column(
        children: [
          // ÁREA DOS CAMPOS (PASSO 2: Limite de 2 números)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("A", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _campoNumerico(_cont1),
                const Text(" - ", style: TextStyle(fontSize: 20)),
                _campoNumerico(_cont2),
                const Text(" - ", style: TextStyle(fontSize: 20)),
                _campoNumerico(_cont3),
              ],
            ),
          ),
          
          Expanded(
            child: Center(
              child: _dadosParaQR.isEmpty 
                ? const Text("Digite ou use um atalho") 
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Screenshot(
                        controller: _screenshotController,
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(15),
                          child: QrImageView(data: _dadosParaQR, size: 250),
                        ),
                      ),
                      Text(_dadosParaQR, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _botaoAcao(Icons.save, "Salvar", _salvarNoHistorico),
                          const SizedBox(width: 20),
                          _botaoAcao(Icons.share, "Enviar", _compartilharImagem),
                        ],
                      )
                    ],
                  ),
            ),
          ),

          // PASSO 3: BARRA DE ATALHOS FIXOS
          const Divider(),
          const Text("ATALHOS RÁPIDOS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _botaoAtalho("A5-EXP"),
                _botaoAtalho("A6-EXP"),
                _botaoAtalho("A7-EXP"),
                _botaoAtalho("A8-EXP"),
              ],
            ),
          ),

          // HISTÓRICO
          const Divider(),
          const Text("HISTÓRICO", style: TextStyle(fontSize: 10, color: Colors.grey)),
          Container(
            height: 70,
            padding: const EdgeInsets.only(bottom: 5),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _historico.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () {
                   setState(() {
                     _dadosParaQR = _historico[index];
                   });
                },
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(child: Text(_historico[index])),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para os botões de atalho
  Widget _botaoAtalho(String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () => _gerarAtalho(label),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black)),
    );
  }

  Widget _campoNumerico(TextEditingController controller) {
    return SizedBox(
      width: 65,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        // PASSO 2: Limitar a apenas 2 dígitos
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2), 
        ], 
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        onChanged: (_) => _atualizarCodigo(),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          counterText: "",
        ),
      ),
    );
  }

  Widget _botaoAcao(IconData icone, String rotulo, VoidCallback acao) {
    return ElevatedButton.icon(
      onPressed: acao,
      icon: Icon(icone),
      label: Text(rotulo),
    );
  }
}