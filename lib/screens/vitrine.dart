import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'theme_manager.dart';

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
        SnackBar(
          content: Text('Erro ao carregar produtos: $e'),
          backgroundColor: Colors.red,
        ),
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

      final themeManager = Provider.of<ThemeManager>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Avaliação enviada com sucesso!'),
          backgroundColor: themeManager.primaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar avaliação: $e'),
          backgroundColor: Colors.red,
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

    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: themeManager.dialogBgColor,
              title: Text(
                'Avaliar: $produtoNome',
                style: TextStyle(color: themeManager.textPrimary),
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
                        color: themeManager.textSecondary,
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
                            color: themeManager.warningColor,
                            size: 40,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: comentarioController,
                      maxLines: 3,
                      style: TextStyle(color: themeManager.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Comentário (opcional)',
                        labelStyle: TextStyle(color: themeManager.textTertiary),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: themeManager.inputBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: themeManager.primaryColor),
                        ),
                        filled: true,
                        fillColor: themeManager.inputBgColor,
                      ),
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
                                backgroundColor: themeManager.primaryColor,
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao remover avaliação: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Remover minha avaliação',
                          style: TextStyle(
                            color: Colors.red,
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
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: themeManager.textTertiary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (notaSelecionada == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Selecione uma nota'),
                          backgroundColor: themeManager.warningColor,
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
                    backgroundColor: themeManager.primaryColor,
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
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: themeManager.dialogBgColor,
          title: Text(
            'Avaliações: $produtoNome',
            style: TextStyle(color: themeManager.textPrimary),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  color: themeManager.cardBgColor,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              _avaliacoesPorProduto[produtoId]?['media']?.toStringAsFixed(1) ?? '0.0',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: themeManager.warningColor,
                              ),
                            ),
                            Text(
                              'Média',
                              style: TextStyle(
                                fontSize: 12,
                                color: themeManager.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${_avaliacoesPorProduto[produtoId]?['total'] ?? 0}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: themeManager.primaryColor,
                              ),
                            ),
                            Text(
                              'Avaliações',
                              style: TextStyle(
                                fontSize: 12,
                                color: themeManager.textTertiary,
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
                              Icon(Icons.star_border, size: 50, color: themeManager.textTertiary),
                              const SizedBox(height: 10),
                              Text(
                                'Seja o primeiro a avaliar!',
                                style: TextStyle(
                                  color: themeManager.textTertiary,
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
                              color: themeManager.cardBgColor,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isMinhaAvaliacao ? Colors.green[100] : themeManager.scaffoldBgColor,
                                  child: Icon(
                                    isMinhaAvaliacao ? Icons.person : Icons.person_outline,
                                    size: 20,
                                    color: isMinhaAvaliacao ? themeManager.successColor : themeManager.primaryColor,
                                  ),
                                ),
                                title: Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      starIndex < (avaliacao['nota'] ?? 0)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: themeManager.warningColor,
                                      size: 16,
                                    );
                                  }),
                                ),
                                subtitle: avaliacao['comentario'] != null && avaliacao['comentario'].isNotEmpty
                                    ? Text(
                                        avaliacao['comentario'],
                                        style: TextStyle(color: themeManager.textSecondary),
                                      )
                                    : Text(
                                        'Sem comentário',
                                        style: TextStyle(color: themeManager.textTertiary),
                                      ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${avaliacao['nota'] ?? 0}/5',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: themeManager.primaryColor,
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
                                        child: Text(
                                          'Você',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: themeManager.successColor,
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
                backgroundColor: themeManager.warningColor,
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
              child: Text(
                'Fechar',
                style: TextStyle(color: themeManager.textTertiary),
              ),
            ),
          ],
        );
      },
    );
  }

  // FUNÇÕES DE CONTATO 

  Future<void> _abrirWhatsApp(String numero) async {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
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
              backgroundColor: themeManager.primaryColor,
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
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
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
              backgroundColor: themeManager.primaryColor,
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

  // FIM DAS FUNÇÕES DE CONTATO

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
    final themeManager = Provider.of<ThemeManager>(context);
    
    return Scaffold(
      backgroundColor: themeManager.scaffoldBgColor,
      appBar: AppBar(
        title: const Text('Vitrine de Produtos'),
        backgroundColor: themeManager.cardBgColor,
        foregroundColor: themeManager.textPrimary,
        elevation: 0,
        actions: [
          // Botão de alternar tema
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
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
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 15),
            TextField(
              controller: _searchController,
              style: TextStyle(color: themeManager.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar Produto',
                hintStyle: TextStyle(color: themeManager.textTertiary),
                prefixIcon: Icon(Icons.search, color: themeManager.textSecondary),
                filled: true,
                fillColor: themeManager.inputBgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: themeManager.inputBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: themeManager.primaryColor, width: 1.5),
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
                      backgroundColor: themeManager.dialogBgColor,
                      title: Text(
                        'Filtrar por preço',
                        style: TextStyle(color: themeManager.textPrimary),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: minController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: themeManager.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Preço mínimo',
                              labelStyle: TextStyle(color: themeManager.textTertiary),
                              prefixIcon: Icon(Icons.attach_money, color: themeManager.textTertiary),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: themeManager.inputBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: themeManager.primaryColor),
                              ),
                              filled: true,
                              fillColor: themeManager.inputBgColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: themeManager.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Preço máximo',
                              labelStyle: TextStyle(color: themeManager.textTertiary),
                              prefixIcon: Icon(Icons.attach_money, color: themeManager.textTertiary),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: themeManager.inputBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: themeManager.primaryColor),
                              ),
                              filled: true,
                              fillColor: themeManager.inputBgColor,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(color: themeManager.textTertiary),
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
                            backgroundColor: themeManager.primaryColor,
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
                backgroundColor: themeManager.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Filtrar por preço'),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: themeManager.primaryColor,
                    thickness: 2,
                    endIndent: 10,
                  ),
                ),
                Text(
                  "PRODUTOS",
                  style: TextStyle(
                    color: themeManager.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: themeManager.primaryColor,
                    thickness: 2,
                    indent: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: loading
                  ? Center(child: CircularProgressIndicator(color: themeManager.primaryColor))
                  : produtos.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhum produto disponível',
                            style: TextStyle(
                              color: themeManager.textTertiary,
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
                                      backgroundColor: themeManager.dialogBgColor,
                                      title: Text(
                                        p['name'] ?? 'Produto',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: themeManager.textPrimary,
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
                                                            color: themeManager.warningColor,
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
                                              color: themeManager.cardBgColor,
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
                                                                    color: themeManager.textSecondary,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  media.toStringAsFixed(1),
                                                                  style: TextStyle(
                                                                    fontSize: 18,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: themeManager.warningColor,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  '/5',
                                                                  style: TextStyle(color: themeManager.textSecondary),
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
                                                                  color: themeManager.warningColor,
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
                                                                color: themeManager.textTertiary,
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
                                                                backgroundColor: themeManager.primaryColor,
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
                                                        backgroundColor: minhaAvaliacao != null ? themeManager.successColor : themeManager.warningColor,
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
                                                color: themeManager.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              "Quantidade: ${p['quantity']}",
                                              style: TextStyle(color: themeManager.textSecondary),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              "Descrição: ${p['description'] ?? 'Sem descrição'}",
                                              style: TextStyle(color: themeManager.textSecondary),
                                            ),
                                            const SizedBox(height: 5),
                                            if (p['expiration_date'] != null)
                                              Text(
                                                "Validade: ${p['expiration_date']}",
                                                style: TextStyle(color: themeManager.textSecondary),
                                              ),
                                            const SizedBox(height: 5),
                                            Text(
                                              "Endereço: ${p['empresa_locate']}",
                                              style: TextStyle(color: themeManager.textSecondary),
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
                                                          themeManager.primaryColor,
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
                                                          themeManager.successColor,
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
                                                style: TextStyle(
                                                  color: themeManager.successColor,
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
                              child: Container(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl,
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
                                          const SizedBox(height: 4),
                                          Text(
                                            p['empresa_name'] ?? "Empresa",
                                            style: TextStyle(
                                              color: themeManager.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            p['description'] ?? "",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: themeManager.textTertiary, fontSize: 12),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Row(
                                                children: List.generate(5, (index) {
                                                  return Icon(
                                                    index < media.round()
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    color: themeManager.warningColor,
                                                    size: 14,
                                                  );
                                                }),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${media.toStringAsFixed(1)} ($totalAvaliacoes)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: themeManager.textTertiary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (_minhasAvaliacoes.containsKey(produtoId))
                                                Container(
                                                  margin: const EdgeInsets.only(left: 6),
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[50],
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: themeManager.successColor.withOpacity(0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.check, size: 10, color: themeManager.successColor),
                                                      const SizedBox(width: 2),
                                                      const Text(
                                                        'Você avaliou',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.green,
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
                                                "R\$ ${p['value']?.toStringAsFixed(2) ?? '0.00'}",
                                                style: TextStyle(
                                                  color: themeManager.successColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: themeManager.primaryColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: themeManager.primaryColor.withOpacity(0.3)),
                                                ),
                                                child: Text(
                                                  'Ver detalhes',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: themeManager.primaryColor,
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
                              ),
                            );
                          },
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