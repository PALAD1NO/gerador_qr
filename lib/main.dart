import 'dart:io'; // Necessário para manipular arquivos
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart'; // Para capturar a imagem
import 'package:path_provider/path_provider.dart'; // Para salvar o arquivo temporário

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gerador QR Pro',
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
  
  // Controlador para capturar a imagem do QR Code
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Salvo no histórico!")));
  }

  void _recuperarDoHistorico(String codigo) {
    String puro = codigo.replaceFirst('A', '');
    List<String> partes = puro.split('-');
    setState(() {
      _cont1.text = partes.isNotEmpty ? partes[0] : "";
      _cont2.text = partes.length > 1 ? partes[1] : "";
      _cont3.text = partes.length > 2 ? partes[2] : "";
      _atualizarCodigo();
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

  // FUNÇÃO PARA COMPARTILHAR A IMAGEM
  Future<void> _compartilharImagem() async {
    try {
      // 1. Captura a imagem do widget
      final Uint8List? image = await _screenshotController.capture();

      if (image != null) {
        // 2. Obtém diretório temporário do celular
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/qrcode_gerado.png').create();
        
        // 3. Grava os bytes da imagem no arquivo
        await imagePath.writeAsBytes(image);

        // 4. Compartilha o arquivo
        await Share.shareXFiles(
          [XFile(imagePath.path)],
          text: 'Código: $_dadosParaQR',
        );
      }
    } catch (e) {
      debugPrint("Erro ao compartilhar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerador QR"), centerTitle: true),
      body: Column(
        children: [
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
                ? const Text("Digite os números acima") 
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // O Screenshot envolve apenas o que queremos "fotografar"
                      Screenshot(
                        controller: _screenshotController,
                        child: Container(
                          color: Colors.white, // Fundo branco para o QR sair nítido
                          padding: const EdgeInsets.all(15),
                          child: QrImageView(data: _dadosParaQR, size: 250),
                        ),
                      ),
                      Text(_dadosParaQR, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      const SizedBox(height: 20),
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

          const Divider(),
          const Text("HISTÓRICO (Toque para carregar)", style: TextStyle(fontSize: 10, color: Colors.grey)),
          Container(
            height: 80,
            padding: const EdgeInsets.only(bottom: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _historico.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _recuperarDoHistorico(_historico[index]),
                child: Card(
                  color: Colors.grey[100],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    child: Center(child: Text(_historico[index], style: const TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoNumerico(TextEditingController controller) {
    return SizedBox(
      width: 70,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number, 
        inputFormatters: [FilteringTextInputFormatter.digitsOnly], 
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
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
    );
  }
}