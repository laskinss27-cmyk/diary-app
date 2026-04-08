import 'package:flutter/material.dart';
import '../models/app_theme.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/city_autocomplete.dart';
import '../widgets/disclaimer_dialog.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  final _nameController = TextEditingController();
  String _city = '';
  AvatarData _avatar = AvatarData.defaultAvatar;
  String _selectedThemeId = AppThemes.defaultThemeId;

  // Notification settings
  int _notifHour = 21;
  int _notifMinute = 0;
  bool _notifEnabled = true;

  // User agreement
  bool _agreedToTerms = false;

  // Fade animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  AppThemeData get _theme => AppThemes.getById(_selectedThemeId);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Введите ваше имя'),
          backgroundColor: _theme.accent,
        ),
      );
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Необходимо принять пользовательское соглашение'),
          backgroundColor: _theme.accent,
        ),
      );
      return;
    }
    await StorageService.saveProfile(
      name: _nameController.text.trim(),
      age: '',
      note: '',
      city: _city.trim(),
    );
    await StorageService.saveAvatar(_avatar);
    await StorageService.saveThemeId(_selectedThemeId);
    await StorageService.setOnboarded();

    // Set up notifications
    if (_notifEnabled) {
      await NotificationService.scheduleDaily(_notifHour, _notifMinute);
    }

    widget.onComplete();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notifHour, minute: _notifMinute),
    );
    if (time != null) {
      setState(() {
        _notifHour = time.hour;
        _notifMinute = time.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: _theme.background,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildDots(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _buildWelcomePage(),
                      _buildThemePage(),
                      _buildNotifPage(),
                      _buildReadyPage(),
                    ],
                  ),
                ),
                _buildNav(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: active
                ? _theme.primary
                : _theme.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  // Page 1: Welcome + Name + Avatar
  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Onboarding image
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/onboarding/welcome.png',
              height: 180,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(height: 80),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Добро пожаловать!',
            style: TextStyle(
              color: _theme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ваш личный дневник с AI-анализом настроения',
            textAlign: TextAlign.center,
            style: TextStyle(color: _theme.textHint, fontSize: 15),
          ),
          const SizedBox(height: 24),
          AvatarPicker(
            current: _avatar,
            onChanged: (a) => setState(() => _avatar = a),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: _theme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Ваше имя',
              hintStyle: TextStyle(color: _theme.textHint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: _theme.primary.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: _theme.primary.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _theme.primary, width: 2),
              ),
              filled: true,
              fillColor: _theme.cardColor,
            ),
          ),
          const SizedBox(height: 14),
          CityAutocomplete(
            initialValue: _city,
            theme: _theme,
            onChanged: (v) => _city = v,
          ),
        ],
      ),
    );
  }

  // Page 2: Theme
  Widget _buildThemePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/onboarding/calendar.png',
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(height: 60),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Выберите тему',
            style: TextStyle(
              color: _theme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Можно изменить позже в настройках',
            style: TextStyle(color: _theme.textHint, fontSize: 15),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: AppThemes.all.length,
            itemBuilder: (context, i) {
              final theme = AppThemes.all[i];
              final isSelected = theme.id == _selectedThemeId;
              return GestureDetector(
                onTap: () => setState(() => _selectedThemeId = theme.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? theme.primary : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(theme.emoji,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        theme.name,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Page 3: Notifications
  Widget _buildNotifPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(Icons.notifications_active_rounded,
              color: _theme.primary, size: 80),
          const SizedBox(height: 24),
          Text(
            'Напоминания',
            style: TextStyle(
              color: _theme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Настройте ежедневное напоминание,\nчтобы не забывать записывать свои мысли',
            textAlign: TextAlign.center,
            style: TextStyle(color: _theme.textHint, fontSize: 15),
          ),
          const SizedBox(height: 30),
          // Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _theme.cardShadow.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Включить напоминания',
                    style: TextStyle(
                      color: _theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _notifEnabled,
                  onChanged: (v) => setState(() => _notifEnabled = v),
                  activeColor: _theme.primary,
                ),
              ],
            ),
          ),
          if (_notifEnabled) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: _theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _theme.cardShadow.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Время напоминания',
                      style: TextStyle(
                        color: _theme.textHint,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_notifHour.toString().padLeft(2, '0')}:${_notifMinute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: _theme.primary,
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Нажмите для изменения',
                      style: TextStyle(
                        color: _theme.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Page 4: Ready
  Widget _buildReadyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/onboarding/ready.jpg',
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(height: 80),
            ),
          ),
          const SizedBox(height: 24),
          AvatarWidget(data: _avatar, size: 80),
          const SizedBox(height: 16),
          Text(
            'Привет, ${_nameController.text.trim().isEmpty ? "друг" : _nameController.text.trim()}!',
            style: TextStyle(
              color: _theme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Всё готово! Ваш дневник настроен.',
            style: TextStyle(color: _theme.textHint, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Записывайте мысли, отслеживайте настроение\nи делитесь отчётами со специалистом.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _theme.textHint, fontSize: 14),
          ),
          const SizedBox(height: 20),
          // Feature highlights
          _featureRow(Icons.psychology_rounded, 'AI анализ настроения'),
          _featureRow(Icons.calendar_month_rounded, 'Календарь записей'),
          _featureRow(Icons.photo_library_rounded, 'Фото к записям'),
          _featureRow(Icons.picture_as_pdf_rounded, 'Экспорт в PDF'),
          const SizedBox(height: 24),
          // User agreement
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _agreedToTerms
                    ? _theme.primary
                    : _theme.primary.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: _theme.cardShadow.withValues(alpha: 0.1),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: (v) =>
                            setState(() => _agreedToTerms = v ?? false),
                        activeColor: _theme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _agreedToTerms = !_agreedToTerms),
                        child: Text(
                          'Я принимаю пользовательское соглашение и понимаю, что анализ не является медицинским диагнозом',
                          style: TextStyle(
                            color: _theme.textPrimary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => DisclaimerDialog.showAgreement(context),
                  child: Text(
                    'Прочитать полностью',
                    style: TextStyle(
                      color: _theme.primary,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _theme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: _theme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: _prevPage,
              child: Text(
                'Назад',
                style: TextStyle(color: _theme.textHint, fontSize: 16),
              ),
            )
          else
            const SizedBox(width: 80),
          const Spacer(),
          ElevatedButton(
            onPressed: _currentPage == 3 ? _finish : _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: _theme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              elevation: 2,
            ),
            child: Text(
              _currentPage == 3 ? 'Начать' : 'Далее',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
