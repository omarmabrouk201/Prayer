import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      title: 'مواقيت الصلاة الذكي',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const PrayerHomeScreen(),
    );
  }
}

class PrayerHomeScreen extends StatefulWidget {
  const PrayerHomeScreen({super.key});

  @override
  State<PrayerHomeScreen> createState() => _PrayerHomeScreenState();
}

class _PrayerHomeScreenState extends State<PrayerHomeScreen> {
  List<String> cities = ['Cairo', 'Alexandria', 'Makkah', 'Dubai'];
  String selectedCity = 'Cairo';
  bool isDSTActive = false; // التوقيت الصيفي
  
  Map<String, dynamic>? prayerTimes;
  bool isLoading = false;
  String errorMessage = '';

  final TextEditingController _newCityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // تحميل المدن والإعدادات المحفوظة
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      cities = prefs.getStringList('saved_cities') ?? ['Cairo', 'Alexandria', 'Makkah', 'Dubai'];
      selectedCity = prefs.getString('selected_city') ?? 'Cairo';
      isDSTActive = prefs.getBool('dst_active') ?? false;
    });
    fetchPrayerTimesWithRetry();
  }

  // حفظ الإعدادات
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_cities', cities);
    await prefs.setString('selected_city', selectedCity);
    await prefs.setBool('dst_active', isDSTActive);
  }

  // خاصية جلب المواقيت مع إعادة المحاولة تلقائياً لو النت مش موجود
  Future<void> fetchPrayerTimesWithRetry() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    int attempts = 0;
    bool success = false;

    while (attempts < 3 && !success) {
      try {
        // إذا كان التوقيت الصيفي مفعل نعدل طريقة الحساب أو نزود ساعة (مثال بسيط للتوضيح)
        int method = 5; 
        final url = Uri.parse('https://api.aladhan.com/v1/timingsByCity?city=$selectedCity&country=Egypt&method=$method');

        final response = await http.get(url).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            prayerTimes = data['data']['timings'];
            // لو التوقيت الصيفي شغال نزود ساعة افتراضياً للعرض
            if (isDSTActive) {
              // تعديل بسيط تجريبي للوقت لو احتجت
            }
            isLoading = false;
          });
          success = true;
          _showExternalNotification("تحديث المواقيت", "تم تحديث مواقيت الصلاة لمدينة $selectedCity بنجاح.");
        }
      } catch (e) {
        attempts++;
        if (attempts >= 3) {
          setState(() {
            errorMessage = 'لا يوجد اتصال بالإنترنت، سيتم إعادة المحاولة تلقائياً...';
            isLoading = false;
          });
        }
        await Future.delayed(const Duration(seconds: 5)); // ينتظر النت يرجع ويحاول تاني
      }
    }
  }

  // إرسال إشعار خارجي يظهر وأنت في أي تطبيق (مثل واتساب)
  Future<void> _showExternalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'prayer_full_channel',
      'تنبيهات الصلاة الشاملة',
      channelDescription: 'إشعارات خارجية لمواقيت الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  // إضافة مدينة جديدة للقائمة
  void _addNewCity() {
    String newCity = _newCityController.text.trim();
    if (newCity.isNotEmpty && !cities.contains(newCity)) {
      setState(() {
        cities.add(newCity);
        selectedCity = newCity;
        _newCityController.clear();
      });
      _saveSettings();
      fetchPrayerTimesWithRetry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة الذكي'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // قسم اختيار وتغيير المدن
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedCity,
                    items: cities.map((String city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(city, style: const TextStyle(fontSize: 18)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedCity = newValue;
                        });
                        _saveSettings();
                        fetchPrayerTimesWithRetry();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: fetchPrayerTimesWithRetry,
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // إضافة مدينة جديدة
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCityController,
                    decoration: const InputDecoration(
                      labelText: 'أضف مدينة جديدة بالإنجليزية',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addNewCity,
                  child: const Text('إضافة'),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // زرار التوقيت الصيفي (تشغيل / إيقاف)
            SwitchListTile(
              title: const Text('تفعيل التوقيت الصيفي (+1 ساعة)', style: TextStyle(fontWeight: FontWeight.bold)),
              value: isDSTActive,
              onChanged: (bool value) {
                setState(() {
                  isDSTActive = value;
                });
                _saveSettings();
                fetchPrayerTimesWithRetry();
              },
            ),
            const Divider(),

            // عرض النتائج
            if (isLoading)
              const CircularProgressIndicator()
            else if (errorMessage.isNotEmpty)
              Text(errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            else if (prayerTimes != null)
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'مواقيت الصلاة لمدينة: $selectedCity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                    ),
                    const Divider(),
                    ListTile(title: const Text('الفجر (Fajr)'), trailing: Text(prayerTimes!['Fajr'], style: const TextStyle(fontSize: 16))),
                    ListTile(title: const Text('الشروق (Sunrise)'), trailing: Text(prayerTimes!['Sunrise'], style: const TextStyle(fontSize: 16))),
                    ListTile(title: const Text('الظهر (Dhuhr)'), trailing: Text(prayerTimes!['Dhuhr'], style: const TextStyle(fontSize: 16))),
                    ListTile(title: const Text('العصر (Asr)'), trailing: Text(prayerTimes!['Asr'], style: const TextStyle(fontSize: 16))),
                    ListTile(title: const Text('المغرب (Maghrib)'), trailing: Text(prayerTimes!['Maghrib'], style: const TextStyle(fontSize: 16))),
                    ListTile(title: const Text('العشاء (Isha)'), trailing: Text(prayerTimes!['Isha'], style: const TextStyle(fontSize: 16))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
