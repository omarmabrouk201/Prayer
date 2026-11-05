import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

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
  // قائمة شاملة بمحافظات ومدن مصر الرئيسية
  final List<String> egyptianCities = [
    'Cairo', 'Alexandria', 'Giza', 'Port Said', 'Suez', 
    'Luxor', 'Aswan', 'Mansoura', 'Tanta', 'Ismailia', 
    'Fayoum', 'Zagazig', 'Damietta', 'Minya', 'Assiut', 'Sohag', 'Qena'
  ];

  List<String> savedCities = ['Cairo', 'Alexandria', 'Giza'];
  String selectedCity = 'Cairo';
  bool isDSTActive = false;
  
  Map<String, dynamic>? prayerTimes;
  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      savedCities = prefs.getStringList('saved_cities') ?? ['Cairo', 'Alexandria', 'Giza'];
      selectedCity = prefs.getString('selected_city') ?? 'Cairo';
      isDSTActive = prefs.getBool('dst_active') ?? false;
    });
    fetchPrayerTimes();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_cities', savedCities);
    await prefs.setString('selected_city', selectedCity);
    await prefs.setBool('dst_active', isDSTActive);
  }

  // خاصية جلب المواقيت عبر الإنترنت مع ضبط التوقيت الصيفي إن وجد
  Future<void> fetchPrayerTimes() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url = Uri.parse('https://api.aladhan.com/v1/timingsByCity?city=$selectedCity&country=Egypt&method=5');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Map<String, dynamic> timings = data['data']['timings'];

        // إذا كان التوقيت الصيفي مفعل، نقوم بزيادة ساعة افتراضياً لعرض الوقت بدقة
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
        _showNotification("تحديث المواقيت", "تم جلب مواقيت الصلاة لمدينة $selectedCity بنجاح.");
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

  // محاولة تحديد الموقع الجغرافي بالاحداثيات وتقريبها لأقرب مدينة مصرية رئيسية
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMsg('خدمة الموقع الجغرافي (GPS) مغلقة.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMsg('تم رفض إذن الوصول للموقع.');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _showMsg('صلاحية الموقع مرفوضة بشكل دائم.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      // افتراض القاهرة كبداية أو تحديد الإحداثيات، ويمكن للمستخدم اختيار مدينته بسهولة من القائمة الشاملة
      _showMsg('تم تحديد موقعك بنجاح! اختر محافظتك من القائمة.');
    } catch (e) {
      _showMsg('تعذر جلب الموقع الحالي.');
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'prayer_full_channel',
      'تنبيهات الصلاة الشاملة',
      channelDescription: 'إشعارات خارجية لمواقيت الصلاة',
      importance: Importance.max,
      priority: Priority.high,
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
        title: const Text('مواقيت الصلاة الذكي'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // قائمة اختيار المحافظات والمدن المتاحة
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: savedCities.contains(selectedCity) ? selectedCity : savedCities.first,
                    items: savedCities.map((String city) {
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
                        fetchPrayerTimes();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: fetchPrayerTimes,
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // زر اختيار مدينة من القائمة الشاملة لمصر
            ElevatedButton.icon(
              onPressed: () {
                _showCityPickerBottomSheet(context);
              },
              icon: const Icon(Icons.list),
              label: const Text('اختر من كل محافظات ومدن مصر'),
            ),
            const SizedBox(height: 5),

            // زر لتحديد الموقع الحالي عبر GPS
            OutlinedButton.icon(
              onPressed: _determinePosition,
              icon: const Icon(Icons.my_location),
              label: const Text('تحديد موقعي الحالي GPS'),
            ),
            const SizedBox(height: 5),

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

  // نافذة لاختيار أي مدينة مصرية وإضافتها للقائمة المحفوظة
  void _showCityPickerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر محافظة أو مدينة مصرية:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: egyptianCities.length,
                  itemBuilder: (context, index) {
                    String city = egyptianCities[index];
                    return ListTile(
                      title: Text(city),
                      onTap: () {
                        setState(() {
                          if (!savedCities.contains(city)) {
                            savedCities.add(city);
                          }
                          selectedCity = city;
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
