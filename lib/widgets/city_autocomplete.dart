import 'package:flutter/material.dart';
import '../data/cities.dart';
import '../models/app_theme.dart';

/// Автокомплит выбора города.
/// - Поле необязательное: можно оставить пустым, можно ввести свой
///   город вручную (мы не ограничиваем ввод списком).
/// - Если пользователь начал печатать и слово совпадает с началом
///   известного города — показываем выпадающий список до 6 подсказок.
/// - При выборе из списка в [onSelected] приходит объект [City].
/// - При ручном вводе без выбора вариант запишется как просто строка
///   (город, но без привязки к региону) — это ок, для будущего фичи
///   "Если плохо" такой город фоллбэкнется на федеральные линии.
///
/// Отображает аккуратное текстовое поле в стиле приложения и
/// выпадающий список, стилизованный под текущую тему.
class CityAutocomplete extends StatefulWidget {
  final String initialValue;
  final AppThemeData theme;
  final ValueChanged<String> onChanged;
  final String label;
  final String hint;

  const CityAutocomplete({
    super.key,
    required this.initialValue,
    required this.theme,
    required this.onChanged,
    this.label = 'Город',
    this.hint = 'Необязательно — поможет подобрать службы помощи',
  });

  @override
  State<CityAutocomplete> createState() => _CityAutocompleteState();
}

class _CityAutocompleteState extends State<CityAutocomplete> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  List<City> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Закрываем с небольшой задержкой, чтобы успел обработаться тап
      // по подсказке, прежде чем она исчезнет.
      Future.delayed(const Duration(milliseconds: 150), _removeOverlay);
    } else if (_suggestions.isNotEmpty) {
      _showOverlay();
    }
  }

  void _onTextChanged(String value) {
    widget.onChanged(value);
    final suggestions = searchCities(value, limit: 6);
    setState(() => _suggestions = suggestions);
    if (suggestions.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _onSelect(City city) {
    _controller.text = city.name;
    _controller.selection = TextSelection.collapsed(offset: city.name.length);
    widget.onChanged(city.name);
    _removeOverlay();
    _focusNode.unfocus();
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: widget.theme.cardColor,
            shadowColor: widget.theme.primary.withValues(alpha: 0.3),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, i) {
                  final c = _suggestions[i];
                  return InkWell(
                    onTap: () => _onSelect(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: widget.theme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: widget.theme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${c.region}${c.country != "RU" ? ", ${_countryName(c.country)}" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.theme.textPrimary
                                        .withValues(alpha: 0.55),
                                  ),
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
          ),
        ),
      ),
    );

    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  String _countryName(String code) {
    switch (code) {
      case 'BY':
        return 'Беларусь';
      case 'KZ':
        return 'Казахстан';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onTextChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontSize: 12,
            color: widget.theme.textPrimary.withValues(alpha: 0.45),
          ),
          prefixIcon: Icon(
            Icons.location_city_outlined,
            color: widget.theme.primary,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                    _removeOverlay();
                    setState(() => _suggestions = const []);
                  },
                )
              : null,
          filled: true,
          fillColor: widget.theme.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: widget.theme.primary.withValues(alpha: 0.25),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: widget.theme.primary.withValues(alpha: 0.25),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: widget.theme.primary,
              width: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}
