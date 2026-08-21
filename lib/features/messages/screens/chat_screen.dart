import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../models/message.dart';
import '../messages_repository.dart';

/// Per-job chat thread, reachable from a job's contact card once a bid
/// is accepted. [viewerId] (not a full Profile) is enough here -- all
/// this screen needs is which side of each bubble to draw on.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.jobId, required this.viewerId});

  final String jobId;
  final String viewerId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repository = MessagesRepository();
  final _bodyController = TextEditingController();
  final _scrollController = ScrollController();
  late final Stream<List<Message>> _messagesStream =
      _repository.streamMessagesForJob(widget.jobId);
  bool _isSending = false;

  @override
  void dispose() {
    _bodyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await _repository.sendMessage(jobId: widget.jobId, body: body);
      _bodyController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const TopBar(eyebrow: 'THIS JOB', title: 'Messages'),
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: 'Could not load messages: ${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const LoadingView();
                  }
                  final messages = snapshot.data!;
                  if (messages.isEmpty) {
                    return const EmptyView(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No messages yet',
                      message: 'Say hello -- questions about the job go here.',
                    );
                  }
                  _scrollToBottom();
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _MessageBubble(
                        message: message,
                        isMine: message.senderId == widget.viewerId,
                      );
                    },
                  );
                },
              ),
            ),
            _Composer(
              controller: _bodyController,
              isSending: _isSending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : AppColors.card,
                    border: isMine ? null : Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.body,
                    style: AppText.body.copyWith(
                      fontSize: 13,
                      color: isMine ? AppColors.primaryForeground : AppColors.foreground,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatRelative(message.createdAt),
                  style: AppText.bodyMuted.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.body.copyWith(fontSize: 13),
              decoration: const InputDecoration(hintText: 'Type a message...'),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isSending ? null : onSend,
              child: SizedBox(
                width: 46,
                height: 46,
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryForeground,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        size: 19,
                        color: AppColors.primaryForeground,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
