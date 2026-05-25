import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/theme.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

const _kAllSkills = [
  'Дизайн', 'Программирование', 'Копирайтинг', 'Фотография',
  'Видеосъёмка', 'Перевод', 'Обучение', 'Соцсети',
  'Организация', 'Помощь людям', 'Работа с детьми', 'Экология',
  'Медицина', 'Юридическая помощь', 'Бухгалтерия',
];

const _kSuggestedTags = [
  'Дети', 'Пожилые', 'Животные', 'Экология', 'Образование',
  'Здоровье', 'Культура', 'Спорт', 'Срочно', 'Долгосрочно',
];

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _karmaController = TextEditingController(text: '50');
  final _cityController = TextEditingController(text: 'Сириус');
  final _tagInputController = TextEditingController();
  bool _isPhysical = true;
  bool _isSubmitting = false;
  final Set<String> _selectedSkills = {};
  final Set<String> _selectedTags = {};
  XFile? _pickedImage;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    _karmaController.dispose();
    _cityController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 80);
    if (file != null) setState(() => _pickedImage = file);
  }

  void _addCustomTag() {
    final text = _tagInputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _selectedTags.add(text);
      _tagInputController.clear();
    });
  }

  void _submit() async {
    if (_titleController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Заполните заголовок и описание'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final formMap = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'duration_minutes': int.tryParse(_durationController.text) ?? 30,
      'karma_reward': int.tryParse(_karmaController.text) ?? 50,
      'city': _cityController.text.trim(),
      'is_physical': _isPhysical,
      'skills_required': _selectedSkills.join(','),
      'tags': _selectedTags.join(','),
    };
    final formData = FormData.fromMap(formMap);
    if (_pickedImage != null) {
      final bytes = await _pickedImage!.readAsBytes();
      formData.files.add(MapEntry(
        'image',
        MultipartFile.fromBytes(bytes, filename: _pickedImage!.name),
      ));
    }

    final success = await ref.read(dashboardProvider.notifier).createTask(formData);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ошибка создания задачи'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Новая задача'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImagePicker(),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Заголовок задачи',
                  prefixIcon: Icon(Icons.title_rounded, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Подробное описание задачи...',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Минуты',
                        prefixIcon: Icon(Icons.timer_outlined, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _karmaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Карма',
                        prefixIcon: Icon(Icons.star_outline_rounded, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  hintText: 'Город',
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Теги для волонтёров'),
              const SizedBox(height: 8),
              Text(
                'Выберите из подсказок или добавьте свои',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kSuggestedTags.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () => setState(() {
                      selected ? _selectedTags.remove(tag) : _selectedTags.add(tag);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.accentColor : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? AppTheme.accentColor : const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagInputController,
                      decoration: const InputDecoration(
                        hintText: 'Свой тег',
                        prefixIcon: Icon(Icons.tag_rounded, color: AppTheme.textSecondary),
                      ),
                      onSubmitted: (_) => _addCustomTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addCustomTag,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  ),
                ],
              ),
              if (_selectedTags.where((t) => !_kSuggestedTags.contains(t)).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedTags
                      .where((t) => !_kSuggestedTags.contains(t))
                      .map((tag) => Chip(
                            label: Text('#$tag'),
                            onDeleted: () => setState(() => _selectedTags.remove(tag)),
                            backgroundColor: AppTheme.accentColor.withOpacity(0.12),
                            labelStyle: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.w600),
                            deleteIconColor: AppTheme.accentColor,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 20),
              _sectionLabel('Нужные навыки'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kAllSkills.map((tag) {
                  final selected = _selectedSkills.contains(tag);
                  return GestureDetector(
                    onTap: () => setState(() {
                      selected ? _selectedSkills.remove(tag) : _selectedSkills.add(tag);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _typeTab(true, 'Очная', Icons.place_outlined)),
                    Expanded(child: _typeTab(false, 'Онлайн', Icons.laptop_mac_outlined)),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Опубликовать'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildImagePicker() {
    final picked = _pickedImage;
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: picked != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<Uint8List>(
                    future: picked.readAsBytes(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Image.memory(snapshot.data!, fit: BoxFit.cover);
                    },
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GestureDetector(
                        onTap: () => setState(() => _pickedImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Добавить картинку',
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _typeTab(bool value, String label, IconData icon) {
    final isSelected = _isPhysical == value;
    return GestureDetector(
      onTap: () => setState(() => _isPhysical = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

