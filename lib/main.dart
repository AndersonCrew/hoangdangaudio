import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

const _boxName = 'hoang_dang_audio_calendar';
const _ink = Color(0xFF2E1209);
const _brown = Color(0xFF7A4A2B);
const _paper = Color(0xFFFCFAF7);

CollectionReference<Map<String, dynamic>> get _daysCollection {
  return FirebaseFirestore.instance.collection('calendar_days');
}

//Script
// Shoot
// Edit
// Post
enum StoryStatus {
  none('Nothing', null, Color(0xFF7A4A2B), Color(0xFFFFFBF7)),
  edited(
    'Edited',
    'lib/icons/ic_pen.png',
    Color(0xFFFF7A00),
    Color(0xFFFFF1DF),
  ),
  filmed(
    'Recorded',
    'lib/icons/ic_camera.png',
    Color(0xFF1479C9),
    Color(0xFFE8F5FF),
  ),
  produced(
    'Produced',
    'lib/icons/ic_edited.png',
    Color(0xFF5B28CC),
    Color(0xFFF1E9FF),
  ),
  posted(
    'Posted',
    'lib/icons/ic_pushlish.png',
    Color(0xFF178A27),
    Color(0xFFE9F8E5),
  );

  const StoryStatus(
    this.label,
    this.iconPath,
    this.accentColor,
    this.softColor,
  );

  final String label;
  final String? iconPath;
  final Color accentColor;
  final Color softColor;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await Hive.openBox<dynamic>(_boxName);
  runApp(const HoangDangAudioApp());
}

