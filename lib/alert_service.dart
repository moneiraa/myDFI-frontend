import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// ======== INITIALIZE NOTIFICATIONS ========
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
  const InitializationSettings settings =
      InitializationSettings(android: androidSettings, iOS: iosSettings);

  await flutterLocalNotificationsPlugin.initialize(settings);
  tz.initializeTimeZones();
}

/// ======== REQUEST PERMISSIONS (iOS & ANDROID 13+) ========
Future<void> requestNotificationPermissions() async {
  final iosImplementation = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  await iosImplementation?.requestPermissions(alert: true, badge: true, sound: true);

  final androidImplementation = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImplementation?.requestNotificationsPermission();
}

/// ======== SHOW NOTIFICATION (Immediate Trigger) ========
Future<void> showNotification(String title, String message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'daily_alerts',
    'Daily Alerts',
    channelDescription: 'Daily static alerts',
    importance: Importance.high,
    priority: Priority.high,
  );
  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);
  await flutterLocalNotificationsPlugin.show(0, title, message, notificationDetails);
}

/// ======== SCHEDULE DAILY NOTIFICATION (10 AM) ========
Future<void> scheduleDailyNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'daily_alerts',
    'Daily Alerts',
    channelDescription: 'Daily static alerts',
    importance: Importance.high,
    priority: Priority.high,
  );
  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    'سالِم',
    'سلامتك اهم، شيّك اذا في تداخلات مع دواك',
    _nextInstanceOfTenAM(),
    notificationDetails,
    androidAllowWhileIdle: true,
    matchDateTimeComponents: DateTimeComponents.time,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

/// ======== GET NEXT 10 AM (LOCAL TIME) ========
tz.TZDateTime _nextInstanceOfTenAM() {
  final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  tz.TZDateTime scheduledDate =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }
  return scheduledDate;
}

/// ======== NEW FEATURE: CHECK BACKEND & SCHEDULE ALERT ========
Future<void> scheduleAlertIfInteractionsExist(String baseUrl) async {
  try {
    final response = await http.get(Uri.parse("$baseUrl/user/1/has-interactions"));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['hasInteractions'] == true) {
        debugPrint("Interactions found → scheduling daily notification");
        await scheduleDailyNotification();
      } else {
        debugPrint("No interactions → alert not scheduled");
      }
    } else {
      debugPrint("Error response from backend: ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("Error checking interactions: $e");
  }
}