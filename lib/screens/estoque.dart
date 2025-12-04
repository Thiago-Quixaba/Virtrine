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

  Future<void> escolherImagem() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (resultado != null && resultado.files.first.bytes != null) {
      setState(() {
        imagemBytes = resultado.files.first.bytes!;
        imagemBase64 = base64Encode(imagemBytes!);
        imagemApagada = false; // Se escolheu nova imagem, não está apagada
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

    if (nome.isEmpty || valor.isEmpty || lote.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha nome, valor e lote!')),
      );
      return;
    }

    String? imageURL;

    // Se apagou a imagem, não enviar URL antiga
    if (imagemApagada) {
      imageURL = null;
      await deletarImagemImgbb(); // Remove do Imgbb se havia
    } else if (imagemBytes != null && imagemBase64 != null) {
      // Se escolheu nova imagem
      imageURL = await uploadImagemWeb(imagemBase64!);

      // Remove antiga se existia
      if (produtoEditando != null && produtoEditando!['photo_url'] != null) {
        imagemDeleteUrl = produtoEditando!['delete_url'];
        await deletarImagemImgbb();
      }
    } else if (produtoEditando != null && produtoEditando!['photo_url'] != null) {
      imageURL = produtoEditando!['photo_url']; // Mantém a antiga se nada mudou
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

      // Deleta imagem do Imgbb se houver
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

  void abrirDialogCadastro({Map<String, dynamic>? produto}) {
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
      limparCampos();
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
                TextField(
                  controller: loteController,
                  enabled: produto == null,
                  decoration: const InputDecoration(labelText: "Lote"),
                ),
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: "Nome"),
                ),
                TextField(
                  controller: valorController,
                  decoration: const InputDecoration(labelText: "Valor de Venda"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: custoController,
                  decoration: const InputDecoration(labelText: "Custo Original"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: quantidadeController,
                  decoration: const InputDecoration(labelText: "Quantidade"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: validadeController,
                  decoration: const InputDecoration(labelText: "Validade (AAAA-MM-DD)"),
                ),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(labelText: "Tags"),
                ),
                TextField(
                  controller: descricaoController,
                  decoration: const InputDecoration(labelText: "Descrição"),
                ),
                const SizedBox(height: 12),

                // IMAGEM
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
                                  // Marca imagem como apagada
                                  imagemApagada = true;

                                  // Remove foto do estado
                                  setState(() {
                                    imagemBytes = null;
                                    imagemBase64 = null;
                                  });

                                  // Atualiza no Supabase para ficar padrão
                                  if (produto != null) {
                                    await supabase
                                        .from('produtos')
                                        .update({'photo_url': null})
                                        .eq('lote', produto['lote']);
                                    setState(() {
                                      produto['photo_url'] = null;
                                    });
                                  }

                                  // Remove do Imgbb
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                editarProdutoLote = null;
                limparCampos();
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                salvarProduto(
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
