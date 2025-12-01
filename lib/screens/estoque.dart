import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  String? editarProdutoLote;

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
        'expiration_date':
            validade.isNotEmpty ? DateTime.parse(validade).toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (editarProdutoLote == null) {
        // Criar
        data['lote'] = lote;
        data['created_at'] = DateTime.now().toIso8601String();

        await supabase.from('produtos').insert(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produto "$nome" adicionado!')),
        );
      } else {
        // Editar
        await supabase
            .from('produtos')
            .update(data)
            .eq('lote', editarProdutoLote!);

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
  }

  void abrirDialogCadastro({Map<String, dynamic>? produto}) {
    if (produto != null) {
      nomeController.text = produto['name'] ?? '';
      valorController.text = (produto['value'] ?? 0).toString();
      descricaoController.text = produto['description'] ?? '';
      quantidadeController.text = (produto['quantity'] ?? 0).toString();
      loteController.text = produto['lote'] ?? '';
      editarProdutoLote = produto['lote'];
    }

    final TextEditingController custoController = TextEditingController(
        text: produto != null ? (produto['original_value'] ?? 0).toString() : '');

    final TextEditingController validadeController = TextEditingController(
        text: produto != null
            ? (produto['expiration_date'] ?? '').toString().split('T').first
            : '');

    final TextEditingController tagsController = TextEditingController(
        text: produto != null ? (produto['tags'] as List).join(', ') : '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
                decoration:
                    const InputDecoration(labelText: "Validade (AAAA-MM-DD)"),
              ),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(labelText: "Tags"),
              ),
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(labelText: "Descrição"),
              ),
              if (produto != null && produto['photo_url'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Image.network(
                    produto['photo_url'],
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 50),
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
              p['photo_url'] ??
                  'https://cdn-icons-png.flaticon.com/512/1170/1170576.png',
              height: 70,
              width: 70,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
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
                      fontWeight: FontWeight.bold, fontSize: 16),
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
                        color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => abrirDialogCadastro(produto: p),
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
