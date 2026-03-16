import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../theme/app_design.dart';

class ChatHistoryDrawer extends StatefulWidget {
  final String? currentChatId;
  final Function(String chatId) onChatSelected;
  final VoidCallback onNewChat;

  const ChatHistoryDrawer({
    super.key,
    this.currentChatId,
    required this.onChatSelected,
    required this.onNewChat,
  });

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  List<ChatSessionMeta> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await StorageService.getChatSessions();
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppDesign.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppDesign.primaryGradient,
                      borderRadius: AppDesign.radiusMd,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: AppDesign.background,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conversations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppDesign.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your chat history',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppDesign.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AppDesign.radiusMd,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onNewChat();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppDesign.primary.withValues(alpha: 0.1),
                          borderRadius: AppDesign.radiusMd,
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: AppDesign.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // ─── Chat List ───
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _sessions.isEmpty
                  ? AppComponents.emptyState(
                      icon: Icons.forum_outlined,
                      title: 'No conversations yet',
                      subtitle: 'Start a new chat to begin',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final isActive = session.id == widget.currentChatId;
                        final dateStr = DateFormat(
                          'MMM d, HH:mm',
                        ).format(session.createdAt);

                        return Dismissible(
                          key: Key(session.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesign.error.withValues(alpha: 0.15),
                              borderRadius: AppDesign.radiusMd,
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: AppDesign.error,
                            ),
                          ),
                          onDismissed: (_) async {
                            await StorageService.deleteChat(session.id);
                            _loadSessions();
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppDesign.primary.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: AppDesign.radiusMd,
                              border: isActive
                                  ? Border.all(
                                      color: AppDesign.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                    )
                                  : null,
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: AppDesign.radiusMd,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
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
                                      ? Icons.chat_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  color: isActive
                                      ? AppDesign.primary
                                      : AppDesign.textTertiary,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                session.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isActive
                                      ? AppDesign.textPrimary
                                      : AppDesign.textSecondary,
                                ),
                              ),
                              subtitle: Text(
                                '${session.modelName ?? 'No model'} · $dateStr',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppDesign.textTertiary,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onChatSelected(session.id);
                              },
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
}
