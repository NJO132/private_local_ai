import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:llamadart/llamadart.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<types.Message> _messages = [];
  final _user = const types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ac');
  final _ai = const types.User(id: 'ai-id', firstName: 'Llama');

  LlamaEngine? _engine;
  ChatSession? _session;
  bool _isModelLoading = false;
  bool _isGenerating = false;
  String? _loadedModelName;

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
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
        "Please load a model first using the button in the top right.",
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
          preferredBackend:
              GpuBackend.cpu, // Force CPU-only to avoid Vulkan crash on Android
        ),
      );

      _session = ChatSession(_engine!);

      final fileName = path.split(Platform.pathSeparator).last;

      setState(() {
        _isModelLoading = false;
        _loadedModelName = fileName;
      });
      _addAiMessage(
        "Model successfully loaded!\nModel: $fileName\n\nHow can I help you?",
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
        _addAiMessage("Error: Please select a valid .gguf file.");
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

  Future<void> _generateResponse(String prompt) async {
    if (_session == null) return;

    setState(() {
      _isGenerating = true;
    });

    final aiMessageId = const Uuid().v4();
    String currentText = "";

    // Add empty message we will stream into
    final initialMessage = types.TextMessage(
      author: _ai,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: aiMessageId,
      text: "...",
    );
    _addMessage(initialMessage);

    try {
      final stream = _session!.create([LlamaTextContent(prompt)]);

      await for (final chunk in stream) {
        final content = chunk.choices.first.delta.content ?? '';
        currentText += content;

        setState(() {
          final index = _messages.indexWhere(
            (element) => element.id == aiMessageId,
          );
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
        final index = _messages.indexWhere(
          (element) => element.id == aiMessageId,
        );
        if (index != -1) {
          _messages[index] = types.TextMessage(
            author: _ai,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: aiMessageId,
            text: "$currentText\n\n[Error: $e]",
          );
        }
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Local Offline AI Agent'),
            if (_loadedModelName != null)
              Text(
                '$_loadedModelName',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          _isModelLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.cloud_download),
                      onPressed: _isGenerating ? null : _showDownloadDialog,
                      tooltip: "Download Model from Hugging Face",
                    ),
                    IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: _isGenerating ? null : _pickAndLoadModel,
                      tooltip: "Load Local GGUF File",
                    ),
                  ],
                ),
        ],
      ),
      body: Chat(
        messages: _messages,
        onSendPressed: _handleSendPressed,
        user: _user,
        theme: const DarkChatTheme(),
      ),
    );
  }
}

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
  CancelToken? _cancelToken;

  final List<Map<String, String>> _presets = [
    {
      "name": "Llama 3.2 1B Instruct (Q4_K_M - 812MB)",
      "url":
          "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
    },
    {
      "name": "Llama 3.2 3B Instruct (Q4_K_M - 2.0GB)",
      "url":
          "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf",
    },
    {
      "name": "Phi-3 Mini 4K Instruct (Q4_K_M - 2.4GB)",
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
        _status =
            "Please enter a valid Hugging Face download URL ending in .gguf";
      });
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.last.isEmpty) {
      setState(() {
        _status = "Invalid URL format.";
      });
      return;
    }

    final filename = uri.pathSegments.last;
    if (!filename.endsWith('.gguf')) {
      setState(() {
        _status = "File must be a .gguf format.";
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
      _status = "Starting download...";
      _cancelToken = CancelToken();
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      if (!await modelsDir.exists()) {
        await modelsDir.create();
      }

      final savePath = '${modelsDir.path}/$filename';

      // Check if already exists
      if (await File(savePath).exists()) {
        setState(() {
          _status = "Model already exists locally. Loading...";
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
                  "Downloading: ${(received / 1024 / 1024).toStringAsFixed(1)} MB / ${(total / 1024 / 1024).toStringAsFixed(1)} MB";
            });
          }
        },
      );

      setState(() {
        _status = "Download complete! Loading model...";
        _isDownloading = false;
      });

      widget.onModelDownloaded(savePath);
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        setState(() {
          _status = "Download cancelled.";
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
    return AlertDialog(
      title: const Text('Download Hugging Face Model'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Select a recommended small model:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._presets.map(
                (preset) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    onPressed: _isDownloading
                        ? null
                        : () {
                            _urlController.text = preset["url"]!;
                          },
                    child: Text(preset["name"]!, textAlign: TextAlign.center),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Or enter direct Hugging Face URL (.gguf):",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  hintText: 'https://huggingface.co/.../*.gguf',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isDownloading,
              ),
              const SizedBox(height: 24),
              if (_isDownloading) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
              ],
              Text(
                _status,
                style: TextStyle(
                  color:
                      _status.contains('failed') ||
                          _status.contains('Error') ||
                          _status.contains('Invalid')
                      ? Colors.red
                      : Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_isDownloading)
          TextButton(
            onPressed: () {
              _cancelToken?.cancel();
            },
            child: const Text(
              'Cancel Download',
              style: TextStyle(color: Colors.red),
            ),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ElevatedButton(
          onPressed: _isDownloading ? null : _downloadModel,
          child: const Text('Download & Load'),
        ),
      ],
    );
  }
}
