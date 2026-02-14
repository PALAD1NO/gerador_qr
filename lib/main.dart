import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';

void main() {
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
      title: 'Gerador QR Pro 3.1',
      theme: ThemeData(
        primarySwatch: Colors.indigo, 
        useMaterial3: true,
        // Garante que o texto use uma escala previsível
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
      appBar: AppBar(title: const Text("Gerador QR 3.1"), centerTitle: true),
      body: Column(
        children: [
          // ÁREA DE INPUT
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("A", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
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
                ? const Text("Digite ou use um atalho", style: TextStyle(fontSize: 16)) 
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
                      const SizedBox(height: 10),
                      Text(_dadosParaQR, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo)),
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

          // BARRA DE ATALHOS (Ajustada)
          const Divider(),
          const Text("ATALHOS RÁPIDOS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
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

          // HISTÓRICO EM GRADE (Ajustada para 2 linhas amplas)
          const Divider(),
          const Text("HISTÓRICO RECENTE", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          SizedBox(
            height: 150, // Altura ampliada para conforto visual
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              physics: const NeverScrollableScrollPhysics(), // Mantém fixo já que são só 10
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, 
                mainAxisSpacing: 12, 
                crossAxisSpacing: 8, 
                childAspectRatio: 1.3, // Botões mais altos para facilitar o toque
              ),
              itemCount: _historico.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () {
                   setState(() {
                     _dadosParaQR = _historico[index];
                   });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _historico[index], 
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13, // Fonte aumentada
                        fontWeight: FontWeight.bold,
                        color: Colors.black87
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _botaoAtalho(String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.blue.shade900,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15), // Mais área de toque
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => _gerarAtalho(label),
      child: Text(
        label, 
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold) // Fonte aumentada
      ),
    );
  }

  Widget _campoNumerico(TextEditingController controller) {
    return SizedBox(
      width: 70, // Levemente mais largo
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2), 
        ], 
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Fonte do campo aumentada
        onChanged: (_) => _atualizarCodigo(),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          counterText: "",
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