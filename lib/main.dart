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
  final Map<String, String> egyptCities = {
    'القاهرة (الدقي / وسط البلد)': 'Cairo',
    'الجيزة (الهرم / الدقي)': 'Giza',
    'الإسكندرية': 'Alexandria',
    'الدقهلية (المنصورة)': 'Mansoura',
    'الشرقية (الزقازيق)': 'Zagazig',
    'القليوبية (بنها)': 'Banha',
    'الغربية (طنطا)': 'Tanta',
    'أسوان': 'Aswan',
    'الأقصر': 'Luxor',
    'بورسعيد': 'Port Said',
    'السويس': 'Suez',
    'الإسماعيلية': 'Ismailia',
    'الغردقة (البحر الأحمر)': 'Hurghada'
  };

  String selectedCityArabic = 'الجيزة (الهرم / الدقي)';
  String selectedCityApi = 'Giza';
  
  bool isDSTActive = false;
  Map<String, dynamic>? prayerTimes;
  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission(); // طلب إذن الإشعارات فور فتح التطبيق
    _loadSavedData();
  }

  // طلب إذن الإشعارات لأنظمة أندرويد الحديثة
  Future<void> _requestNotificationPermission() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedCityArabic = prefs.getString('selected_city_ar') ?? 'الجيزة (الهرم / الدقي)';
      selectedCityApi = prefs.getString('selected_city_api') ?? 'Giza';
      isDSTActive = prefs.getBool('dst_active') ?? false;
    });
    fetchPrayerTimes();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_city_ar', selectedCityArabic);
    await prefs.setString('selected_city_api', selectedCityApi);
    await prefs.setBool('dst_active', isDSTActive);
  }

  Future<void> fetchPrayerTimes() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url = Uri.parse('https://api.aladhan.com/v1/timingsByCity?city=$selectedCityApi&country=Egypt&method=5');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Map<String, dynamic> timings = data['data']['timings'];

        if (isDSTActive) {
          timings.updateAll((key, value) {
            if (value is String && value.contains(':')) {
              try {
                final parts = value.split(':');
                int hour = (int.parse(parts[0]) + 1) % 24;
                String minute = parts[1];
                return '${hour.toString().padLeft(2, '0')}:$minute';
              } catch (e) {
                return value;
              }
            }
            return value;
          });
        }

        setState(() {
          prayerTimes = timings;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'فشل جلب البيانات، تأكد من الاتصال بالإنترنت.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'لا يوجد اتصال بالإنترنت أو خطأ في الشبكة.';
        isLoading = false;
      });
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
            Card(
              elevation: 3,
              child: ListTile(
                title: const Text('المنطقة الحالية:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                subtitle: Text(selectedCityArabic, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                trailing: ElevatedButton(
                  onPressed: () => _showCityPickerDialog(context),
                  child: const Text('تغيير'),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SwitchListTile(
              title: const Text('تفعيل التوقيت الصيفي (+1 ساعة)', style: TextStyle(fontWeight: FontWeight.bold)),
              value: isDSTActive,
              onChanged: (bool value) {
                setState(() {
                  isDSTActive = value;
                });
                _saveSettings();
                fetchPrayerTimes();
              },
            ),
            const Divider(),

            if (isLoading)
              const CircularProgressIndicator()
            else if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              )
            else if (prayerTimes != null)
              Expanded(
                child: ListView(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المواقيت:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: fetchPrayerTimes,
                        ),
                      ],
                    ),
                    const Divider(),
                    ListTile(title: const Text('الفجر'), trailing: Text(prayerTimes!['Fajr'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('الشروق'), trailing: Text(prayerTimes!['Sunrise'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('الظهر'), trailing: Text(prayerTimes!['Dhuhr'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('العصر'), trailing: Text(prayerTimes!['Asr'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('المغرب'), trailing: Text(prayerTimes!['Maghrib'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('العشاء'), trailing: Text(prayerTimes!['Isha'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCityPickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر المحافظة / المدينة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: egyptCities.length,
                  itemBuilder: (context, index) {
                    String cityAr = egyptCities.keys.elementAt(index);
                    String cityApi = egyptCities[cityAr]!;
                    return ListTile(
                      title: Text(cityAr, style: const TextStyle(fontSize: 16)),
                      onTap: () {
                        setState(() {
                          selectedCityArabic = cityAr;
                          selectedCityApi = cityApi;
                        });
                        _saveSettings();
                        fetchPrayerTimes();
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
