import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const PrayerApp());
}

class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مواقيت الصلاة',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const PrayerHomeScreen(),
    );
  }
}

class PrayerHomeScreen extends StatefulWidget {
  const PrayerHomeScreen({super.key});

  @override
  _PrayerHomeScreenState createState() => _PrayerHomeScreenState();
}

class _PrayerHomeScreenState extends State<PrayerHomeScreen> {
  final TextEditingController _cityController = TextEditingController(text: 'Cairo');
  final TextEditingController _countryController = TextEditingController(text: 'Egypt');
  
  Map<String, dynamic>? prayerTimes;
  bool isLoading = false;
  String errorMessage = '';

  Future<void> fetchPrayerTimes() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final city = _cityController.text.trim();
    final country = _countryController.text.trim();
    final url = Uri.parse('https://api.aladhan.com/v1/timingsByCity?city=$city&country=$country&method=5');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          prayerTimes = data['data']['timings'];
          isLoading = false;
        });
        _showNotification("تم التحديث", "تم جلب مواقيت الصلاة لمدينة $city بنجاح");
      } else {
        setState(() {
          errorMessage = 'فشل جلب البيانات، تأكد من اسم المدينة والبلد بالإنجليزية.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'خطأ في الاتصال بالإنترنت.';
        isLoading = false;
      });
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'prayer_channel_id',
      'مواقيت الصلاة',
      channelDescription: 'تنبيهات مواقيت الصلاة اليومية',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تطبيق مواقيت الصلاة والتنبيهات'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'المدينة (بالإنجليزية مثلاً: Cairo أو Dubai)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'الدولة (بالإنجليزية مثلاً: Egypt)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: fetchPrayerTimes,
              icon: const Icon(Icons.search),
              label: const Text('جلب المواقيت'),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const CircularProgressIndicator()
            else if (errorMessage.isNotEmpty)
              Text(errorMessage, style: const TextStyle(color: Colors.red))
            else if (prayerTimes != null)
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'مواقيت الصلاة اليوم:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('الفجر (Fajr)'),
                      trailing: Text(prayerTimes!['Fajr'], style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      title: const Text('الشروق (Sunrise)'),
                      trailing: Text(prayerTimes!['Sunrise'], style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      title: const Test('الظهر (Dhuhr)'),
                      trailing: Text(prayerTimes!['Dhuhr'], style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      title: const Text('العصر (Asr)'),
                      trailing: Text(prayerTimes!['Asr'], style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      title: const Text('المغرب (Maghrib)'),
                      trailing: Text(prayerTimes!['Maghrib'], style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      title: const Text('العشاء (Isha)'),
                      trailing: Text(prayerTimes!['Isha'], style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
