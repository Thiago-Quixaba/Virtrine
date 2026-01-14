import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

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
  }

  Future<void> carregarProdutos() async {
    setState(() => loading = true);
    final response = await supabase
        .from('produtos')
        .select()
        .eq('empresa', widget.empresa)
        .order('created_at', ascending: false);

    setState(() {
      produtos = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
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
      debugPrint("Erro ao verificar lote: $e");
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
        debugPrint("Imagem removida do Imgbb");
      } catch (e) {
        debugPrint("Erro ao remover imagem do Imgbb: $e");
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
        debugPrint("ERRO IMGBB: $data");
        return null;
      }
    } catch (e) {
      debugPrint("ERRO uploadImagemWeb: $e");
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

    // VALIDAÇÃO DE LOTE DUPLICADO (apenas para novo cadastro)
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
        'expiration_date': validade.isNotEmpty
            ? DateTime.parse(validade).toIso8601String()
            : null,
        'updated_at': DateTime.now().toIso8601String(),
        'photo_url': imageURL,
      };

      if (editarProdutoLote == null) {
        data['lote'] = lote;
        data['created_at'] = DateTime.now().toIso8601String();
        await supabase.from('produtos').insert(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produto "$nome" adicionado!')),
        );
      } else {
        await supabase.from('produtos').update(data).eq('lote', editarProdutoLote!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto atualizado!')),
        );
        editarProdutoLote = null;
      }

      limparCampos();
      carregarProdutos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
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
          debugPrint("Erro ao remover imagem do Imgbb: $e");
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produto "${produto['name']}" excluído!')),
      );
      carregarProdutos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  // Widget para criar label com asterisco para campos obrigatórios
  Widget _labelComAsterisco(String texto, {bool obrigatorio = true}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: texto,
            style: const TextStyle(color: Colors.black87),
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

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(produto != null ? "Editar Produto" : "Novo Produto"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                // LOTE (Obrigatório apenas para novo)
                TextField(
                  controller: loteController,
                  enabled: produto == null,
                  decoration: InputDecoration(
                    label: _labelComAsterisco("Lote", obrigatorio: produto == null),
                  ),
                ),
                
                // NOME (Obrigatório)
                TextField(
                  controller: nomeController,
                  decoration: InputDecoration(
                    label: _labelComAsterisco("Nome"),
                  ),
                ),
                
                // VALOR DE VENDA (Obrigatório)
                TextField(
                  controller: valorController,
                  decoration: InputDecoration(
                    label: _labelComAsterisco("Valor de Venda"),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                
                // CUSTO ORIGINAL (Opcional)
                TextField(
                  controller: custoController,
                  decoration: const InputDecoration(
                    labelText: "Custo Original",
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                
                // QUANTIDADE (Obrigatório)
                TextField(
                  controller: quantidadeController,
                  decoration: InputDecoration(
                    label: _labelComAsterisco("Quantidade"),
                  ),
                  keyboardType: TextInputType.number,
                ),
                
                // VALIDADE (Opcional)
                TextField(
                  controller: validadeController,
                  decoration: const InputDecoration(
                    labelText: "Validade (AAAA-MM-DD)",
                  ),
                ),
                
                // TAGS (Opcional)
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: "Tags",
                  ),
                ),
                
                // DESCRIÇÃO (Opcional)
                TextField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    labelText: "Descrição",
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // IMAGEM (Opcional) - SEM ASTERISCO
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
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          height: 70,
                          width: double.infinity,
                          child: InkWell(
                            onTap: () async {
                              await escolherImagem();
                              setStateDialog(() {});
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [Colors.blue, Colors.lightBlueAccent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo, color: Colors.white, size: 28),
                                  SizedBox(width: 10),
                                  Text(
                                    "Adicionar Foto",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                // REMOVIDA A LEGENDA DOS ASTERISCOS
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (produto != null) {
                  editarProdutoLote = null;
                  limparCampos();
                }
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await salvarProduto(
                  custo: custoController.text,
                  validade: validadeController.text,
                  tags: tagsController.text,
                );
              },
              child: const Text("Salvar"),
            ),
          ],
        ),
      ),
    );
  }

  Widget produtoCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                ),
                ),
                Text("Lote: ${p['lote']}"),
                Text(
                  p['description'] ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "R\$ ${p['value']}",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => abrirDialogCadastro(produto: p),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Confirma exclusão?'),
                  content: Text('Deseja realmente excluir "${p['name']}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
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
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => abrirDialogCadastro(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : produtos.isEmpty
                ? const Center(child: Text("Nenhum produto cadastrado"))
                : ListView.builder(
                    itemCount: produtos.length,
                    itemBuilder: (_, i) => produtoCard(produtos[i]),
                  ),
      ),
    );
  }
}