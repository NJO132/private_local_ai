import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:llamadart/llamadart.dart';
import 'package:dio/dio.dart';
import 'dart:io';

import 'services/storage_service.dart';
import 'widgets/model_manager_dialog.dart';
import 'widgets/chat_history_drawer.dart';
import 'theme/app_design.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Local AI Agent',
      theme: AppDesign.theme,
      home: const ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  final List<types.Message> _messages = [];
  final _user = const types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ac');
  final _ai = const types.User(id: 'ai-id', firstName: 'AI');
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  LlamaEngine? _engine;
  ChatSession? _session;
  bool _isModelLoading = false;
  bool _isGenerating = false;
  String? _loadedModelName;
  String? _currentChatId;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initApp();
  }

  Future<void> _initApp() async {
    final chatId = await StorageService.getCurrentChatId();
    if (chatId != null) {
      await _loadChat(chatId);
    } else {
      await _startNewChat();
    }

    final lastModelPath = await StorageService.getLastModelPath();
    if (lastModelPath != null && await File(lastModelPath).exists()) {
      await _loadModelFromPath(lastModelPath);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _engine?.dispose();
    super.dispose();
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
    _autoSave();
  }

  void _autoSave() {
    if (_currentChatId != null) {
      StorageService.saveMessages(_currentChatId!, _messages);
    }
  }

  Future<void> _startNewChat() async {
    final chatId = await StorageService.createNewChat(
      modelName: _loadedModelName,
    );
    setState(() {
      _currentChatId = chatId;
      _messages.clear();
    });
  }

  Future<void> _loadChat(String chatId) async {
    final messages = await StorageService.loadMessages(chatId);
    await StorageService.setCurrentChatId(chatId);
    setState(() {
      _currentChatId = chatId;
      _messages.clear();
      _messages.addAll(messages);
    });
  }

  void _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );

    _addMessage(textMessage);

    if (_engine == null || _session == null) {
      _addAiMessage(
        "No model loaded. Tap the ✦ button to select or download a model.",
      );
      return;
    }

    _generateResponse(message.text);
  }

  void _addAiMessage(String text) {
    final message = types.TextMessage(
      author: _ai,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: text,
    );
    _addMessage(message);
  }

  Future<void> _loadModelFromPath(String path) async {
    setState(() {
      _isModelLoading = true;
    });

    try {
      if (_engine != null) {
        await _engine!.dispose();
      }

      _engine = LlamaEngine(LlamaBackend());
      await _engine!.loadModel(
        path,
        modelParams: const ModelParams(
          contextSize: 2048,
          gpuLayers: 0,
          preferredBackend: GpuBackend.cpu,
        ),
      );

      _session = ChatSession(_engine!);
      final fileName = path.split(Platform.pathSeparator).last;
      await StorageService.setLastModelPath(path);

      setState(() {
        _isModelLoading = false;
        _loadedModelName = fileName;
      });
      _addAiMessage(
        "Model loaded: ${fileName.replaceAll('.gguf', '')}\n\nI'm ready to help. What would you like to discuss?",
      );
    } catch (e) {
      setState(() {
        _isModelLoading = false;
      });
      _addAiMessage("Failed to load model: $e");
    }
  }

  Future<void> _pickAndLoadModel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      if (!path.endsWith('.gguf')) {
        _addAiMessage("Please select a valid .gguf model file.");
        return;
      }
      await _loadModelFromPath(path);
    }
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadModelDialog(
        onModelDownloaded: (path) {
          Navigator.of(context).pop();
          _loadModelFromPath(path);
        },
      ),
    );
  }

  void _showModelManager() {
    showDialog(
      context: context,
      builder: (context) => ModelManagerDialog(
        currentModelName: _loadedModelName,
        onModelSelected: (path) => _loadModelFromPath(path),
        onDownloadNew: _showDownloadDialog,
      ),
    );
  }

  Future<void> _generateResponse(String prompt) async {
    if (_session == null) return;

    setState(() {
      _isGenerating = true;
    });

    final aiMessageId = const Uuid().v4();
    String currentText = "";

    final initialMessage = types.TextMessage(
      author: _ai,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: aiMessageId,
      text: "•••",
    );
    _addMessage(initialMessage);

    try {
      final stream = _session!.create([LlamaTextContent(prompt)]);

      await for (final chunk in stream) {
        final content = chunk.choices.first.delta.content ?? '';
        currentText += content;

        setState(() {
          final index = _messages.indexWhere((e) => e.id == aiMessageId);
          if (index != -1) {
            _messages[index] = types.TextMessage(
              author: _ai,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: aiMessageId,
              text: currentText,
            );
          }
        });
      }
    } catch (e) {
      setState(() {
        final index = _messages.indexWhere((e) => e.id == aiMessageId);
        if (index != -1) {
          _messages[index] = types.TextMessage(
            author: _ai,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: aiMessageId,
            text: "$currentText\n\n⚠️ Error: $e",
          );
        }
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
      _autoSave();
    }
  }

  // ─── Custom Chat Theme ───
  DarkChatTheme get _chatTheme => const DarkChatTheme(
    backgroundColor: AppDesign.background,
    primaryColor: AppDesign.primary,
    secondaryColor: AppDesign.surfaceElevated,
    inputBackgroundColor: AppDesign.surfaceElevated,
    inputTextColor: AppDesign.textPrimary,
    inputBorderRadius: BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
    ),
    inputMargin: EdgeInsets.zero,
    inputPadding: EdgeInsets.fromLTRB(8, 12, 8, 12),
    inputElevation: 2,
    inputContainerDecoration: BoxDecoration(
      color: AppDesign.surfaceElevated,
      border: Border(top: BorderSide(color: Color(0xFF242D3D), width: 1)),
    ),
    inputTextDecoration: InputDecoration(
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      isCollapsed: false,
      isDense: false,
      hintText: 'Message',
    ),
    inputTextStyle: TextStyle(fontSize: 16, height: 1.5),
    sentMessageBodyTextStyle: TextStyle(
      color: AppDesign.background,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    receivedMessageBodyTextStyle: TextStyle(
      color: AppDesign.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    messageBorderRadius: 18,
    messageInsetsVertical: 12,
    messageInsetsHorizontal: 16,
  );

  // ─── Welcome Screen ───
  Widget _buildWelcomeView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppDesign.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppDesign.primary.withValues(alpha: 0.3),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 40,
                color: AppDesign.background,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Private Local AI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppDesign.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '100% offline · Your device · Your data',
              style: TextStyle(
                fontSize: 14,
                color: AppDesign.textTertiary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 40),

            // Quick action cards
            _buildActionCard(
              icon: Icons.cloud_download_outlined,
              title: 'Download a Model',
              subtitle: 'Get a pre-trained AI from Hugging Face',
              onTap: _showDownloadDialog,
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.folder_open_outlined,
              title: 'Load from Storage',
              subtitle: 'Import a .gguf file from your device',
              onTap: _pickAndLoadModel,
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.psychology_outlined,
              title: 'My Models',
              subtitle: 'Manage previously downloaded models',
              onTap: _showModelManager,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppDesign.radiusMd,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppDesign.surfaceElevated,
            borderRadius: AppDesign.radiusMd,
            border: Border.all(color: AppDesign.surfaceHighlight, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppDesign.primary.withValues(alpha: 0.1),
                  borderRadius: AppDesign.radiusSm,
                ),
                child: Icon(icon, size: 22, color: AppDesign.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesign.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppDesign.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppDesign.background,
      drawer: ChatHistoryDrawer(
        currentChatId: _currentChatId,
        onChatSelected: (chatId) => _loadChat(chatId),
        onNewChat: () => _startNewChat(),
      ),
      appBar: AppBar(
        backgroundColor: AppDesign.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppDesign.textSecondary),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Chat History',
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppDesign.primaryGradient,
                borderRadius: AppDesign.radiusSm,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppDesign.background,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Local AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppDesign.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (_loadedModelName != null)
                    Text(
                      _loadedModelName!.replaceAll('.gguf', ''),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppDesign.textTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    const Text(
                      'No model loaded',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppDesign.textTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isModelLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppDesign.primary,
                ),
              ),
            )
          else if (_isGenerating)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.4 + (_pulseController.value * 0.6),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: AppDesign.primary,
                    ),
                  );
                },
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.psychology_rounded, size: 22),
              onPressed: _showModelManager,
              tooltip: 'My Models',
              color: AppDesign.textSecondary,
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 24),
              onPressed: _startNewChat,
              tooltip: 'New Chat',
              color: AppDesign.textSecondary,
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppDesign.surfaceHighlight.withValues(alpha: 0.5),
          ),
        ),
      ),
      body: _messages.isEmpty && _loadedModelName == null
          ? _buildWelcomeView()
          : Chat(
              messages: _messages,
              onSendPressed: _handleSendPressed,
              user: _user,
              theme: _chatTheme,
              emptyState: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 48,
                      color: AppDesign.textTertiary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Send a message to begin',
                      style: TextStyle(
                        color: AppDesign.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Download Dialog ───

class DownloadModelDialog extends StatefulWidget {
  final Function(String) onModelDownloaded;
  const DownloadModelDialog({super.key, required this.onModelDownloaded});

  @override
  State<DownloadModelDialog> createState() => _DownloadModelDialogState();
}

class _DownloadModelDialogState extends State<DownloadModelDialog> {
  final _urlController = TextEditingController();
  bool _isDownloading = false;
  double _progress = 0;
  String _status = "";
  String? _selectedPreset;
  CancelToken? _cancelToken;

  final List<Map<String, String>> _presets = [
    {
      "name": "Qwen 2.5 1.5B Instruct",
      "size": "1.12 GB",
      "desc": "Highly capable compact model",
      "url":
          "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
    },
    {
      "name": "Gemma 2 2B Instruct",
      "size": "1.71 GB",
      "desc": "Google's powerful 2B model",
      "url":
          "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf",
    },
    {
      "name": "Phi-3 Mini 4K Instruct",
      "size": "2.4 GB",
      "desc": "Microsoft's compact powerhouse",
      "url":
          "https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf",
    },
  ];

  @override
  void dispose() {
    _urlController.dispose();
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _downloadModel() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('https://huggingface.co/')) {
      setState(() {
        _status = "Enter a valid Hugging Face .gguf URL";
      });
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.last.isEmpty) {
      setState(() {
        _status = "Invalid URL.";
      });
      return;
    }

    final filename = uri.pathSegments.last;
    if (!filename.endsWith('.gguf')) {
      setState(() {
        _status = "Must be a .gguf file.";
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
      _status = "Connecting...";
      _cancelToken = CancelToken();
    });

    try {
      final modelsDir = await StorageService.getModelsDir();
      final savePath = '${modelsDir.path}/$filename';

      if (await File(savePath).exists()) {
        setState(() {
          _status = "Already downloaded! Loading...";
          _isDownloading = false;
        });
        widget.onModelDownloaded(savePath);
        return;
      }

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _status =
                  "${(received / 1024 / 1024).toStringAsFixed(0)} / ${(total / 1024 / 1024).toStringAsFixed(0)} MB";
            });
          }
        },
      );

      setState(() {
        _status = "Complete! Loading model...";
        _isDownloading = false;
      });
      widget.onModelDownloaded(savePath);
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        setState(() {
          _status = "Cancelled.";
          _isDownloading = false;
        });
      } else {
        setState(() {
          _status = "Download failed: $e";
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppDesign.surface,
      shape: RoundedRectangleBorder(borderRadius: AppDesign.radiusLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header ───
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppDesign.accent.withValues(alpha: 0.15),
                      borderRadius: AppDesign.radiusMd,
                    ),
                    child: const Icon(
                      Icons.cloud_download_outlined,
                      size: 22,
                      color: AppDesign.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download Model',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppDesign.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'From Hugging Face',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppDesign.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppDesign.textTertiary,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ─── Content ───
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Presets
                    AppComponents.sectionLabel('Recommended Models'),
                    ..._presets.map((preset) {
                      final isSelected = _selectedPreset == preset["url"];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: AppDesign.radiusMd,
                            onTap: _isDownloading
                                ? null
                                : () {
                                    setState(() {
                                      _selectedPreset = preset["url"];
                                      _urlController.text = preset["url"]!;
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppDesign.accent.withValues(alpha: 0.08)
                                    : AppDesign.surfaceElevated,
                                borderRadius: AppDesign.radiusMd,
                                border: Border.all(
                                  color: isSelected
                                      ? AppDesign.accent.withValues(alpha: 0.3)
                                      : AppDesign.surfaceHighlight,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: isSelected
                                        ? AppDesign.accent
                                        : AppDesign.textTertiary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          preset["name"]!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppDesign.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          preset["desc"]!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppDesign.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppDesign.surfaceHighlight,
                                      borderRadius: AppDesign.radiusXl,
                                    ),
                                    child: Text(
                                      preset["size"]!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppDesign.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Custom URL
                    const SizedBox(height: 8),
                    AppComponents.sectionLabel('Or Custom URL'),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        hintText: 'https://huggingface.co/.../model.gguf',
                        prefixIcon: Icon(Icons.link, size: 20),
                      ),
                      enabled: !_isDownloading,
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) {
                        if (_selectedPreset != v) {
                          setState(() {
                            _selectedPreset = null;
                          });
                        }
                      },
                    ),

                    // Progress
                    if (_isDownloading) ...[
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: AppDesign.radiusXl,
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppDesign.primary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],

                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _status,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _status.contains('failed') ||
                                  _status.contains('Invalid')
                              ? AppDesign.error
                              : AppDesign.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ─── Footer ───
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_isDownloading)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _cancelToken?.cancel(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppDesign.error),
                          foregroundColor: AppDesign.error,
                        ),
                        child: const Text('Cancel'),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _downloadModel,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
