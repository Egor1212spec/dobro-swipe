import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/theme.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final dynamic taskData;

  const ReviewScreen({Key? key, required this.taskData}) : super(key: key);

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  void _review(int assignmentId, bool approve) async {
    if (!approve && _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Укажите причину отклонения'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await ref.read(dashboardProvider.notifier).reviewAssignment(
      assignmentId,
      approve,
      _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
    );
    setState(() => _isSubmitting = false);

    if (success && mounted) {
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ошибка'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> assignments = widget.taskData['assignments'] ?? [];
    var underReview = assignments.where((a) => a['status'] == 'under_review').toList();
    var inProgress = assignments.where((a) => a['status'] == 'in_progress').toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Детали задачи'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTaskHeader(),
              const SizedBox(height: 24),
              if (inProgress.isNotEmpty)
                ...inProgress.map((a) => _buildInProgressCard(a)),
              if (underReview.isNotEmpty)
                ...underReview.map((a) => _buildReportCard(a)),
              if (inProgress.isEmpty && underReview.isEmpty)
                _buildNoReports(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.taskData['title'] ?? '',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(widget.taskData['status']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(widget.taskData['status']),
              style: TextStyle(
                color: _statusColor(widget.taskData['status']),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressCard(dynamic assignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Волонтёр работает', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('ID: ${assignment['volunteer_id']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => context.push('/volunteer/chat', extra: {
              'assignmentId': assignment['id'] as int,
              'taskTitle': widget.taskData['title'] ?? '',
            }),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('Чат'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoReports() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Нет отчётов на проверке', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildReportCard(dynamic assignment) {
    final resultText = assignment['result_text'] ?? '';
    final imageUrlMatch = RegExp(r'\[Image: (.*?)\]').firstMatch(resultText);
    String? imageUrl = imageUrlMatch?.group(1);
    String textOnly = resultText.replaceAll(RegExp(r'\n?\[Image: .*?\]'), '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'На проверке',
                  style: TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chat_rounded, color: AppTheme.primaryColor),
                onPressed: () => context.push('/volunteer/chat', extra: {
                  'assignmentId': assignment['id'] as int,
                  'taskTitle': widget.taskData['title'] ?? '',
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (textOnly.isNotEmpty) ...[
            Text('Текст отчёта:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(textOnly, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(height: 16),
          ],
          if (imageUrl != null) ...[
            Text('Фото:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              hintText: 'Комментарий (обязателен при отклонении)',
            ),
          ),
          const SizedBox(height: 20),
          if (_isSubmitting)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _review(assignment['id'], false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentColor,
                      side: const BorderSide(color: AppTheme.accentColor, width: 1.5),
                    ),
                    child: const Text('Отклонить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.successColor, Color(0xFF2ECC71)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _review(assignment['id'], true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: const Text('Одобрить'),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return AppTheme.primaryColor;
      case 'completed':
        return AppTheme.successColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'active':
        return 'Активна';
      case 'completed':
        return 'Завершена';
      case 'archived':
        return 'В архиве';
      default:
        return 'Неизвестно';
    }
  }
}
