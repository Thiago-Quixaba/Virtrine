import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
      final response = await supabase
          .from('produtos')
          .select()
          .order('created_at', ascending: false);

      final produtosList = List<Map<String, dynamic>>.from(response);

      for (var p in produtosList) {
        final empresaData = await supabase
            .from('empresas')
            .select('name, email, cellphone, locate')
            .eq('cnpj', p['empresa'])
            .maybeSingle();

        p['empresa_name'] = empresaData?['name'] ?? 'Empresa';
        p['empresa_email'] = empresaData?['email'] ?? '';
        p['empresa_cellphone'] = empresaData?['cellphone'] ?? '';
        p['empresa_locate'] = empresaData?['locate'] ?? '';
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

  Future<void> buscarProdutos(String termo) async {
    setState(() => loading = true);
    try {
      final response = await supabase
          .from('produtos')
          .select()
          .or('name.ilike.%$termo%,description.ilike.%$termo%')
          .order('created_at', ascending: false);

      var produtosList = List<Map<String, dynamic>>.from(response);

      final responseTags = await supabase
          .from('produtos')
          .select()
          .contains('tags', [termo]);

      final produtosComTags = List<Map<String, dynamic>>.from(responseTags);

      final idsExistentes = produtosList.map((p) => p['lote']).toSet();
      for (var p in produtosComTags) {
        if (!idsExistentes.contains(p['lote'])) {
          produtosList.add(p);
        }
      }

      for (var p in produtosList) {
        final empresaData = await supabase
            .from('empresas')
            .select('name, email, cellphone, locate')
            .eq('cnpj', p['empresa'])
            .maybeSingle();

        p['empresa_name'] = empresaData?['name'] ?? 'Empresa';
        p['empresa_email'] = empresaData?['email'] ?? '';
        p['empresa_cellphone'] = empresaData?['cellphone'] ?? '';
        p['empresa_locate'] = empresaData?['locate'] ?? '';
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
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar Produto',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: const [
                  Expanded(
                    child: Divider(color: Colors.blue, thickness: 2, endIndent: 10),
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
                    child: Divider(color: Colors.blue, thickness: 2, indent: 10),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : produtos.isEmpty
                        ? const Center(child: Text('Nenhum produto disponível'))
                        : ListView.builder(
                            itemCount: produtos.length,
                            itemBuilder: (context, index) {
                              final p = produtos[index];
                              final imageUrl = p['photo_url'] ??
                                  'https://cdn-icons-png.flaticon.com/512/1170/1170576.png';

                              return _categoryCard(
                                imageUrl: imageUrl,
                                category: p['name'] ?? 'Produto',
                                market: p['empresa_name'] ?? 'Empresa',
                                description: p['description'] ?? '',
                                price:
                                    'R\$ ${p['value']?.toStringAsFixed(2) ?? '0.00'}',
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text(
                                          p['name'] ?? 'Produto',
                                          textAlign: TextAlign.center,
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Center(
                                                child: Image.network(
                                                  imageUrl,
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text("Empresa: ${p['empresa_name']}"),
                                              const SizedBox(height: 5),
                                              Text("Quantidade: ${p['quantity']}"),
                                              const SizedBox(height: 5),
                                              Text("Descrição: ${p['description'] ?? 'Sem descrição'}"),
                                              const SizedBox(height: 5),
                                              if (p['expiration_date'] != null)
                                                Text("Validade: ${p['expiration_date']}"),
                                              const SizedBox(height: 5),
                                              Text("Endereço: ${p['empresa_locate']}"),
                                              const SizedBox(height: 15),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  if (p['empresa_email'] != '')
                                                    ElevatedButton.icon(
                                                      onPressed: () => _enviarEmail(p['empresa_email']),
                                                      icon: const Icon(Icons.email, color: Colors.white),
                                                      label: const Text("Email"),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.blue,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                      ),
                                                    ),
                                                  if (p['empresa_cellphone'] != '')
                                                    ElevatedButton.icon(
                                                      onPressed: () => _abrirWhatsApp(p['empresa_cellphone']),
                                                      icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                                                      label: const Text("WhatsApp"),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.green,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 20),
                                              Center(
                                                child: Text(
                                                  "Preço: R\$ ${p['value']?.toStringAsFixed(2) ?? '0.00'}",
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
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

  Widget _categoryCard({
    required String imageUrl,
    required String category,
    required String market,
    required String description,
    required String price,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
          children: [
            Container(
              height: 65,
              width: 65,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const Icon(Icons.fastfood, size: 30, color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(width: 14),
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
                      Text(
                        market,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6F6F6F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
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

  void _abrirWhatsApp(String numero) async {
    final Uri whatsappUrl = Uri.parse("https://wa.me/$numero");
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _enviarEmail(String email) async {
    final Uri emailUrl = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUrl)) {
      await launchUrl(emailUrl);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
