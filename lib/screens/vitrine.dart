import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Vitrine extends StatefulWidget {
  const Vitrine({super.key});

  @override
  State<Vitrine> createState() => _VitrineState();
}

class _VitrineState extends State<Vitrine> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> produtos = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    carregarProdutos();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LOGO
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 75,
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // BARRA DE PESQUISA
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar Produto',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.grey.shade300),
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
                                price:
                                    'R\$ ${p['value']?.toStringAsFixed(2) ?? '0.00'}',
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8), // tom de fundo off-white, suave e elegante
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
          // ÍCONE/IMAGEM à esquerda
          Container(
            height: 65,
            width: 65,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.fastfood, size: 30, color: Colors.orange);
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
                    Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
                  ],
                ),
              
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
                    color: Color(0xFF00A86B), // verde suave moderno
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}