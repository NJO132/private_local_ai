import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_design.dart';

class ModelManagerDialog extends StatefulWidget {
  final String? currentModelName;
  final Function(String path) onModelSelected;
  final VoidCallback onDownloadNew;

  const ModelManagerDialog({
    super.key,
    this.currentModelName,
    required this.onModelSelected,
    required this.onDownloadNew,
  });

  @override
  State<ModelManagerDialog> createState() => _ModelManagerDialogState();
}

class _ModelManagerDialogState extends State<ModelManagerDialog> {
  List<FileSystemEntity> _models = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    final models = await StorageService.getDownloadedModels();
    setState(() {
      _models = models;
      _isLoading = false;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(0)} MB';
    } else {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppDesign.surface,
      shape: RoundedRectangleBorder(borderRadius: AppDesign.radiusLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
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
                      gradient: AppDesign.primaryGradient,
                      borderRadius: AppDesign.radiusMd,
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      size: 22,
                      color: AppDesign.background,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Models',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppDesign.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage your local AI models',
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

            // ─── Model List ───
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _models.isEmpty
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: AppComponents.emptyState(
                          icon: Icons.download_rounded,
                          title: 'No models yet',
                          subtitle:
                              'Download an AI model to start\nchatting offline',
                          action: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onDownloadNew();
                            },
                            icon: const Icon(Icons.cloud_download, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Download Model'),
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _models.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final model = _models[index];
                        final name = model.path
                            .split(Platform.pathSeparator)
                            .last;
                        final stat = model.statSync();
                        final size = _formatFileSize(stat.size);
                        final isActive = name == widget.currentModelName;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: AppDesign.radiusMd,
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onModelSelected(model.path);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppDesign.primary.withValues(alpha: 0.08)
                                    : AppDesign.surfaceElevated,
                                borderRadius: AppDesign.radiusMd,
                                border: Border.all(
                                  color: isActive
                                      ? AppDesign.primary.withValues(alpha: 0.3)
                                      : AppDesign.surfaceHighlight,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppDesign.primary.withValues(
                                              alpha: 0.15,
                                            )
                                          : AppDesign.surfaceHighlight,
                                      borderRadius: AppDesign.radiusSm,
                                    ),
                                    child: Icon(
                                      isActive
                                          ? Icons.check_circle_rounded
                                          : Icons.memory_rounded,
                                      color: isActive
                                          ? AppDesign.primary
                                          : AppDesign.textTertiary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.replaceAll('.gguf', ''),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isActive
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: AppDesign.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Text(
                                              size,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppDesign.textTertiary,
                                              ),
                                            ),
                                            if (isActive) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppDesign.primary
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      AppDesign.radiusXl,
                                                ),
                                                child: const Text(
                                                  'ACTIVE',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppDesign.primary,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      size: 20,
                                      color: AppDesign.textTertiary,
                                    ),
                                    onSelected: (value) async {
                                      if (value == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Model'),
                                            content: Text(
                                              'Delete "$name"?\nThis cannot be undone.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppDesign.error,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await StorageService.deleteModel(
                                            model.path,
                                          );
                                          _loadModels();
                                        }
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: AppDesign.error,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: AppDesign.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ─── Footer ───
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDownloadNew();
                  },
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Download New Model'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
