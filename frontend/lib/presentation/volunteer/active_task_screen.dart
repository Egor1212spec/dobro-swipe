import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../data/models.dart';
import '../../core/network.dart';
import '../../core/theme.dart';

class ActiveTaskScreen extends ConsumerStatefulWidget {
  final Task task;
  final int? initialAssignmentId;

  const ActiveTaskScreen({Key? key, required this.task, this.initialAssignmentId}) : super(key: key);

  @override
  ConsumerState<ActiveTaskScreen> createState() => _ActiveTaskScreenState();
}

class _ActiveTaskScreenState extends ConsumerState<ActiveTaskScreen> {
  final _commentController = TextEditingController();
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  XFile? _pickedFile;
  bool _isAccepting = false;
  bool _isSubmitting = false;
  int? _assignmentId;
  List<dynamic> _messages = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialAssignmentId != null) {
      _assignmentId = widget.initialAssignmentId;
      Future.microtask(_startChatPolling);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _commentController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _acceptTask() async {
    setState(() => _isAccepting = true);
    try {
      final response = await apiClient.dio.post('/tasks/${widget.task.id}/swipe_right');
      final assignmentId = response.data['id'] as int;
      setState(() {
        _assignmentId = assignmentId;
        _isAccepting = false;
      });
      _startChatPolling();
    } on DioException catch (e) {
      setState(() => _isAccepting = false);
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? 'Не удалось взять задачу';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.toString()),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _startChatPolling() {
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages());
  }

  Future<void> _loadMessages() async {
    if (_assignmentId == null) return;
    try {
      final response = await apiClient.dio.get('/chat/$_assignmentId');
      if (mounted) setState(() => _messages = response.data as List);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _assignmentId == null) return;
    _chatController.clear();
    try {
      final response = await apiClient.dio.post('/chat/$_assignmentId', data: {'text': text});
      if (mounted) {
        setState(() => _messages.add(response.data));
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _pickedFile = file);
  }

  Future<void> _submitReport() async {
    if (_commentController.text.trim().isEmpty && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Добавьте текст или фото'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final formData = FormData.fromMap({'result_text': _commentController.text.trim()});
      if (_pickedFile != null) {
        final bytes = await _pickedFile!.readAsBytes();
        formData.files.add(MapEntry('image', MultipartFile.fromBytes(bytes, filename: _pickedFile!.name)));
      }
      await apiClient.dio.post('/tasks/assignments/$_assignmentId/submit', data: formData);
      if (mounted) _showSuccessDialog();
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? 'Ошибка отправки';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.check_circle_rounded, size: 40, color: AppTheme.successColor),
              ),
              const SizedBox(height: 20),
              Text('Отчёт отправлен!', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Фонд проверит и начислит карму', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.of(ctx).pop(); context.go('/volunteer'); },
                  child: const Text('К ленте'),
                ),
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(_assignmentId == null ? 'Задача' : 'В работе'),
      ),
      body: SafeArea(
        child: _assignmentId == null ? _buildPreview() : _buildWorkView(),
      ),
    );
  }

  // ─── PREVIEW (before accepting) ───────────────────────────────────────

  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTaskCard(),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: ElevatedButton.icon(
              onPressed: _isAccepting ? null : _acceptTask,
              icon: _isAccepting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.rocket_launch_rounded),
              label: Text(_isAccepting ? 'Берём...' : 'Взять в работу'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  // ─── WORK VIEW (after accepting) ──────────────────────────────────────

  Widget _buildWorkView() {
    return Column(
      children: [
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primaryColor,
                  tabs: [
                    Tab(text: 'Чат с фондом'),
                    Tab(text: 'Сдать отчёт'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildChatTab(),
                      _buildReportTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── CHAT TAB ─────────────────────────────────────────────────────────

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('Напишите фонду', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[i];
                    final isMine = msg['is_mine'] == true;
                    return _buildBubble(msg, isMine);
                  },
                ),
        ),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildBubble(dynamic msg, bool isMine) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(msg['sender_name'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
              ),
            Text(msg['text'] ?? '', style: TextStyle(color: isMine ? Colors.white : AppTheme.textPrimary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: 'Сообщение...',
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── REPORT TAB ───────────────────────────────────────────────────────

  Widget _buildReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTaskCard(),
          const SizedBox(height: 20),
          Text('Отчёт о выполнении', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Опишите что было сделано...'),
          ),
          const SizedBox(height: 14),
          _buildImagePicker(),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Отправить на проверку'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────────────────

  Widget _buildTaskCard() {
    final hasImage = widget.task.imageUrl != null && widget.task.imageUrl!.isNotEmpty;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: widget.task.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.surfaceLight),
                errorWidget: (_, __, ___) => Container(color: AppTheme.surfaceLight),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
                      child: Icon(widget.task.isPhysical ? Icons.place : Icons.laptop_mac, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(widget.task.title, style: Theme.of(context).textTheme.titleLarge)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(widget.task.description, style: Theme.of(context).textTheme.bodyMedium),
                if (widget.task.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: widget.task.tags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#$t',
                        style: const TextStyle(fontSize: 12, color: AppTheme.accentColor, fontWeight: FontWeight.w600),
                      ),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip(Icons.timer_outlined, '${widget.task.durationMinutes} мин'),
                    _chip(Icons.star_rounded, '+${widget.task.karmaReward} кармы'),
                    if (widget.task.city != null) _chip(Icons.location_on_outlined, widget.task.city!),
                    ...widget.task.skillsRequired.map((tag) => _skillChip(tag)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _skillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryDark.withOpacity(0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: AppTheme.primaryDark, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildImagePicker() {
    if (_pickedFile != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.image_rounded, color: AppTheme.successColor),
            const SizedBox(width: 10),
            Expanded(child: Text(_pickedFile!.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
            IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => setState(() => _pickedFile = null)),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: const Text('Прикрепить фото'),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
    );
  }
}
