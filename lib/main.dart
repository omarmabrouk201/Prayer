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
  // خريطة المحافظات والأحياء بالعربي بالكامل (الاسم العربي والاسم الإنجليزي المقابل للـ API)
  final Map<String, Map<String, String>> egyptData = {
    'القاهرة': {
      'القاهرة (المركز)': 'Cairo',
      'مدينة نصر': 'Nasr City',
      'مصر الجديدة': 'Heliopolis',
      'المعادي': 'Maadi',
      'الزمالك': 'Zamalek',
      'التجمع الخامس': 'New Cairo'
    },
    'الجيزة': {
      'الجيزة (المركز)': 'Giza',
      'الدقي': 'Dokki',
      'المهندسين': 'Mohandessin',
      'الشيخ زايد': 'Sheikh Zayed',
      '6 أكتوبر': '6th of October',
      'الهرم': 'Haram'
    },
    'الإسكندرية': {
      'الإسكندرية (المركز)': 'Alexandria',
      'برج العرب': 'Borg El Arab',
      'المتزه': 'Montaza',
      'ميامي': 'Miami'
    },
    'الدقهلية': {
      'المنصورة': 'Mansoura',
      'طلخا': 'Talkha',
      'ميت غمر': 'Mit Ghamr'
    },
    'الشرقية': {
      'الزقازيق': 'Zagazig',
      'منيا القمح': 'Minya El Qamh',
      'بلبيس': 'Belbeis'
    },
    'القليوبية': {
      'بنها': 'Banha',
      'شبرا الخيمة': 'Shubra El Kheima'
    },
    'الغربية': {
      'طنطا': 'Tanta',
      'المحلة الكبرى': 'El Mahalla El Kubra'
    },
    'أسوان': {
      'أسوان': 'Aswan',
      'كوم أمبو': 'Kom Ombo'
    },
    'الأقصر': {
      'الأقصر': 'Luxor'
    },
    'بورسعيد': {
      'بورسعيد': 'Port Said'
    },
    'السويس': {
      'السويس': 'Suez'
    }
  };

  String selectedGovernorate = 'الجيزة';
  String selectedCityArabic = 'الدقي';
  String selectedCityApi = 'Dokki';
  
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
      selectedGovernorate = prefs.getString('selected_gov') ?? 'الجيزة';
      selectedCityArabic = prefs.getString('selected_city_ar') ?? 'الدقي';
      selectedCityApi = prefs.getString('selected_city_api') ?? 'Dokki';
      isDSTActive = prefs.getBool('dst_active') ?? false;
    });
    fetchPrayerTimes();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_gov', selectedGovernorate);
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
            // عرض المنطقة الحالية المتاحة
            Card(
              elevation: 3,
              child: ListTile(
                title: Text('المحافظة: $selectedGovernorate', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('المنطقة/المدينة: $selectedCityArabic'),
                trailing: ElevatedButton(
                  onPressed: () => _showGovernoratesDialog(context),
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
              Text(errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            else if (prayerTimes != null)
              Expanded(
                child: ListView(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'مواقيت الصلاة ($selectedCityArabic):',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: fetchPrayerTimes,
                        ),
                      ],
                    ),
                    const Divider(),
                    ListTile(title: const Text('الفجر (Fajr)'), trailing: Text(prayerTimes!['Fajr'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('الشروق (Sunrise)'), trailing: Text(prayerTimes!['Sunrise'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('الظهر (Dhuhr)'), trailing: Text(prayerTimes!['Dhuhr'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('العصر (Asr)'), trailing: Text(prayerTimes!['Asr'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('المغرب (Maghrib)'), trailing: Text(prayerTimes!['Maghrib'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('العشاء (Isha)'), trailing: Text(prayerTimes!['Isha'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // نافذة اختيار المحافظات بالعربي
  void _showGovernoratesDialog(BuildContext context) {
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
                  itemCount: egyptData.keys.length,
                  itemBuilder: (context, index) {
                    String gov = egyptData.keys.elementAt(index);
                    return ListTile(
                      title: Text(gov, style: const TextStyle(fontSize: 16)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(context);
                        _showCitiesDialog(context, gov);
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

  // نافذة اختيار المدن والأحياء التابعة للمحافظة بالعربي
  void _showCitiesDialog(BuildContext context, String gov) {
    Map<String, String> citiesMap = egyptData[gov]!;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختر المدينة أو الحي في ($gov):', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: citiesMap.length,
                  itemBuilder: (context, index) {
                    String cityAr = citiesMap.keys.elementAt(index);
                    String cityApi = citiesMap[cityAr]!;
                    return ListTile(
                      title: Text(cityAr, style: const TextStyle(fontSize: 16)),
                      onTap: () {
                        setState(() {
                          selectedGovernorate = gov;
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
