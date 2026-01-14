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
  
  Map<String, Map<String, dynamic>> _avaliacoesPorProduto = {};
  Map<String, Map<String, dynamic>> _minhasAvaliacoes = {};
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initDeviceId();
    carregarProdutos();
  }

  void _initDeviceId() {
    _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
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
        
        await _carregarAvaliacoesProduto(p['lote']);
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
  
  Future<void> _carregarAvaliacoesProduto(String produtoId) async {
    try {
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

      final avaliacaoExistente = await supabase
          .from('avaliacoes')
          .select()
          .eq('produto_id', produtoId)
          .eq('device_id', _deviceId!)
          .maybeSingle();

      if (avaliacaoExistente != null) {
        await supabase
            .from('avaliacoes')
            .update({
              'nota': nota,
              'comentario': comentario,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', avaliacaoExistente['id']);
      } else {
        await supabase.from('avaliacoes').insert({
          'produto_id': produtoId,
          'device_id': _deviceId!,
          'nota': nota,
          'comentario': comentario,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      _minhasAvaliacoes[produtoId] = {
        'nota': nota,
        'comentario': comentario,
        'produto_id': produtoId,
        'device_id': _deviceId!,
      };

      await _carregarAvaliacoesProduto(produtoId);
      
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Avaliação enviada com sucesso!'),
          backgroundColor: Colors.green[800],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar avaliação: $e'),
          backgroundColor: Colors.red[700],
        ),
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
              title: Text(
                'Avaliar: $produtoNome',
                style: const TextStyle(color: Color(0xFF1A1A1A)),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Selecione sua nota:',
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF4A4A4A),
                        fontWeight: FontWeight.w600,
                      ),
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
                            color: const Color(0xFFF57C00),
                            size: 40,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: comentarioController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Comentário (opcional)',
                        labelStyle: const TextStyle(color: Color(0xFF6B6B6B)),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1565C0)),
                        ),
                      ),
                      style: const TextStyle(color: Color(0xFF4A4A4A)),
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
                              SnackBar(
                                content: const Text('Avaliação removida!'),
                                backgroundColor: Colors.green[800],
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao remover avaliação: $e'),
                                backgroundColor: Colors.red[700],
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Remover minha avaliação',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Color(0xFF6B6B6B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (notaSelecionada == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Selecione uma nota'),
                          backgroundColor: Colors.orange[700],
                        ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                  ),
                  child: const Text(
                    'Enviar Avaliação',
                    style: TextStyle(color: Colors.white),
                  ),
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
          title: Text(
            'Avaliações: $produtoNome',
            style: const TextStyle(color: Color(0xFF1A1A1A)),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                                color: Color(0xFFF57C00),
                              ),
                            ),
                            Text(
                              'Média',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
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
                                color: Color(0xFF1565C0),
                              ),
                            ),
                            Text(
                              'Avaliações',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                
                Expanded(
                  child: avaliacoes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_border, size: 50, color: Colors.grey[500]),
                              const SizedBox(height: 10),
                              const Text(
                                'Seja o primeiro a avaliar!',
                                style: TextStyle(
                                  color: Color(0xFF6B6B6B),
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
                                    color: isMinhaAvaliacao ? Colors.green[800] : Colors.blue[800],
                                  ),
                                ),
                                title: Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      starIndex < (avaliacao['nota'] ?? 0)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: const Color(0xFFF57C00),
                                      size: 16,
                                    );
                                  }),
                                ),
                                subtitle: avaliacao['comentario'] != null && avaliacao['comentario'].isNotEmpty
                                    ? Text(
                                        avaliacao['comentario'],
                                        style: const TextStyle(color: Color(0xFF4A4A4A)),
                                      )
                                    : Text(
                                        'Sem comentário',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${avaliacao['nota'] ?? 0}/5',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1565C0),
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
                                            color: Color(0xFF2E7D32),
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
                backgroundColor: const Color(0xFFF57C00),
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
              child: const Text(
                'Fechar',
                style: TextStyle(color: Color(0xFF6B6B6B)),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===== FUNÇÕES DE CONTATO SIMPLIFICADAS =====

  Future<void> _abrirWhatsApp(String numero) async {
    try {
      if (numero.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Número de WhatsApp não disponível'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Limpar e formatar o número
      String cleanedNumber = numero.replaceAll(RegExp(r'[^\d]'), '');
      
      // Remover zeros iniciais se houver
      while (cleanedNumber.startsWith('0')) {
        cleanedNumber = cleanedNumber.substring(1);
      }
      
      // Adicionar código do Brasil se não tiver
      if (!cleanedNumber.startsWith('55')) {
        cleanedNumber = '55$cleanedNumber';
      }

      // Formatar URL do WhatsApp
      String url = 'https://wa.me/$cleanedNumber';
      
      print('Tentando abrir WhatsApp: $url');
      
      // Tentar abrir diretamente
      try {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        print('Erro com wa.me, tentando whataspp://: $e');
        // Tentar com protocolo whataspp://
        String alternativeUrl = 'whatsapp://send?phone=$cleanedNumber';
        try {
          await launchUrl(
            Uri.parse(alternativeUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (e2) {
          print('Erro com whataspp://: $e2');
          // Se tudo falhar, mostrar instruções
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Abra o WhatsApp e envie mensagem para: $numero'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('Erro geral ao abrir WhatsApp: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _enviarEmail(String email) async {
    try {
      if (email.isEmpty || !email.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço de e-mail inválido'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Criar URL do e-mail
      final String assunto = 'Contato via App - Interesse em produto';
      final String corpo = 'Olá,\n\nTenho interesse em mais informações sobre o produto anunciado no app.\n\nAtenciosamente,';
      
      final String url = 'mailto:$email?subject=${Uri.encodeComponent(assunto)}&body=${Uri.encodeComponent(corpo)}';
      
      print('Tentando abrir e-mail: $url');
      
      // Tentar abrir diretamente
      try {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        print('Erro ao abrir mailto: $e');
        // Se falhar, abrir o Gmail na web
        final String gmailUrl = 'https://mail.google.com/mail/?view=cm&fs=1&to=$email&su=${Uri.encodeComponent(assunto)}&body=${Uri.encodeComponent(corpo)}';
        try {
          await launchUrl(
            Uri.parse(gmailUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (e2) {
          print('Erro ao abrir Gmail: $e2');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Envie um e-mail para: $email\nAssunto: $assunto'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('Erro geral ao enviar e-mail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===== FIM DAS FUNÇÕES DE CONTATO =====

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
        
        await _carregarAvaliacoesProduto(p['lote']);
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

  @override
  Widget build(BuildContext context) {
    const Color textPrimary = Color(0xFF1A1A1A); 
    const Color textSecondary = Color(0xFF4A4A4A); 
    const Color textTertiary = Color(0xFF6B6B6B); 
    const Color textLight = Color(0xFF8A8A8A); 
    const Color textSuccess = Color(0xFF2E7D32); 
    const Color textError = Color(0xFFC62828); 
    const Color textWarning = Color(0xFFF57C00); 
    const Color textInfo = Color(0xFF1565C0); 
    const Color cardBackground = Color(0xFFFFFCF8);
    const Color borderColor = Color(0xFFE0E0E0);

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
                  hintStyle: const TextStyle(color: textLight),
                  prefixIcon: const Icon(Icons.search, color: textTertiary),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: textInfo, width: 1.5),
                  ),
                ),
                style: const TextStyle(color: textPrimary),
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
                        title: const Text(
                          'Filtrar por preço',
                          style: TextStyle(color: textPrimary),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: minController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Preço mínimo',
                                labelStyle: const TextStyle(color: textTertiary),
                                prefixIcon: const Icon(Icons.attach_money, color: textTertiary),
                                border: OutlineInputBorder(
                                  borderSide: const BorderSide(color: borderColor),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: textInfo),
                                ),
                              ),
                              style: const TextStyle(color: textPrimary),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: maxController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Preço máximo',
                                labelStyle: const TextStyle(color: textTertiary),
                                prefixIcon: const Icon(Icons.attach_money, color: textTertiary),
                                border: OutlineInputBorder(
                                  borderSide: const BorderSide(color: borderColor),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: textInfo),
                                ),
                              ),
                              style: const TextStyle(color: textPrimary),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: textTertiary),
                            ),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: textInfo,
                            ),
                            child: const Text(
                              'Aplicar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: textInfo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Filtrar por preço'),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Expanded(
                    child: Divider(
                      color: textInfo,
                      thickness: 2,
                      endIndent: 10,
                    ),
                  ),
                  const Text(
                    "PRODUTOS",
                    style: TextStyle(
                      color: textInfo,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Expanded(
                    child: Divider(
                      color: textInfo,
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
                        ? Center(
                            child: Text(
                              'Nenhum produto disponível',
                              style: TextStyle(
                                color: textTertiary,
                                fontSize: 16,
                              ),
                            ),
                          )
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
                                          style: const TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                                          child: Center(
                                                            child: Icon(
                                                              Icons.shopping_bag,
                                                              size: 50,
                                                              color: textWarning,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              
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
                                                                      fontWeight: FontWeight.w600,
                                                                      color: textSecondary,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    media.toStringAsFixed(1),
                                                                    style: const TextStyle(
                                                                      fontSize: 18,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: textWarning,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    '/5',
                                                                    style: TextStyle(color: textSecondary),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(height: 4),
                                                              Row(
                                                                children: List.generate(5, (index) {
                                                                  return Icon(
                                                                    index < media.round()
                                                                        ? Icons.star
                                                                        : Icons.star_border,
                                                                    color: textWarning,
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
                                                                  color: textTertiary,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 8),
                                                              ElevatedButton.icon(
                                                                onPressed: () => _mostrarTodasAvaliacoes(produtoId, p['name'] ?? 'Produto'),
                                                                icon: const Icon(Icons.rate_review, size: 16, color: Colors.white),
                                                                label: const Text('Ver todas'),
                                                                style: ElevatedButton.styleFrom(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                  backgroundColor: textInfo,
                                                                  foregroundColor: Colors.white,
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
                                                          backgroundColor: minhaAvaliacao != null ? textSuccess : textWarning,
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
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              
                                              Text(
                                                "Empresa: ${p['empresa_name']}",
                                                style: TextStyle(
                                                  color: textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                "Quantidade: ${p['quantity']}",
                                                style: const TextStyle(color: textSecondary),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                "Descrição: ${p['description'] ?? 'Sem descrição'}",
                                                style: const TextStyle(color: textSecondary),
                                              ),
                                              const SizedBox(height: 5),
                                              if (p['expiration_date'] != null)
                                                Text(
                                                  "Validade: ${p['expiration_date']}",
                                                  style: const TextStyle(color: textSecondary),
                                                ),
                                              const SizedBox(height: 5),
                                              Text(
                                                "Endereço: ${p['empresa_locate']}",
                                                style: const TextStyle(color: textSecondary),
                                              ),
                                              const SizedBox(height: 15),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                children: [
                                                  if (p['empresa_email'] != null && p['empresa_email'].isNotEmpty)
                                                    ElevatedButton.icon(
                                                      onPressed: () =>
                                                          _enviarEmail(
                                                              p['empresa_email']),
                                                      icon: const Icon(
                                                          Icons.email,
                                                          color: Colors.white),
                                                      label: const Text(
                                                        "Email",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            textInfo,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12),
                                                        ),
                                                      ),
                                                    ),
                                                  if (p['empresa_cellphone'] != null && p['empresa_cellphone'].isNotEmpty)
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
                                                        "WhatsApp",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            textSuccess,
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
                                                    color: textSuccess,
                                                    fontSize: 20,
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
    const Color textPrimary = Color(0xFF1A1A1A);
    const Color textSecondary = Color(0xFF4A4A4A);
    const Color textTertiary = Color(0xFF6B6B6B);
    const Color textSuccess = Color(0xFF2E7D32);
    const Color textWarning = Color(0xFFF57C00);
    const Color textInfo = Color(0xFF1565C0);
    const Color cardBackground = Color(0xFFFFFCF8);
    const Color borderColor = Color(0xFFE0E0E0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      color: textInfo,
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
                    child: Center(
                      child: Icon(
                        Icons.shopping_bag,
                        size: 40,
                        color: textWarning,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  empresa,
                  style: const TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                if (description.isNotEmpty)
                  Text(
                    description.length > 50
                        ? '${description.substring(0, 50)}...'
                        : description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                
                const SizedBox(height: 6),
                
                Row(
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < avaliacao.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: textWarning,
                          size: 14,
                        );
                      }),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${avaliacao.toStringAsFixed(1)} ($totalAvaliacoes)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (minhaAvaliacao)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: textSuccess.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 10, color: textSuccess),
                            const SizedBox(width: 2),
                            const Text(
                              'Você avaliou',
                              style: TextStyle(
                                fontSize: 9,
                                color: textSuccess,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'R\$ $price',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textSuccess,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: textInfo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: textInfo.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Ver detalhes',
                        style: TextStyle(
                          fontSize: 11,
                          color: textInfo,
                          fontWeight: FontWeight.w600,
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
