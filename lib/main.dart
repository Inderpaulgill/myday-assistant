import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final notifications = FlutterLocalNotificationsPlugin();

const categories = [
  'Water', 'Medication', 'Exercise', 'Study', 'Office', 'Login',
  'Meals & snacks', 'Priority', 'Night beauty', 'Hair care', 'Sleep', 'Other'
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(const InitializationSettings(android: android));
  final androidPlugin = notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.requestNotificationsPermission();
  await androidPlugin?.requestExactAlarmsPermission();
  runApp(const MyDayApp());
}

class ReminderTask {
  ReminderTask({
    required this.id, required this.title, required this.category,
    required this.hour, required this.minute, required this.repeat,
    this.done = false, this.overdue = false,
  });
  final int id;
  String title, category, repeat;
  int hour, minute;
  bool done, overdue;

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'category': category, 'hour': hour,
    'minute': minute, 'repeat': repeat, 'done': done, 'overdue': overdue
  };
  factory ReminderTask.fromJson(Map<String, dynamic> j) => ReminderTask(
    id: j['id'], title: j['title'], category: j['category'],
    hour: j['hour'], minute: j['minute'], repeat: j['repeat'],
    done: j['done'] ?? false, overdue: j['overdue'] ?? false,
  );
}

class MyDayApp extends StatelessWidget {
  const MyDayApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MyDay Assistant',
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ReminderTask> tasks = [];
  bool loaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('tasks');
    if (raw != null) {
      tasks = (jsonDecode(raw) as List).map((e) => ReminderTask.fromJson(e)).toList();
    }
    if (tasks.isEmpty) {
      tasks = [
        ReminderTask(id: 1, title: 'Drink water', category: 'Water', hour: 9, minute: 0, repeat: 'Daily'),
        ReminderTask(id: 2, title: 'Study for 30 minutes', category: 'Study', hour: 10, minute: 0, repeat: 'Daily'),
        ReminderTask(id: 3, title: 'Lunch break', category: 'Meals & snacks', hour: 13, minute: 0, repeat: 'Daily'),
      ];
      await _save();
    }
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tasks', jsonEncode(tasks.map((e) => e.toJson()).toList()));
  }

  Future<void> _schedule(ReminderTask t) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
    if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));
    await notifications.zonedSchedule(
      t.id, 'MyDay: ${t.title}', '${t.category} • Tap to review your task',
      scheduled,
      const NotificationDetails(android: AndroidNotificationDetails(
        'myday_reminders', 'MyDay reminders',
        channelDescription: 'Scheduled personal task reminders',
        importance: Importance.max, priority: Priority.high, playSound: true,
      )),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: t.repeat == 'Daily' ? DateTimeComponents.time : null,
    );
  }

  Future<void> _addTask() async {
    final title = TextEditingController();
    String category = categories.first;
    String repeat = 'Daily';
    TimeOfDay time = TimeOfDay.now();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, refresh) => AlertDialog(
        title: const Text('New reminder'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task name')),
          DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category'),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => refresh(() => category = v ?? categories.first)),
          DropdownButtonFormField<String>(value: repeat, decoration: const InputDecoration(labelText: 'Repeat'),
            items: ['Daily', 'One time'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => refresh(() => repeat = v ?? 'Daily')),
          const SizedBox(height: 8),
          OutlinedButton.icon(icon: const Icon(Icons.alarm), label: Text('Time: ${time.format(ctx)}'),
            onPressed: () async { final picked = await showTimePicker(context: ctx, initialTime: time); if (picked != null) refresh(() => time = picked); }),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    ));
    if (ok != true || title.text.trim().isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2000000000);
    final task = ReminderTask(id: id, title: title.text.trim(), category: category,
      hour: time.hour, minute: time.minute, repeat: repeat);
    setState(() => tasks.add(task));
    await _save();
    await _schedule(task);
  }

  Future<void> _confirm(ReminderTask task) async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirm completion'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Complete “${task.title}”? Type DONE to confirm.'),
        TextField(controller: controller, textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Type DONE')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim().toUpperCase() == 'DONE'),
          child: const Text('Confirm')),
      ],
    ));
    if (accepted == true) {
      setState(() { task.done = true; task.overdue = false; });
      await notifications.cancel(task.id);
      await _save();
    } else if (controller.text.trim().isNotEmpty && controller.text.trim().toUpperCase() != 'DONE' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter DONE exactly to confirm.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = tasks.where((t) => !t.done).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('MyDay Assistant'), actions: [
        IconButton(onPressed: () async {
          for (final t in tasks.where((x) => !x.done)) { await _schedule(t); }
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pending reminders scheduled.')));
        }, icon: const Icon(Icons.notifications_active), tooltip: 'Schedule pending reminders'),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addTask, icon: const Icon(Icons.add), label: const Text('Add reminder')),
      body: !loaded ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(18), color: Theme.of(context).colorScheme.primaryContainer,
          child: Text('${pending.length} tasks pending • ${tasks.where((t) => t.done).length} completed',
            style: Theme.of(context).textTheme.titleMedium)),
        Expanded(child: tasks.isEmpty ? const Center(child: Text('Add your first reminder')) :
          ListView.builder(itemCount: tasks.length, itemBuilder: (ctx, i) {
            final t = tasks[i];
            return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: ListTile(
              leading: CircleAvatar(child: Icon(t.done ? Icons.check : Icons.alarm)),
              title: Text(t.title, style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null)),
              subtitle: Text('${t.category} • ${TimeOfDay(hour: t.hour, minute: t.minute).format(context)} • ${t.repeat}${t.overdue ? ' • OVERDUE' : ''}'),
              trailing: t.done ? const Icon(Icons.check_circle, color: Colors.green) :
                IconButton(onPressed: () => _confirm(t), icon: const Icon(Icons.task_alt), tooltip: 'Complete task'),
            ));
          })),
        const Padding(padding: EdgeInsets.all(12), child: Text('Starter version: test alarm delivery on your phone before relying on reminders.',
          textAlign: TextAlign.center)),
      ]),
    );
  }
}

