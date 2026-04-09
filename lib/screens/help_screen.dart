import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/helplines.dart';
import '../main.dart';
import '../services/storage_service.dart';
import 'breathing_screen.dart';
import 'grounding_screen.dart';

/// Экран "Если плохо" — кризисные контакты и быстрые техники.
///
/// Принципы:
/// - Никаких нравоучений. Никаких "всё будет хорошо".
/// - Только данные и инструменты. Минимум текста.
/// - Крупные кнопки, большие номера, лёгкая навигация.
/// - Номера берутся из helplines.dart и подбираются по городу
///   из профиля. Если города нет — показываем федеральные России
///   + международный fallback.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _userCity = '';
  List<Helpline> _lines = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await StorageService.loadProfile();
    final city = profile['city'] ?? '';
    final lines = getHelplinesForUserCity(city);
    if (!mounted) return;
    setState(() {
      _userCity = city;
      _lines = lines;
      _loading = false;
    });
  }

  Future<void> _call(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/${cleaned.replaceAll('+', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.primary,
        title: const Text(
          'Если тебе тяжело',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Тёплое короткое вступление
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: t.cardColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: t.cardShadow,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ты не один.',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ниже — люди, готовые выслушать прямо сейчас.\n'
                          'Бесплатно, анонимно, без оценок.',
                          style: TextStyle(
                            fontSize: 14,
                            color: t.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Секция номеров
                  _sectionTitle(
                    t,
                    _userCity.isEmpty
                        ? 'Бесплатные линии'
                        : 'Для тебя: $_userCity',
                  ),
                  const SizedBox(height: 10),
                  ..._lines.map((l) => _helplineCard(t, l)),

                  const SizedBox(height: 24),

                  // Секция техник
                  _sectionTitle(t, 'Если не можешь говорить'),
                  const SizedBox(height: 10),
                  _techniqueCard(
                    t,
                    icon: Icons.air_rounded,
                    title: 'Дыхание 4-7-8',
                    subtitle: 'Снимает острую тревогу за 2 минуты',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BreathingScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _techniqueCard(
                    t,
                    icon: Icons.eco_rounded,
                    title: 'Заземление 5-4-3-2-1',
                    subtitle: 'Вернуться в настоящий момент',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GroundingScreen()),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Дисклеймер
                  Text(
                    'Это не замена помощи специалиста.\n'
                    'Если состояние не улучшается — обратись к врачу.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: t.textHint,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(dynamic t, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: t.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _helplineCard(dynamic t, Helpline h) {
    final isIntl = h.country == 'INTL';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: t.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            h.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          if (!isIntl)
            Text(
              h.phoneFull,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: t.primary,
                letterSpacing: 0.5,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 13, color: t.textHint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${h.hours} • ${h.target}',
                  style: TextStyle(fontSize: 12, color: t.textHint),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (h.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              h.notes,
              style: TextStyle(
                fontSize: 11,
                color: t.textHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isIntl) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _call(h.phone),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Позвонить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                if (h.whatsapp != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openWhatsApp(h.whatsapp!),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.primary,
                        side: BorderSide(color: t.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ] else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(h.sourceUrl),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Открыть каталог'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _techniqueCard(
    dynamic t, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: t.cardShadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: t.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
