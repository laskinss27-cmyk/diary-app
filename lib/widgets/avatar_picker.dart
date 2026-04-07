import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AvatarData {
  final String type; // 'preset' or 'photo'
  final String value; // emoji for preset, base64 for photo
  final Color backgroundColor;

  const AvatarData({
    required this.type,
    required this.value,
    this.backgroundColor = const Color(0xFFE8A0BF),
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'backgroundColor': backgroundColor.toHex(),
      };

  factory AvatarData.fromJson(Map<String, dynamic> json) => AvatarData(
        type: json['type'] as String,
        value: json['value'] as String,
        backgroundColor: _hexToColor(json['backgroundColor'] as String),
      );

  static Color _hexToColor(String hex) =>
      Color(int.parse(hex.replaceFirst('#', '0xFF')));

  static const defaultAvatar = AvatarData(
    type: 'preset',
    value: '🌸',
    backgroundColor: Color(0xFFE8A0BF),
  );
}

extension ColorHex on Color {
  String toHex() =>
      '#${(toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

class AvatarPicker extends StatefulWidget {
  final AvatarData current;
  final ValueChanged<AvatarData> onChanged;

  const AvatarPicker({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  static const _presets = [
    '🌸', '🌺', '🌻', '🌷', '🌹', '💐',
    '🦋', '🐱', '🐰', '🦊', '🐻', '🐼',
    '🌙', '⭐', '🌈', '☀️', '❄️', '🔥',
    '💎', '🎀', '🎭', '🎨', '🎵', '💝',
  ];

  static const _bgColors = [
    Color(0xFFE8A0BF), Color(0xFF9B8EC1), Color(0xFF7EC8A8),
    Color(0xFFE8956A), Color(0xFF6BA3BE), Color(0xFFD4728C),
    Color(0xFF5C6BC0), Color(0xFFD4A574), Color(0xFFEF5350),
    Color(0xFF66BB6A), Color(0xFFFFCA28), Color(0xFF78909C),
  ];

  late String _selectedEmoji;
  late Color _selectedColor;
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    _selectedEmoji = widget.current.type == 'preset' ? widget.current.value : '🌸';
    _selectedColor = widget.current.backgroundColor;
    if (widget.current.type == 'photo') {
      try {
        _photoBytes = base64Decode(widget.current.value);
      } catch (_) {}
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() => _photoBytes = bytes);

      widget.onChanged(AvatarData(
        type: 'photo',
        value: base64Encode(bytes),
        backgroundColor: _selectedColor,
      ));
    } catch (_) {}
  }

  void _selectPreset(String emoji) {
    setState(() {
      _selectedEmoji = emoji;
      _photoBytes = null;
    });
    widget.onChanged(AvatarData(
      type: 'preset',
      value: emoji,
      backgroundColor: _selectedColor,
    ));
  }

  void _selectColor(Color color) {
    setState(() => _selectedColor = color);
    if (_photoBytes != null) {
      widget.onChanged(AvatarData(
        type: 'photo',
        value: base64Encode(_photoBytes!),
        backgroundColor: color,
      ));
    } else {
      widget.onChanged(AvatarData(
        type: 'preset',
        value: _selectedEmoji,
        backgroundColor: color,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Превью аватара
        _buildPreview(),
        const SizedBox(height: 20),
        // Кнопка загрузить фото
        OutlinedButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.camera_alt, size: 18),
          label: const Text('Загрузить фото'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB56576),
            side: BorderSide(color: _selectedColor),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
        const SizedBox(height: 16),
        // Или выбрать аватар
        Text(
          'или выбери аватар',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
        const SizedBox(height: 12),
        // Сетка аватаров
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _presets.length,
          itemBuilder: (context, i) {
            final emoji = _presets[i];
            final isSelected = _photoBytes == null && _selectedEmoji == emoji;
            return GestureDetector(
              onTap: () => _selectPreset(emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _selectedColor.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: _selectedColor, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Цвет фона
        Text(
          'Цвет аватара',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _bgColors.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () => _selectColor(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: _selectedColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: _photoBytes != null
          ? ClipOval(
              child: Image.memory(
                _photoBytes!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            )
          : Center(
              child: Text(
                _selectedEmoji,
                style: const TextStyle(fontSize: 48),
              ),
            ),
    );
  }
}

class AvatarWidget extends StatelessWidget {
  final AvatarData data;
  final double size;

  const AvatarWidget({super.key, required this.data, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: data.backgroundColor,
        shape: BoxShape.circle,
      ),
      child: data.type == 'photo'
          ? ClipOval(
              child: Image.memory(
                base64Decode(data.value),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text('🌸', style: TextStyle(fontSize: size * 0.5)),
                ),
              ),
            )
          : Center(
              child: Text(
                data.value,
                style: TextStyle(fontSize: size * 0.5),
              ),
            ),
    );
  }
}
