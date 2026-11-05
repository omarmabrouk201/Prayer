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
  // خريطة تفصيلية تربط المحافظات بأشهر مدنها وأحياؤها بالإنجليزية للـ API
  final Map<String, List<String>> egyptGovernorates = {
    'Cairo (القاهرة)': ['Cairo', 'Nasr City', 'Heliopolis', 'Maadi', 'Zamalek', 'New Cairo'],
    'Giza (الجيزة)': ['Giza', 'Dokki', 'Mohandessin', 'Sheikh Zayed', '6th of October', 'Haram'],
    'Alexandria (الإسكندرية)': ['Alexandria', 'Borg El Arab', 'Montaza', 'Miami'],
    'Dakahlia (الدقهلية)': ['Mansoura', 'Talkha', 'Mit Ghamr'],
    'Sharqia (الشرقية)': ['Zagazig', 'Minya El Qamh', 'Belbeis'],
    'Qalyubia (القليوبية)': ['Banha', 'Shubra El Kheima', 'Qalyub'],
    'Gharbiya (الغربية)': ['Tanta', 'El Mahalla El Kubra', 'Zefta'],
    'Monufia (الموفية)': ['Shibin El Kom', 'Menouf', 'Sadat City'],
    'Beheira (البحيرة)': ['Damanhour', 'Kafr El Dawwar', 'Rashid'],
    'Kafr El Sheikh (كفر الشيخ)': ['Kafr El Sheikh', 'Desouk', 'Baltim'],
    'Damietta (دمياط)': ['Damietta', 'New Damietta', 'Ras El Bar'],
    'Port Said (بورسعيد)': ['Port Said'],
    'Suez (السويس)': ['Suez'],
    'Ismailia (الإسماعيلية)': ['Ismailia', 'Fayed'],
    'Red Sea (البحر الأحمر)': ['Hurghada', 'Sharm El-Sheikh', 'Safaga', 'Marsa Alam'],
    'Aswan (أسوان)': ['Aswan', 'Kom Ombo', 'Edfu'],
    'Luxor (الأقصر)': ['Luxor'],
    'Qena (قنا)': ['Qena', 'Nag Hammadi'],
    'Sohag (سوهاج)': ['Sohag', 'Girga'],
    'Assiut (أسيوط)': ['Assiut', 'Abnoub'],
    'Minya (المنيا)': ['Minya', 'Mallawi'],
    'Beni Suef (بني سويف)': ['Beni Suef'],
    'Fayoum (الفيوم)': ['Fayoum', 'Bahr Youssef'],
    'Matrouh (مطروح)': ['Marsa Matruh', 'El Alamein', 'Siwa'],
    'New Valley (الوادي الجديد)': ['Kharga', 'Dakhla'],
    'North Sinai (شمال سيناء)': ['Arish', 'Sheikh Zuweid'],
    'South Sinai (جنوب سيناء)': ['El Tor', 'Dahab', 'Nuweiba']
  };

  List<String> savedLocations = ['Dokki', 'Giza', 'Cairo'];
  String selectedLocation = 'Dokki';
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
      savedLocations = prefs.getStringList('saved_locations') ?? ['Dokki', 'Giza', 'Cairo'];
      selectedLocation = prefs.getString('selected_location') ?? 'Dokki';
      isDSTActive = prefs.getBool('dst_active') ?? false;
    });
    fetchPrayerTimes();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_locations', savedLocations);
    await prefs.setString('selected_location', selectedLocation);
    await prefs.setBool('dst_active', isDSTActive);
  }

  Future<void> fetchPrayerTimes() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url = Uri.parse('https://api.aladhan.com/v1/timingsByCity?city=$selectedLocation&country=Egypt&method=5');

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
        _showNotification("تحديث المواقيت", "تم جلب مواقيت الصلاة لمنطقة $selectedLocation بنجاح.");
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
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: savedLocations.contains(selectedLocation) ? selectedLocation : savedLocations.first,
                    items: savedLocations.map((String loc) {
                      return DropdownMenuItem<String>(
                        value: loc,
                        child: Text(loc, style: const TextStyle(fontSize: 18)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedLocation = newValue;
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

            // زر لاختيار المحافظة ثم المدينة/الحي بدقة
            ElevatedButton.icon(
              onPressed: () {
                _showGovernoratesBottomSheet(context);
              },
              icon: const Icon(Icons.location_city),
              label: const Text('اختر المحافظة والحي (مثل الجيزة > الدقي)'),
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
                      'مواقيت الصلاة لمنطقة: $selectedLocation',
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

  // عرض قائمة المحافظات أولاً
  void _showGovernoratesBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر المحافظة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: egyptGovernorates.keys.length,
                  itemBuilder: (context, index) {
                    String govKey = egyptGovernorates.keys.elementAt(index);
                    return ListTile(
                      title: Text(govKey, style: const TextStyle(fontSize: 16)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(context);
                        _showCitiesBottomSheet(context, govKey, egyptGovernorates[govKey]!);
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

  // عرض المدن والأحياء التابعة للمحافظة المختار (مثل الدقي والهرم تحت الجيزة)
  void _showCitiesBottomSheet(BuildContext context, String governorateName, List<String> cities) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختر المدينة / الحي في ($governorateName):', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: cities.length,
                  itemBuilder: (context, index) {
                    String city = cities[index];
                    return ListTile(
                      title: Text(city, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      onTap: () {
                        setState(() {
                          if (!savedLocations.contains(city)) {
                            savedLocations.add(city);
                          }
                          selectedLocation = city;
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