class HoangDangAudioApp extends StatelessWidget {
  const HoangDangAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hoàng Đăng Audio',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(seedColor: _brown),
      ),
      home: const CalendarScreen(),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _initialPage = 1200;
  final _box = Hive.box<dynamic>(_boxName);
  final _pageController = PageController(initialPage: _initialPage);
  final _today = DateTime.now();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _syncSubscription;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_today.year, _today.month);
    _startFirestoreSync();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startFirestoreSync() {
    try {
      _syncSubscription = _daysCollection.snapshots().listen(
        (snapshot) async {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.removed) {
              await _box.delete(change.doc.id);
              continue;
            }

            final data = _DayData.fromFirestore(change.doc.data());
            await _box.put(change.doc.id, data.toStorageValue());
          }

          if (mounted) setState(() {});
        },
        onError: (Object error) {
          debugPrint('Firebase realtime sync failed: $error');
        },
      );
    } catch (_) {
      // Widget tests can build the app without Firebase initialization.
    }
  }

  void _goToMonth(int offset) {
    final nextPage = (_pageController.page ?? _initialPage).round() + offset;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _MonthHeader(
                month: _visibleMonth,
                onPrevious: () => _goToMonth(-1),
                onNext: () => _goToMonth(1),
              ),
              const SizedBox(height: 14),
              const _WeekdayRow(),
              const SizedBox(height: 10),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() {
                      _visibleMonth = DateTime(
                        _today.year,
                        _today.month + page - _initialPage,
                      );
                    });
                  },
                  itemBuilder: (context, page) {
                    final month = DateTime(
                      _today.year,
                      _today.month + page - _initialPage,
                    );
                    return _MonthGrid(
                      month: month,
                      today: _today,
                      box: _box,
                      onChanged: () => setState(() {}),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              const _Legend(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleIconButton(
          tooltip: 'Tháng trước',
          icon: Icons.chevron_left_rounded,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            'Tháng ${month.month}, ${month.year}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _CircleIconButton(
          tooltip: 'Tháng sau',
          icon: Icons.chevron_right_rounded,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFFFF7EC),
        fixedSize: const Size(42, 42),
      ),
      icon: Icon(icon, size: 24, color: _ink),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    const sundayColor = Color(0xFFE53935);
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Center(
              child: Text(
                day,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: day == 'CN' ? sundayColor : const Color(0xFF80543A),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.box,
    required this.onChanged,
  });

  final DateTime month;
  final DateTime today;
  final Box<dynamic> box;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final leadingCells = firstDay.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rowCount = ((leadingCells + daysInMonth) / 7).ceil();
    final cellCount = rowCount * 7;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.5,
      ),
      itemCount: cellCount,
      itemBuilder: (context, index) {
        final dayOffset = index - leadingCells;
        final date = DateTime(month.year, month.month, dayOffset + 1);
        final isCurrentMonth = date.month == month.month;
        final data = _DayData.fromBox(box.get(_dateKey(date)));
        final isToday = _sameDate(date, today);

        return _DayCell(
          date: date,
          data: data,
          isToday: isToday,
          isCurrentMonth: isCurrentMonth,
          onTap: () => _showUpdateSheet(context, box, date, data, onChanged),
          onSwipe: (direction) => _handleStatusSwipe(
            context: context,
            box: box,
            date: date,
            data: data,
            direction: direction,
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}

enum _SwipeDirection { up, down }

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.data,
    required this.isToday,
    required this.isCurrentMonth,
    required this.onTap,
    required this.onSwipe,
  });

  final DateTime date;
  final _DayData data;
  final bool isToday;
  final bool isCurrentMonth;
  final VoidCallback onTap;
  final ValueChanged<_SwipeDirection> onSwipe;

  @override
  Widget build(BuildContext context) {
    const sundayColor = Color(0xFFE53935);
    const todayColor = Color(0xFFFF4C22);
    const inactiveTextColor = Color(0xFFAAA39B);
    const inactiveBorderColor = Color(0xFFE5E0DA);
    final isSunday = date.weekday == DateTime.sunday;
    final textColor = !isCurrentMonth
        ? inactiveTextColor
        : isToday
        ? todayColor
        : isSunday
        ? sundayColor
        : _ink;
    final borderColor = !isCurrentMonth
        ? inactiveBorderColor
        : isToday
        ? todayColor
        : const Color(0xFFEFDCC8);
    final cellColor = isCurrentMonth
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFFF2F0ED).withValues(alpha: 0.58);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -260) {
          onSwipe(_SwipeDirection.up);
        } else if (velocity > 260) {
          onSwipe(_SwipeDirection.down);
        }
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: isToday ? 1.2 : 0.8),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 30,
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: borderColor),
              Expanded(
                child: Opacity(
                  opacity: isCurrentMonth ? 1 : 0.34,
                  child: Center(child: _AnimatedDayContent(data: data)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedDayContent extends StatelessWidget {
  const _AnimatedDayContent({required this.data});

  final _DayData data;

  @override
  Widget build(BuildContext context) {
    final hasStatus = data.status != StoryStatus.none;
    final hasEpisode = data.episode.trim().isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.24),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: hasStatus
          ? Column(
              key: ValueKey('${data.status.name}-${data.episode}'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  data.status.iconPath!,
                  width: 28,
                  height: 28,
                  cacheHeight: 28,
                  cacheWidth: 28,
                ),
                const SizedBox(height: 5),
                if (hasEpisode)
                  Text(
                    'Tập ${data.episode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: data.status.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            )
          : const SizedBox(key: ValueKey('none'), width: 1, height: 1),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFDCC8)),
      ),
      child: Row(
        children: [
          for (final status in StoryStatus.values) ...[
            if (status != StoryStatus.none) ...[
              Expanded(child: _LegendItem(status: status)),
            ],

            if (status != StoryStatus.values.last && status != StoryStatus.none)
              const SizedBox(
                height: 30,
                child: VerticalDivider(color: Color(0xFFEFDCC8)),
              ),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.status});

  final StoryStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 2,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: status.softColor,
            shape: BoxShape.circle,
          ),
          child: Image.asset(status.iconPath!),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _DayData {
  const _DayData({required this.status, this.episode = ''});

  final StoryStatus status;
  final String episode;

  factory _DayData.fromBox(dynamic value) {
    if (value is String) {
      final parts = value.split('|');
      return _DayData(
        status: _statusFromName(parts.first),
        episode: parts.length > 1 ? parts.sublist(1).join('|') : '',
      );
    }

    if (value is! Map) return const _DayData(status: StoryStatus.none);

    return _DayData(
      status: _statusFromName(value['status'] as String?),
      episode: (value['episode'] as String?) ?? '',
    );
  }

  factory _DayData.fromFirestore(Map<String, dynamic>? value) {
    if (value == null) return const _DayData(status: StoryStatus.none);

    return _DayData(
      status: _statusFromName(value['status'] as String?),
      episode: (value['episode'] as String?) ?? '',
    );
  }

  String toStorageValue() {
    return '${status.name}|$episode';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'status': status.name,
      'episode': episode,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

StoryStatus _statusFromName(String? name) {
  return switch (name) {
    'ready' => StoryStatus.edited,
    'edited' => StoryStatus.edited,
    'filmed' => StoryStatus.filmed,
    'produced' => StoryStatus.produced,
    'posted' => StoryStatus.posted,
    _ => StoryStatus.none,
  };
}

StoryStatus? _nextStatus(StoryStatus status) {
  final index = StoryStatus.values.indexOf(status);
  if (index >= StoryStatus.values.length - 1) return null;
  return StoryStatus.values[index + 1];
}

StoryStatus? _previousStatus(StoryStatus status) {
  final index = StoryStatus.values.indexOf(status);
  if (index <= 0) return null;
  return StoryStatus.values[index - 1];
}

Future<void> _handleStatusSwipe({
  required BuildContext context,
  required Box<dynamic> box,
  required DateTime date,
  required _DayData data,
  required _SwipeDirection direction,
  required VoidCallback onChanged,
}) async {
  final nextStatus = direction == _SwipeDirection.up
      ? _nextStatus(data.status)
      : _previousStatus(data.status);

  if (nextStatus == null) return;

  if (data.status == StoryStatus.none && nextStatus == StoryStatus.edited) {
    await _showUpdateSheet(
      context,
      box,
      date,
      data,
      onChanged,
      initialStatus: StoryStatus.edited,
      focusEpisode: true,
    );
    return;
  }

  final nextData = _DayData(
    status: nextStatus,
    episode: nextStatus == StoryStatus.none ? '' : data.episode,
  );
  final key = _dateKey(date);
  await box.put(key, nextData.toStorageValue());
  onChanged();
  if (context.mounted) {
    unawaited(
      _syncDayToFirestore(ScaffoldMessenger.of(context), key, nextData),
    );
  }
}

Future<void> _showUpdateSheet(
  BuildContext context,
  Box<dynamic> box,
  DateTime date,
  _DayData data,
  VoidCallback onChanged, {
  StoryStatus? initialStatus,
  bool focusEpisode = false,
}) async {
  var selectedStatus = initialStatus ?? data.status;
  final episodeController = TextEditingController(text: data.episode);

  Future<void> save(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final key = _dateKey(date);
    final episode = selectedStatus == StoryStatus.none
        ? ''
        : _cleanEpisode(episodeController.text);
    if (selectedStatus != StoryStatus.none && episode.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nhập số tập trước khi lưu trạng thái.')),
      );
      return;
    }

    final nextData = _DayData(status: selectedStatus, episode: episode);

    await box.put(key, nextData.toStorageValue());
    onChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) navigator.pop();
    });
    unawaited(_syncDayToFirestore(messenger, key, nextData));
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                22,
                10,
                22,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 70,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4CBC4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Cập nhật trạng thái',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _longDate(date),
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: const Color(0xFF6E6259),
                          fontSize: 15,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      for (final status in StoryStatus.values) ...[
                        Expanded(
                          child: _StatusChoice(
                            status: status,
                            selected: selectedStatus == status,
                            onTap: () => setSheetState(() {
                              selectedStatus = status;
                            }),
                          ),
                        ),
                        if (status != StoryStatus.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Số tập',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: episodeController,
                    autofocus: focusEpisode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixIcon: Container(
                        width: 48,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5EEE7),
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '#',
                          style: TextStyle(
                            color: _brown,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      suffixIcon: IconButton(
                        onPressed: episodeController.clear,
                        icon: const Icon(Icons.cancel_rounded),
                      ),
                      hintText: 'Tập 57',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2D5C8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2D5C8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _brown),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _brown,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => save(
                      Navigator.of(sheetContext),
                      ScaffoldMessenger.of(context),
                    ),
                    child: const Text(
                      'Lưu trạng thái',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  // Keep the controller alive through the keyboard/sheet closing animation.
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final StoryStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        height: 86,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? _brown : const Color(0xFFE6DCD2),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status.iconPath == null)
              const SizedBox(height: 30)
            else
              Image.asset(status.iconPath!, width: 30, height: 30),
            const SizedBox(height: 8),
            Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _syncDayToFirestore(
  ScaffoldMessengerState messenger,
  String key,
  _DayData data,
) async {
  try {
    await _daysCollection
        .doc(key)
        .set(data.toFirestore(), SetOptions(merge: true));
    debugPrint('Firebase synced calendar_days/$key');
  } on FirebaseException catch (error) {
    debugPrint(
      'Firebase sync failed calendar_days/$key: ${error.code} ${error.message}',
    );
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Chưa sync Firebase: ${error.code}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (error) {
    debugPrint('Firebase sync failed calendar_days/$key: $error');
    if (messenger.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã lưu trên máy, chưa sync Firebase.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

String _cleanEpisode(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _longDate(DateTime date) {
  const weekdays = [
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
    'Chủ nhật',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} tháng ${date.month}, ${date.year}';
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
