import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'login.dart';
import '../services/auth_service.dart';
import 'theme_manager.dart';

class Estoque extends StatefulWidget {
  final String empresa;
  const Estoque({super.key, required this.empresa});

  @override
  State<Estoque> createState() => _EstoqueState();
}

class _EstoqueState extends State<Estoque> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> produtos = [];
  bool loading = true;
  String nomeEmpresa = '';

  // Controllers
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController valorController = TextEditingController();
  final TextEditingController descricaoController = TextEditingController();
  final TextEditingController quantidadeController = TextEditingController();
  final TextEditingController loteController = TextEditingController();

  // Imagem
  Uint8List? imagemBytes; 
  String? imagemBase64;   
  String? imagemDeleteUrl; 

  String? editarProdutoLote;
  Map<String, dynamic>? produtoEditando;

  // Flag para indicar que o usuário apagou a imagem
  bool imagemApagada = false;

  final String imgbbKey = "42262867f069117f21effd58bd64371a";

  @override
  void initState() {
    super.initState();
    carregarProdutos();
    carregarNomeEmpresa();
  }

  Future<void> carregarNomeEmpresa() async {
    try {
      final response = await supabase
          .from('empresas')
          .select('name')
          .eq('cnpj', widget.empresa)
          .maybeSingle();
      
      if (response != null && response['name'] != null) {
        setState(() {
          nomeEmpresa = response['name'];
        });
      }
    } catch (e) {
      print('Erro ao carregar nome da empresa: $e');
    }
  }

  // Método para fazer logout
  Future<void> _logout() async {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeManager.dialogBgColor,
        title: Text(
          'Sair da conta',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeManager.primaryColor,
          ),
        ),
        content: Text(
          'Deseja realmente sair da sua conta?',
          style: TextStyle(fontSize: 16, color: themeManager.textPrimary),
        ),
        actions: [
          // Botão Cancelar
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeManager.primaryColor.withOpacity(0.1),
                  themeManager.primaryColor.withOpacity(0.2)
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: themeManager.primaryColor,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: themeManager.textPrimary,
                ),
              ),
            ),
          ),
          // Botão Sair
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeManager.primaryColor, themeManager.primaryColorDark],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: themeManager.primaryColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text(
                'Sair',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Usar o AuthService para fazer logout
      final authService = AuthService();
      await authService.logout();
      
      // Navegar para a tela de login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Login()),
        (route) => false,
      );
    }
  }

  Future<void> carregarProdutos() async {
    setState(() => loading = true);
    try {
      final response = await supabase
          .from('produtos')
          .select()
          .eq('empresa', widget.empresa)
          .order('created_at', ascending: false);

      setState(() {
        produtos = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      print('Erro ao carregar produtos: $e');
    }
  }

  Future<bool> verificarLoteExistente(String lote) async {
    try {
      final response = await supabase
          .from('produtos')
          .select('lote')
          .eq('lote', lote)
          .maybeSingle();

      // Se encontrar um registro, o lote já existe
      return response != null;
    } catch (e) {
      print("Erro ao verificar lote: $e");
      return false;
    }
  }

  Future<void> escolherImagem() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (resultado != null && resultado.files.first.bytes != null) {
      setState(() {
        imagemBytes = resultado.files.first.bytes!;
        imagemBase64 = base64Encode(imagemBytes!);
        imagemApagada = false;
      });
    }
  }

  Future<void> deletarImagemImgbb() async {
    if (imagemDeleteUrl != null) {
      try {
        await http.get(Uri.parse(imagemDeleteUrl!));
        print("Imagem removida do Imgbb");
      } catch (e) {
        print("Erro ao remover imagem do Imgbb: $e");
      } finally {
        imagemDeleteUrl = null;
      }
    }
  }

  Future<String?> uploadImagemWeb(String base64) async {
    try {
      final url = Uri.parse("https://api.imgbb.com/1/upload?key=$imgbbKey");
      final request = http.MultipartRequest("POST", url);
      request.fields['image'] = base64;
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (data["success"] == true) {
        imagemDeleteUrl = data["data"]["delete_url"];
        return data["data"]["url"];
      } else {
        print("ERRO IMGBB: $data");
        return null;
      }
    } catch (e) {
      print("ERRO uploadImagemWeb: $e");
      return null;
    }
  }

  Future<void> salvarProduto({
    required String custo,
    required String validade,
    required String tags,
  }) async {
    final nome = nomeController.text.trim();
    final valor = valorController.text.trim();
    final descricao = descricaoController.text.trim();
    final quantidade = int.tryParse(quantidadeController.text.trim()) ?? 0;
    final lote = loteController.text.trim();

    // VALIDAÇÃO DOS CAMPOS OBRIGATÓRIOS
    List<String> camposFaltantes = [];
    if (nome.isEmpty) camposFaltantes.add("Nome");
    if (valor.isEmpty) camposFaltantes.add("Valor de Venda");
    if (lote.isEmpty) camposFaltantes.add("Lote");
    
    if (camposFaltantes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preencha os campos obrigatórios: ${camposFaltantes.join(", ")}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // VALIDAÇÃO DE LOTE DUPLICADO
    if (editarProdutoLote == null) {
      bool loteExiste = await verificarLoteExistente(lote);
      if (loteExiste) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('O lote "$lote" já existe! Por favor, insira um lote diferente.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          abrirDialogCadastro();
        });
        return;
      }
    }

    String? imageURL;

    if (imagemApagada) {
      imageURL = null;
      await deletarImagemImgbb();
    } else if (imagemBytes != null && imagemBase64 != null) {
      imageURL = await uploadImagemWeb(imagemBase64!);

      if (produtoEditando != null && produtoEditando!['photo_url'] != null) {
        imagemDeleteUrl = produtoEditando!['delete_url'];
        await deletarImagemImgbb();
      }
    } else if (produtoEditando != null && produtoEditando!['photo_url'] != null) {
      imageURL = produtoEditando!['photo_url'];
    }

    try {
      final Map<String, dynamic> data = {
        'empresa': widget.empresa,
        'name': nome,
        'value': double.tryParse(valor) ?? 0,
        'original_value': double.tryParse(custo) ?? 0,
        'quantity': quantidade,
        'description': descricao,
        'tags': tags.isNotEmpty
            ? tags.split(',').map((e) => e.trim()).toList()
            : ['geral'],
        'updated_at': DateTime.now().toIso8601String(),
        'photo_url': imageURL,
      };

      if (editarProdutoLote == null) {
        data['lote'] = lote;
        data['created_at'] = DateTime.now().toIso8601String();
        await supabase.from('produtos').insert(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produto "$nome" adicionado!'),
            backgroundColor: const Color(0xFF0093FF),
          ),
        );
      } else {
        await supabase.from('produtos').update(data).eq('lote', editarProdutoLote!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produto atualizado!'),
            backgroundColor: Color(0xFF0093FF),
          ),
        );
        editarProdutoLote = null;
      }

      limparCampos();
      carregarProdutos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void limparCampos() {
    nomeController.clear();
    valorController.clear();
    descricaoController.clear();
    quantidadeController.clear();
    loteController.clear();
    imagemBytes = null;
    imagemBase64 = null;
    imagemDeleteUrl = null;
    produtoEditando = null;
    imagemApagada = false;
  }

  Future<void> deletarProduto(Map<String, dynamic> produto) async {
    final lote = produto['lote'];

    try {
      await supabase.from('produtos').delete().eq('lote', lote);

      if (produto['photo_url'] != null && produto['delete_url'] != null) {
        try {
          await http.get(Uri.parse(produto['delete_url']));
        } catch (e) {
          print("Erro ao remover imagem do Imgbb: $e");
        }
      }

      final themeManager = Provider.of<ThemeManager>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produto "${produto['name']}" excluído!'),
          backgroundColor: themeManager.primaryColor,
        ),
      );
      carregarProdutos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Widget para criar label com asterisco para campos obrigatórios
  Widget _labelComAsterisco(String texto, {bool obrigatorio = true}) {
    final themeManager = Provider.of<ThemeManager>(context);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: texto,
            style: TextStyle(color: themeManager.textPrimary),
          ),
          if (obrigatorio)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  void abrirDialogCadastro({Map<String, dynamic>? produto}) {
    final nomeTemp = nomeController.text;
    final valorTemp = valorController.text;
    final descTemp = descricaoController.text;
    final qtdTemp = quantidadeController.text;
    final loteTemp = loteController.text;
    final imagemBytesTemp = imagemBytes;
    final imagemBase64Temp = imagemBase64;
    final produtoEditandoTemp = produtoEditando;
    final editarLoteTemp = editarProdutoLote;
    final imagemApagadaTemp = imagemApagada;

    if (produto != null) {
      nomeController.text = produto['name'] ?? '';
      valorController.text = (produto['value'] ?? 0).toString();
      descricaoController.text = produto['description'] ?? '';
      quantidadeController.text = (produto['quantity'] ?? 0).toString();
      loteController.text = produto['lote'] ?? '';
      editarProdutoLote = produto['lote'];
      produtoEditando = Map<String, dynamic>.from(produto);
      imagemDeleteUrl = produto['delete_url'];
      imagemApagada = false;
    } else {
      nomeController.text = nomeTemp;
      valorController.text = valorTemp;
      descricaoController.text = descTemp;
      quantidadeController.text = qtdTemp;
      loteController.text = loteTemp;
      imagemBytes = imagemBytesTemp;
      imagemBase64 = imagemBase64Temp;
      produtoEditando = produtoEditandoTemp;
      editarProdutoLote = editarLoteTemp;
      imagemApagada = imagemApagadaTemp;
    }

    final custoController = TextEditingController(
        text: produto != null ? (produto['original_value'] ?? 0).toString() : '');
    final validadeController = TextEditingController(
        text: produto != null
            ? (produto['expiration_date'] ?? '').toString().split('T').first
            : '');
    final tagsController = TextEditingController(
        text: produto != null ? (produto['tags'] as List).join(', ') : '');

    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: themeManager.dialogBgColor,
          title: Text(
            produto != null ? "Editar Produto" : "Novo Produto",
            style: TextStyle(
              color: themeManager.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LOTE (Obrigatório apenas para novo)
                TextField(
                  controller: loteController,
                  enabled: produto == null,
                  style: TextStyle(color: themeManager.textPrimary),
                  decoration: InputDecoration(
                    label: _labelComAsterisco("Lote", obrigatorio: produto == null),
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: themeManager.inputBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: themeManager.primaryColor),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    filled: true,
                    fillColor: themeManager.inputBgColor,
                  ),
                ),
                const SizedBox(height: 12),
                
                // NOME (Obrigatório)
                TextField(
                  controller: nomeController,
                  style: TextStyle(color: themeManager.textPrimary),
                  decoration: InputDecoration(
                    label: _labelComAsterisco("Nome"),
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: themeManager.inputBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: themeManager.primaryColor),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    filled: true,
                    fillColor: themeManager.inputBgColor,
                  ),
                ),
                const SizedBox(height: 12),
                
                // VALOR DE VENDA (Obrigatório)
                TextField(
                  controller: valorController,
                  style: TextStyle(color: themeManager.textPrimary),
                  decoration: InputDecoration(
                    label: _labelComAsterisco("Valor de Venda"),
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: themeManager.inputBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: themeManager.primaryColor),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    filled: true,
                    fillColor: themeManager.inputBgColor,
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                
                // CUSTO ORIGINAL (Opcional)
                TextField(
                  controller: custoController,
                  style: TextStyle(color: themeManager.textPrimary),
                  decoration: InputDecoration(
                    labelText: "Custo Original",
                    labelStyle: TextStyle(color: themeManager.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: themeManager.inputBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: themeManager.primaryColor),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    filled: true,
                    fillColor: themeManager.inputBgColor,
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                
                // QUANTIDADE (Obrigatório)
                TextField(
                  controller: quantidadeController,
                  style: TextStyle(color: themeManager.textPrimary),
                  decoration: InputDecoration(
                    label: _labelComAsterisco("Quantidade"),
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: themeManager.inputBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: themeManager.primaryColor),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    filled: true,
                    fillColor: themeManager.inputBgColor,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                
                // VALIDADE (Opcional)
                TextField(
                  controller: validadeController,
                  style: TextStyle(color: themeManager.textPrimary),
                  decoration: InputDecoration(
                    labelText: "Validade (AAAA-MM-DD)",
                    labelStyle: TextStyle(color: themeManager.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: themeManager.inputBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: themeManager.primaryColor),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    filled: true,
                    fillColor: themeManager.inputBgColor,
                  ),
                ),
                const SizedBox(height: 12),
                
                // TAGS (Opcional)
                TextField(
                  controller: tagsController,
                  style: TextStyle(color: themeManager.textPrimary),
                  decoration: InputDecoration(
                    labelText: "Tags",
                    labelStyle: TextStyle(color: themeManager.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: themeManager.inputBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: themeManager.primaryColor),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    filled: true,
                    fillColor: themeManager.inputBgColor,
                  ),
                ),
                const SizedBox(height: 12),
                
                // DESCRIÇÃO (Opcional)
                TextField(
                  controller: descricaoController,
                  style: TextStyle(color: themeManager.textPrimary),
                  decoration: InputDecoration(
                    labelText: "Descrição",
                    labelStyle: TextStyle(color: themeManager.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: themeManager.inputBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: themeManager.primaryColor),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    filled: true,
                    fillColor: themeManager.inputBgColor,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // IMAGEM (Opcional)
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: (imagemBytes != null ||
                          (produto != null && produto['photo_url'] != null))
                      ? Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 140,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: themeManager.primaryColor, width: 2),
                                image: DecorationImage(
                                  image: imagemBytes != null
                                      ? MemoryImage(imagemBytes!)
                                      : NetworkImage(produto!['photo_url'] ??
                                              'https://cdn-icons-png.flaticon.com/512/1170/1170576.png')
                                          as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () async {
                                  imagemApagada = true;

                                  setState(() {
                                    imagemBytes = null;
                                    imagemBase64 = null;
                                  });

                                  if (produto != null) {
                                    await supabase
                                        .from('produtos')
                                        .update({'photo_url': null})
                                        .eq('lote', produto['lote']);
                                    setState(() {
                                      produto['photo_url'] = null;
                                    });
                                  }

                                  await deletarImagemImgbb();
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: themeManager.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      : InkWell(
                          onTap: () async {
                            await escolherImagem();
                            setStateDialog(() {});
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [themeManager.primaryColor, themeManager.primaryColorDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: themeManager.primaryColor.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.white, size: 28),
                                  SizedBox(width: 10),
                                  Text(
                                    "Adicionar Foto",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            // Botão Cancelar
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (produto != null) {
                  editarProdutoLote = null;
                  limparCampos();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: themeManager.textTertiary,
              ),
              child: Text(
                "Cancelar",
                style: TextStyle(fontWeight: FontWeight.w500, color: themeManager.textPrimary),
              ),
            ),
            // Botão Salvar com gradiente
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeManager.primaryColor, themeManager.primaryColorDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await salvarProduto(
                    custo: custoController.text,
                    validade: validadeController.text,
                    tags: tagsController.text,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Salvar",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget produtoCard(Map<String, dynamic> p) {
    final themeManager = Provider.of<ThemeManager>(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: themeManager.cardBgColor,
        border: Border.all(color: themeManager.primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              p['photo_url'] ?? 'https://cdn-icons-png.flaticon.com/512/1170/1170576.png',
              height: 70,
              width: 70,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] ?? "Sem nome",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: themeManager.textPrimary,
                  ),
                ),
                Text(
                  "Lote: ${p['lote']}",
                  style: TextStyle(
                    color: themeManager.textSecondary,
                  ),
                ),
                Text(
                  p['description'] ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: themeManager.textTertiary),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "R\$ ${p['value']}",
                    style: TextStyle(
                      color: themeManager.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: themeManager.primaryColor),
            onPressed: () => abrirDialogCadastro(produto: p),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) {
                  final themeManager = Provider.of<ThemeManager>(context);
                  return AlertDialog(
                    backgroundColor: themeManager.dialogBgColor,
                    title: Text(
                      'Excluir Produto',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    content: Text(
                      'Deseja realmente excluir "${p['name']}"?',
                      style: TextStyle(color: themeManager.textPrimary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: themeManager.textTertiary,
                        ),
                        child: Text('Cancelar', style: TextStyle(color: themeManager.textPrimary)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.red, Color(0xFFCC0000)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Excluir'),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (confirmar == true) await deletarProduto(p);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    
    return Scaffold(
      backgroundColor: themeManager.scaffoldBgColor,
      appBar: AppBar(
        title: Text(
          nomeEmpresa.isNotEmpty ? nomeEmpresa : 'Minha Empresa',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: themeManager.textPrimary,
          ),
        ),
        backgroundColor: themeManager.cardBgColor,
        foregroundColor: themeManager.textPrimary,
        automaticallyImplyLeading: false,
        actions: [
          // Botão de alternar tema
          IconButton(
            icon: Icon(
              themeManager.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
              size: 24,
              color: themeManager.textPrimary,
            ),
            onPressed: () {
              themeManager.toggleTheme();
            },
            tooltip: themeManager.isDarkMode ? 'Modo Claro' : 'Modo Escuro',
          ),
          // Botão de Sair 
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeManager.primaryColor, themeManager.primaryColorDark],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: themeManager.primaryColor.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 22),
              onPressed: _logout,
              tooltip: 'Sair',
              splashRadius: 20,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => abrirDialogCadastro(),
        backgroundColor: themeManager.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: loading
          ? Center(
              child: CircularProgressIndicator(
                color: themeManager.primaryColor,
              ),
            )
          : produtos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 80,
                        color: themeManager.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Nenhum produto cadastrado",
                        style: TextStyle(
                          fontSize: 18,
                          color: themeManager.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Clique no botão + para adicionar",
                        style: TextStyle(
                          fontSize: 14,
                          color: themeManager.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: produtos.length,
                  itemBuilder: (_, i) => produtoCard(produtos[i]),
                ),
    );
  }
}