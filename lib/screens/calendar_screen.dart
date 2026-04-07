import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../main.dart';
import '../models/diary_entry.dart';
import '../services/database_service.dart';
import '../widgets/entry_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, int> _entryCounts = {};
  List<DiaryEntry> _selectedEntries = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadMonth(_focusedDay);
    _loadEntriesForDay(DateTime.now());
  }

  Future<void> _loadMonth(DateTime month) async {
    final counts = await DatabaseService.loadEntryCounts(month);
    setState(() => _entryCounts = counts);
  }

  Future<void> _loadEntriesForDay(DateTime day) async {
    setState(() => _loading = true);
    final entries = await DatabaseService.loadEntriesForDate(day);
    setState(() {
      _selectedEntries = entries;
      _loading = false;
    });
  }

  Future<void> _deleteEntry(DiaryEntry entry) async {
    await DatabaseService.deleteEntry(entry.id);
    _loadEntriesForDay(_selectedDay!);
    _loadMonth(_focusedDay);
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.primary,
        title: const Text(
          'Календарь',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: t.cardShadow.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime(2024, 1, 1),
              lastDay: DateTime(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
                _loadEntriesForDay(selected);
              },
              onPageChanged: (focused) {
                _focusedDay = focused;
                _loadMonth(focused);
              },
              locale: 'ru_RU',
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: t.primary,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                defaultTextStyle: TextStyle(color: t.textPrimary),
                weekendTextStyle: TextStyle(color: t.textHint),
                outsideTextStyle: TextStyle(
                  color: t.textHint.withValues(alpha: 0.4),
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: t.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: t.primary),
                rightChevronIcon: Icon(Icons.chevron_right, color: t.primary),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: t.textHint,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                weekendStyle: TextStyle(
                  color: t.textHint.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  final normalDay = DateTime(day.year, day.month, day.day);
                  final count = _entryCounts[normalDay] ?? 0;
                  if (count == 0) return null;
                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        count.clamp(0, 3),
                        (i) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: t.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Selected day entries
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: t.primary),
                  )
                : _selectedEntries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📝', style: const TextStyle(fontSize: 36)),
                            const SizedBox(height: 8),
                            Text(
                              'Нет записей за этот день',
                              style: TextStyle(color: t.textHint, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _selectedEntries.length,
                        itemBuilder: (context, index) {
                          return EntryCard(
                            entry: _selectedEntries[index],
                            onDelete: () =>
                                _deleteEntry(_selectedEntries[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
