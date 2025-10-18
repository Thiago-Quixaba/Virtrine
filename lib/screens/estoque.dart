import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Estoque extends StatefulWidget {
  final String empresa; // nome ou CNPJ da empresa logada
  const Estoque({super.key, required this.empresa});

  @override
  State<Estoque> createState() => _EstoqueState();
}

class _EstoqueState extends State<Estoque> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> produtos = [];
  bool loading = true;

  final TextEditingController nomeController = TextEditingController();
  final TextEditingController valorController = TextEditingController();
  final TextEditingController descricaoController = TextEditingController();
  final TextEditingController quantidadeController = TextEditingController();
  final TextEditingController loteController = TextEditingController();

  String? editarProdutoLote; // Lote do produto que está sendo editado

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

  Future<void> salvarProdutoComCamposExtras({
    required String custo,
    required String validade,
    required String tags,
  }) async {
    final nome = nomeController.text.trim();
    final valor = valorController.text.trim();
    final desc = descricaoController.text.trim();
    final quantidade = int.tryParse(quantidadeController.text.trim()) ?? 0;
    final lote = loteController.text.trim();

    if (nome.isEmpty || valor.isEmpty || lote.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha nome, valor e lote!')),
      );
      return;
    }

    try {
      final data = {
        'empresa': widget.empresa,
        'name': nome,
        'value': double.tryParse(valor) ?? 0,
        'original_value': double.tryParse(custo) ?? 0,
        'quantity': quantidade,
        'description': desc,
        'tags': tags.isNotEmpty
            ? tags.split(',').map((e) => e.trim()).toList()
            : ['geral'],
        'expiration_date': validade.isNotEmpty
            ? DateTime.parse(validade).toIso8601String()
            : null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (editarProdutoLote == null) {
        // Novo produto — usa o lote informado
        data['lote'] = lote;
        data['created_at'] = DateTime.now().toIso8601String();

        await supabase.from('produtos').insert(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produto "$nome" adicionado com sucesso!')),
        );
      } else {
        // Atualização — não altera o lote
        await supabase
            .from('produtos')
            .update(data)
            .eq('lote', editarProdutoLote!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto atualizado com sucesso!')),
        );
        editarProdutoLote = null;
      }

      nomeController.clear();
      valorController.clear();
      descricaoController.clear();
      quantidadeController.clear();
      loteController.clear();

      await carregarProdutos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    }
  }

  Future<void> deletarProduto(String lote) async {
    try {
      await supabase.from('produtos').delete().eq('lote', lote);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto excluído com sucesso!')),
      );
      await carregarProdutos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  void confirmarExclusao(Map<String, dynamic> produto) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Produto'),
        content:
            Text('Tem certeza que deseja excluir "${produto['name']}" do estoque?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deletarProduto(produto['lote']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void mostrarDialogoCadastro({Map<String, dynamic>? produto}) {
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
        text: produto != null ? (produto['tags'] as List?)?.join(', ') ?? '' : '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(produto != null ? "Editar Produto" : "Novo Produto"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo Lote — obrigatório e NÃO editável ao editar produto
              TextField(
                controller: loteController,
                enabled: produto == null,
                decoration: InputDecoration(
                  labelText: 'Lote (obrigatório)',
                  hintText: produto == null ? 'Digite o número/lote do produto' : '',
                ),
              ),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Produto'),
              ),
              TextField(
                controller: valorController,
                decoration: const InputDecoration(labelText: 'Valor de Venda'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: custoController,
                decoration: const InputDecoration(labelText: 'Custo Original'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: quantidadeController,
                decoration: const InputDecoration(labelText: 'Quantidade'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: validadeController,
                decoration: const InputDecoration(
                    labelText: 'Data de Validade (AAAA-MM-DD)'),
                keyboardType: TextInputType.datetime,
              ),
              TextField(
                controller: tagsController,
                decoration:
                    const InputDecoration(labelText: 'Tags (separadas por vírgula)'),
              ),
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              if (produto != null) ...[
                const SizedBox(height: 10),
                Text(
                  "Lote: ${produto['lote']}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  "Criado em: ${produto['created_at']?.toString().split('T').first ?? '-'}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  "Atualizado em: ${produto['updated_at']?.toString().split('T').first ?? '-'}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              editarProdutoLote = null;
              nomeController.clear();
              valorController.clear();
              descricaoController.clear();
              quantidadeController.clear();
              loteController.clear();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              salvarProdutoComCamposExtras(
                custo: custoController.text,
                validade: validadeController.text,
                tags: tagsController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0093FF),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _produtoCard({required Map<String, dynamic> produto}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'https://cdn-icons-png.flaticon.com/512/1170/1170576.png',
              height: 60,
              width: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        produto['name'] ?? 'Sem nome',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => mostrarDialogoCadastro(produto: produto),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => confirmarExclusao(produto),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "Lote: ${produto['lote'] ?? '-'}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  produto['description'] ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    "R\$ ${produto['value'] ?? 0}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0093FF),
        onPressed: () => mostrarDialogoCadastro(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LOGO
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 80),
                ],
              ),
              const SizedBox(height: 10),

              // TÍTULO
              Row(
                children: const [
                  Expanded(
                      child: Divider(color: Colors.blue, thickness: 2, endIndent: 10)),
                  Text(
                    "MEUS PRODUTOS",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Expanded(
                      child: Divider(color: Colors.blue, thickness: 2, indent: 10)),
                ],
              ),
              const SizedBox(height: 15),

              // LISTAGEM
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : produtos.isEmpty
                        ? const Center(child: Text('Nenhum produto cadastrado'))
                        : ListView.builder(
                            itemCount: produtos.length,
                            itemBuilder: (context, index) {
                              final p = produtos[index];
                              return _produtoCard(produto: p);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
