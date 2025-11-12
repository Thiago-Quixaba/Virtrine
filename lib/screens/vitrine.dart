import 'dart:async'; // precisa importar isso!
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Vitrine extends StatefulWidget {
  const Vitrine({super.key});

  @override
  State<Vitrine> createState() => _VitrineState();
}

class _VitrineState extends State<Vitrine> {
  final TextEditingController _searchController = TextEditingController();
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> produtos = [];
  bool loading = true;
  Timer? _debounce; 

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    carregarProdutos();
  }
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      final termo = _searchController.text.trim();
      if (termo.isEmpty) {
        carregarProdutos();
      } else {
        buscarProdutos(termo);
      }
    });
  }

  Future<void> carregarProdutos() async {
    setState(() => loading = true);
    try {
      // Busca todos os produtos
      final response = await supabase
          .from('produtos')
          .select()
          .order('created_at', ascending: false);

      final produtosList = List<Map<String, dynamic>>.from(response);

      // Para cada produto, pega o nome da empresa pelo CNPJ
      for (var p in produtosList) {
        final empresaData = await supabase
            .from('empresas')
            .select('name')
            .eq('cnpj', p['empresa'])
            .maybeSingle();

        p['empresa_name'] = empresaData != null ? empresaData['name'] : 'Empresa';
      }

      setState(() {
        produtos = produtosList;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar produtos: $e')),
      );
    }
  }

// Em progresso
  Future<void> buscarProdutos(String termo) async {
    setState(() => loading = true);
    try {
      // Busca nome e descrição
      final response = await supabase
          .from('produtos')
          .select()
          .or('name.ilike.%$termo%,description.ilike.%$termo%')
          .order('created_at', ascending: false);

      var produtosList = List<Map<String, dynamic>>.from(response);

      // Busca por tags diretamente no banco
      final responseTags = await supabase
          .from('produtos')
          .select()
          .contains('tags', [termo]); // busca se o array contém o termo exato

      final produtosComTags = List<Map<String, dynamic>>.from(responseTags);

      // Combina os resultados (sem duplicar)
      final idsExistentes = produtosList.map((p) => p['lote']).toSet();
      for (var p in produtosComTags) {
        if (!idsExistentes.contains(p['lote'])) {
          produtosList.add(p);
        }
      }

      // Busca o nome da empresa de cada produto
      for (var p in produtosList) {
        final empresaData = await supabase
            .from('empresas')
            .select('name')
            .eq('cnpj', p['empresa'])
            .maybeSingle();

        p['empresa_name'] = empresaData != null ? empresaData['name'] : 'Empresa';
      }

      setState(() {
        produtos = produtosList;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar produtos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),

              // BARRA DE PESQUISA
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar Produto',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 255, 255, 255),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // TÍTULO PRODUTOS
              Row(
                children: const [
                  Expanded(
                    child: Divider(
                      color: Colors.blue,
                      thickness: 2,
                      endIndent: 10,
                    ),
                  ),
                  Text(
                    "PRODUTOS",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.blue,
                      thickness: 2,
                      indent: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // LISTA DE PRODUTOS
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : produtos.isEmpty
                        ? const Center(child: Text('Nenhum produto disponível'))
                        : ListView.builder(
                            itemCount: produtos.length,
                            itemBuilder: (context, index) {
                              final p = produtos[index];
                              return _categoryCard(
                                imageUrl: p['image_url'] ??
                                    'https://cdn-icons-png.flaticon.com/512/1170/1170576.png',
                                category: p['name'] ?? 'Produto',
                                market: p['empresa_name'] ?? 'Empresa',
                                description: p['description'] ?? '',
                                price: 'R\$ ${p['value']?.toStringAsFixed(2) ?? '0.00'}',
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text(p['name'] ?? 'Produto', textAlign: TextAlign.center),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start, // <- importante
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Center(
                                                child: Image.network(
                                                    p['image_url'] ?? 'https://cdn-icons-png.flaticon.com/512/1170/1170576.png',
                                                    height: 120,
                                                    fit: BoxFit.cover,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                "Empresa: ${p['empresa_name'] ?? 'Empresa'}",
                                                style: const TextStyle(color: Color(0xFF6F6F6F)),
                                                textAlign: TextAlign.left, // ainda vale, mas crossAxisStart faz a diferença
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                "Descrição: ${p['description'] ?? 'Sem descrição'}",
                                                textAlign: TextAlign.left,
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                "Preço: R\$ ${p['value']?.toStringAsFixed(2) ?? '0.00'}",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF00A86B),
                                                ),
                                                textAlign: TextAlign.left,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // CARD DE PRODUTO
Widget _categoryCard({
  required String imageUrl,
  required String category,
  required String market,
  required String description,
  required String price,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap, // ← executa a função passada
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 65,
            width: 65,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.fastfood,
                      size: 30, color: Colors.orange);
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          // INFORMAÇÕES DO PRODUTO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        market,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6F6F6F),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A8A8A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00A86B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}