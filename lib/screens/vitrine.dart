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
  
  // Mapa para armazenar as avaliações de cada produto
  Map<String, Map<String, dynamic>> _avaliacoesPorProduto = {};
  
  // Mapa para armazenar a avaliação do dispositivo atual para cada produto
  Map<String, Map<String, dynamic>> _minhasAvaliacoes = {};
  
  // Identificador único do dispositivo (simulado)
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initDeviceId();
    carregarProdutos();
  }

  // Inicializar identificador do dispositivo
  void _initDeviceId() {
    // Usar timestamp como identificador único para este dispositivo/sessão
    _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    
    // Tentar recuperar de localStorage se já existe
    // Isso mantém o mesmo ID entre sessões
    // _deviceId = await _getStoredDeviceId();
    print('Device ID: $_deviceId');
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
        
        // Carregar avaliações para este produto
        await _carregarAvaliacoesProduto(p['lote']);
      }

      setState(() {
        produtos = produtosList;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar produtos: $e')));
    }
  }

  // ===== FUNÇÕES DE AVALIAÇÃO (SEM LOGIN) =====
  
  Future<void> _carregarAvaliacoesProduto(String produtoId) async {
    try {
      // Carregar média de avaliações
      final response = await supabase
          .from('avaliacoes')
          .select('nota, comentario, device_id')
          .eq('produto_id', produtoId);

      final avaliacoes = List<Map<String, dynamic>>.from(response);
      
      if (avaliacoes.isNotEmpty) {
        final notas = avaliacoes.where((a) => a['nota'] != null).map((a) => a['nota'] as int).toList();
        final media = notas.isNotEmpty ? notas.reduce((a, b) => a + b) / notas.length : 0.0;
        final totalAvaliacoes = notas.length;
        
        _avaliacoesPorProduto[produtoId] = {
          'media': media,
          'total': totalAvaliacoes,
          'avaliacoes': avaliacoes,
        };
      } else {
        _avaliacoesPorProduto[produtoId] = {
          'media': 0.0,
          'total': 0,
          'avaliacoes': [],
        };
      }
      
      // Verificar se este dispositivo já avaliou este produto
      if (_deviceId != null) {
        final minhaAvaliacao = await supabase
            .from('avaliacoes')
            .select()
            .eq('produto_id', produtoId)
            .eq('device_id', _deviceId!)
            .maybeSingle();
            
        if (minhaAvaliacao != null) {
          _minhasAvaliacoes[produtoId] = Map<String, dynamic>.from(minhaAvaliacao);
        }
      }
    } catch (e) {
      print('Erro ao carregar avaliações: $e');
    }
  }

  Future<void> _avaliarProduto(String produtoId, int nota, String? comentario) async {
    try {
      if (_deviceId == null) {
        _initDeviceId();
      }

      // Verificar se já existe uma avaliação deste dispositivo
      final avaliacaoExistente = await supabase
          .from('avaliacoes')
          .select()
          .eq('produto_id', produtoId)
          .eq('device_id', _deviceId!)
          .maybeSingle();

      if (avaliacaoExistente != null) {
        // Atualizar avaliação existente
        await supabase
            .from('avaliacoes')
            .update({
              'nota': nota,
              'comentario': comentario,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', avaliacaoExistente['id']);
      } else {
        // Criar nova avaliação
        await supabase.from('avaliacoes').insert({
          'produto_id': produtoId,
          'device_id': _deviceId!,
          'nota': nota,
          'comentario': comentario,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Atualizar dados localmente
      _minhasAvaliacoes[produtoId] = {
        'nota': nota,
        'comentario': comentario,
        'produto_id': produtoId,
        'device_id': _deviceId!,
      };

      // Recarregar as avaliações do produto
      await _carregarAvaliacoesProduto(produtoId);
      
      setState(() {}); // Forçar rebuild

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação enviada com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar avaliação: $e')),
      );
    }
  }

  void _mostrarDialogAvaliacao(String produtoId, String produtoNome) {
    final minhaAvaliacao = _minhasAvaliacoes[produtoId];
    int notaSelecionada = minhaAvaliacao?['nota'] ?? 0;
    final TextEditingController comentarioController = TextEditingController(
      text: minhaAvaliacao?['comentario'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Avaliar: $produtoNome'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Selecione sua nota:',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              notaSelecionada = index + 1;
                            });
                          },
                          child: Icon(
                            index < notaSelecionada
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 40,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: comentarioController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Comentário (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Você pode avaliar sem fazer login!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    if (_minhasAvaliacoes.containsKey(produtoId))
                      TextButton(
                        onPressed: () async {
                          try {
                            await supabase
                                .from('avaliacoes')
                                .delete()
                                .eq('produto_id', produtoId)
                                .eq('device_id', _deviceId!);
                            
                            _minhasAvaliacoes.remove(produtoId);
                            await _carregarAvaliacoesProduto(produtoId);
                            setState(() {});
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Avaliação removida!')),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro ao remover avaliação: $e')),
                            );
                          }
                        },
                        child: const Text(
                          'Remover minha avaliação',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (notaSelecionada == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selecione uma nota')),
                      );
                      return;
                    }
                    
                    await _avaliarProduto(
                      produtoId,
                      notaSelecionada,
                      comentarioController.text.trim(),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Enviar Avaliação'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarTodasAvaliacoes(String produtoId, String produtoNome) {
    final avaliacoes = _avaliacoesPorProduto[produtoId]?['avaliacoes'] ?? [];
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Avaliações: $produtoNome'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Estatísticas
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              _avaliacoesPorProduto[produtoId]?['media']?.toStringAsFixed(1) ?? '0.0',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                            const Text(
                              'Média',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${_avaliacoesPorProduto[produtoId]?['total'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Text(
                              'Avaliações',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                
                // Lista de avaliações
                Expanded(
                  child: avaliacoes.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_border, size: 50, color: Colors.grey),
                              SizedBox(height: 10),
                              Text(
                                'Seja o primeiro a avaliar!',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: avaliacoes.length,
                          itemBuilder: (context, index) {
                            final avaliacao = avaliacoes[index];
                            final isMinhaAvaliacao = avaliacao['device_id'] == _deviceId;
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isMinhaAvaliacao ? Colors.green[100] : Colors.blue[100],
                                  child: Icon(
                                    isMinhaAvaliacao ? Icons.person : Icons.person_outline,
                                    size: 20,
                                    color: isMinhaAvaliacao ? Colors.green : Colors.blue,
                                  ),
                                ),
                                title: Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      starIndex < (avaliacao['nota'] ?? 0)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  }),
                                ),
                                subtitle: avaliacao['comentario'] != null && avaliacao['comentario'].isNotEmpty
                                    ? Text(avaliacao['comentario'])
                                    : const Text('Sem comentário'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${avaliacao['nota'] ?? 0}/5',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    if (isMinhaAvaliacao)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Você',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => _mostrarDialogAvaliacao(produtoId, produtoNome),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 20),
                  SizedBox(width: 5),
                  Text('Avaliar'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  // ===== FIM DAS FUNÇÕES DE AVALIAÇÃO =====

  Future<void> buscarProdutos(String termo) async {
    setState(() => loading = true);
    try {
      final response = await supabase
          .from('produtos')
          .select()
          .or('name.ilike.%$termo%,description.ilike.%$termo%')
          .order('created_at', ascending: false);

      var produtosList = List<Map<String, dynamic>>.from(response);

      final responseTags = await supabase.from('produtos').select().contains(
        'tags',
        [termo],
      );

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
        
        // Carregar avaliações
        await _carregarAvaliacoesProduto(p['lote']);
      }

      setState(() {
        produtos = produtosList;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao buscar produtos: $e')));
    }
  }

  Future<void> buscarProdutosPorFaixa(double precoMin, double precoMax) async {
    setState(() => loading = true);
    try {
      final response = await supabase
          .from('produtos')
          .select()
          .gte('value', precoMin)
          .lte('value', precoMax)
          .order('created_at', ascending: false);

      var produtosList = List<Map<String, dynamic>>.from(response);

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
        
        // Carregar avaliações
        await _carregarAvaliacoesProduto(p['lote']);
      }

      setState(() {
        produtos = produtosList;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar produtos por faixa: $e')),
      );
    }
  }

  String limitarTexto(String texto, int limite) {
    if (texto.length <= limite) return texto;
    
    // Encontrar o último espaço antes do limite para não cortar palavras
    final ultimoEspaco = texto.lastIndexOf(' ', limite - 3);
    if (ultimoEspaco > 0 && ultimoEspaco > limite - 10) {
      return texto.substring(0, ultimoEspaco) + '...';
    }
    return texto.substring(0, limite - 3) + '...';
  }

  void _abrirWhatsApp(String numero) async {
    try {
      String cleanedNumber = numero.replaceAll(RegExp(r'[^\d]'), '');
      if (!cleanedNumber.startsWith('55')) cleanedNumber = '55$cleanedNumber';
      final Uri whatsappUrl = Uri.parse("https://wa.me/$cleanedNumber");
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
      );
    }
  }

  void _enviarEmail(String email) async {
    try {
      final Uri emailUrl = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          'subject': 'Contato via App',
          'body': '',
        },
      );
      await launchUrl(emailUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o app de e-mail')),
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
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      final TextEditingController minController =
                          TextEditingController();
                      final TextEditingController maxController =
                          TextEditingController();

                      return AlertDialog(
                        title: const Text('Filtrar por preço'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: minController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Preço mínimo',
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: maxController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Preço máximo',
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final precoMin =
                                  double.tryParse(minController.text) ?? 0;
                              final precoMax =
                                  double.tryParse(maxController.text) ??
                                      double.infinity;

                              await buscarProdutosPorFaixa(
                                  precoMin, precoMax);
                              Navigator.pop(context);
                            },
                            child: const Text('Aplicar'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Filtrar por preço'),
              ),
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
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : produtos.isEmpty
                        ? const Center(child: Text('Nenhum produto disponível'))
                        : ListView.builder(
                            itemCount: produtos.length,
                            itemBuilder: (context, index) {
                              final p = produtos[index];
                              final produtoId = p['lote'];
                              final avaliacoes = _avaliacoesPorProduto[produtoId];
                              final media = avaliacoes?['media'] ?? 0.0;
                              final totalAvaliacoes = avaliacoes?['total'] ?? 0;
                              final minhaAvaliacao = _minhasAvaliacoes[produtoId];
                              
                              final imageUrl = p['photo_url'] ??
                                  'https://cdn-icons-png.flaticon.com/512/1170/1170576.png';

                              return GestureDetector(
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
                                                child: Container(
                                                  height: 150,
                                                  width: 150,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.grey.withOpacity(0.3),
                                                        blurRadius: 5,
                                                        offset: const Offset(0, 3),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stack) {
                                                        return Container(
                                                          color: Colors.grey[200],
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.shopping_bag,
                                                              size: 50,
                                                              color: Colors.orange,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              
                                              // ===== SEÇÃO DE AVALIAÇÕES =====
                                              Card(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(12.0),
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                    'Avaliação: ',
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      color: Colors.grey[700],
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    media.toStringAsFixed(1),
                                                                    style: const TextStyle(
                                                                      fontSize: 18,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: Colors.amber,
                                                                    ),
                                                                  ),
                                                                  const Text('/5'),
                                                                ],
                                                              ),
                                                              const SizedBox(height: 4),
                                                              Row(
                                                                children: List.generate(5, (index) {
                                                                  return Icon(
                                                                    index < media.round()
                                                                        ? Icons.star
                                                                        : Icons.star_border,
                                                                    color: Colors.amber,
                                                                    size: 20,
                                                                  );
                                                                }),
                                                              ),
                                                            ],
                                                          ),
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.end,
                                                            children: [
                                                              Text(
                                                                '$totalAvaliacoes avaliação${totalAvaliacoes != 1 ? 'es' : ''}',
                                                                style: TextStyle(
                                                                  color: Colors.grey[600],
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 8),
                                                              ElevatedButton.icon(
                                                                onPressed: () => _mostrarTodasAvaliacoes(produtoId, p['name'] ?? 'Produto'),
                                                                icon: const Icon(Icons.rate_review, size: 16),
                                                                label: const Text('Ver todas'),
                                                                style: ElevatedButton.styleFrom(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                  backgroundColor: Colors.blue[50],
                                                                  foregroundColor: Colors.blue,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 10),
                                                      ElevatedButton(
                                                        onPressed: () => _mostrarDialogAvaliacao(produtoId, p['name'] ?? 'Produto'),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: minhaAvaliacao != null ? Colors.green : Colors.amber,
                                                          minimumSize: const Size(double.infinity, 40),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(
                                                              minhaAvaliacao != null ? Icons.star : Icons.star_border,
                                                              color: Colors.white,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              minhaAvaliacao != null 
                                                                  ? 'Sua avaliação: ${minhaAvaliacao['nota']}/5'
                                                                  : 'Avaliar este produto',
                                                              style: const TextStyle(color: Colors.white),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              // ===== FIM DA SEÇÃO DE AVALIAÇÕES =====
                                              
                                              Text("Empresa: ${p['empresa_name']}"),
                                              const SizedBox(height: 5),
                                              Text("Quantidade: ${p['quantity']}"),
                                              const SizedBox(height: 5),
                                              Text(
                                                "Descrição: ${p['description'] ?? 'Sem descrição'}",
                                              ),
                                              const SizedBox(height: 5),
                                              if (p['expiration_date'] != null)
                                                Text(
                                                  "Validade: ${p['expiration_date']}",
                                                ),
                                              const SizedBox(height: 5),
                                              Text(
                                                "Endereço: ${p['empresa_locate']}",
                                              ),
                                              const SizedBox(height: 15),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                children: [
                                                  if (p['empresa_email'] != '')
                                                    ElevatedButton.icon(
                                                      onPressed: () =>
                                                          _enviarEmail(
                                                              p['empresa_email']),
                                                      icon: const Icon(
                                                          Icons.email,
                                                          color: Colors.white),
                                                      label:
                                                          const Text("Email"),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.blue,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12),
                                                        ),
                                                      ),
                                                    ),
                                                  if (p['empresa_cellphone'] !=
                                                      '')
                                                    ElevatedButton.icon(
                                                      onPressed: () =>
                                                          _abrirWhatsApp(
                                                              p[
                                                                  'empresa_cellphone']),
                                                      icon: const FaIcon(
                                                        FontAwesomeIcons
                                                            .whatsapp,
                                                        color: Colors.white,
                                                      ),
                                                      label: const Text(
                                                          "WhatsApp"),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.green,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12),
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
                                child: _categoryCard(
                                  imageUrl: imageUrl,
                                  productName: p['name'] ?? 'Produto',
                                  empresa: p['empresa_name'] ?? 'Empresa',
                                  description: p['description'] ?? '',
                                  price: p['value']?.toStringAsFixed(2) ?? '0.00',
                                  avaliacao: _avaliacoesPorProduto[produtoId]?['media'] ?? 0.0,
                                  totalAvaliacoes: _avaliacoesPorProduto[produtoId]?['total'] ?? 0,
                                  minhaAvaliacao: _minhasAvaliacoes.containsKey(produtoId),
                                ),
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

  // WIDGET _categoryCard
  Widget _categoryCard({
    required String imageUrl,
    required String productName,
    required String empresa,
    required String description,
    required String price,
    double avaliacao = 0.0,
    int totalAvaliacoes = 0,
    bool minhaAvaliacao = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGEM DO PRODUTO
          Container(
            width: 90,
            height: 90,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.shopping_bag,
                        size: 40,
                        color: Colors.orange,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // INFORMAÇÕES DO PRODUTO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NOME DO PRODUTO (SEM CORTAR)
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                // NOME DA EMPRESA
                Text(
                  empresa,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                // DESCRIÇÃO (SIMPLIFICADA)
                if (description.isNotEmpty)
                  Text(
                    description.length > 50
                        ? '${description.substring(0, 50)}...'
                        : description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                
                const SizedBox(height: 6),
                
                // AVALIAÇÃO
                Row(
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < avaliacao.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        );
                      }),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${avaliacao.toStringAsFixed(1)} ($totalAvaliacoes)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (minhaAvaliacao)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 10, color: Colors.green[700]),
                            const SizedBox(width: 2),
                            Text(
                              'Você avaliou',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                // PREÇO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'R\$ $price',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00A86B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Ver detalhes',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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