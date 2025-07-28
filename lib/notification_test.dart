import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize time zones
  tz.initializeTimeZones();

  // Initialize notifications
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Notification Test')),
        body: Center(
          child: ElevatedButton(
            child: const Text("Schedule 1-min Notification"),
            onPressed: () async {
              const AndroidNotificationDetails androidDetails =
                  AndroidNotificationDetails('test_channel', 'Test Channel',
                      importance: Importance.high, priority: Priority.high);
              const NotificationDetails notificationDetails =
                  NotificationDetails(android: androidDetails);

              final tz.TZDateTime scheduledTime =
                  tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));

              await flutterLocalNotificationsPlugin.zonedSchedule(
                0,
                'Test Title',
                'This should appear after 1 minute',
                scheduledTime,
                notificationDetails,
                androidAllowWhileIdle: true,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
              );
            },
          ),
        ),
      ),
    );
  }
}
