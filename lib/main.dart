import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
    'Fayoum', 'Zagazig', 'Damietta', 'Aswan', 'Minya', 'Assiut'
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
    // محاولة جلب موقع المستخدم تلقائياً عند فتح التطبيق
    _determinePositionAndSuggest();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_cities', savedCities);
    await prefs.setString('selected_city', selectedCity);
    await prefs.setBool('dst_active', isDSTActive);
  }

  // خاصية جلب المواقيت عبر الإنترنت
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
        setState(() {
          prayerTimes = data['data']['timings'];
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

  // خاصية تحديد موقع المستخدم الجغرافي واقتراح المدينة
  Future<void> _determinePositionAndSuggest() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        String? currentCity = placemarks.first.locality ?? placemarks.first.subAdministrativeArea;
        if (currentCity != null && mounted) {
          // سؤال المستخدم إذا كان يريد إضافة وتفعيل مدينته الحالية
          _showLocationDialog(currentCity);
        }
      }
    } catch (e) {
      // تجاهل الخطأ صامتاً لو تعذر جلب الموقع GPS
    }
  }

  void _showLocationDialog(String detectedCity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديد الموقع الجغرافي'),
        content: Text('تم اكتشاف أنك في مدينة ($detectedCity). هل تريد إضافتها واختيارها للمواقيت؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (!savedCities.contains(detectedCity)) {
                  savedCities.add(detectedCity);
                }
                selectedCity = detectedCity;
              });
              _saveSettings();
              fetchPrayerTimes();
            },
            child: const Text('نعم، استخدمها'),
          ),
        ],
      ),
    );
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
            // قائمة اختيار المحافظات والمدن
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

            // زر لاختيار مدينة من القائمة الشاملة لمصر
            ElevatedButton.icon(
              onPressed: () {
                _showCityPickerBottomSheet(context);
              },
              icon: const Icon(Icons.add_location),
              label: const Text('اختر من مدن ومحافظات مصر'),
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

  // نافذة منبثقة لاختيار مدينة مصرية
  void _showCityPickerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 350,
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
