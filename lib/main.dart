import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:home_widget/home_widget.dart';
import 'package:tapmetoremember/constants.dart';
import 'package:tapmetoremember/software/chat/chat.dart';
import 'package:tapmetoremember/software/notifications/notifications.dart';
import 'package:tapmetoremember/software/splash.dart';
import 'package:tapmetoremember/widgets/widgets.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import 'hardware/toLCDscreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerBackgroundCallback(backgroundCallback);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Alarm.init();
  await setupFlutterNotifications();
  runApp(const MyApp());
}

Future<void> backgroundCallback(Uri? uri) async {
  if (uri!.host == 'updatecounter') {
    int? _counter;
    await HomeWidget.getWidgetData<int>('_counter', defaultValue: 0)
        .then((value) {
      _counter = value!;
      _counter = _counter! + 1;
    });
    await HomeWidget.saveWidgetData<int>('_counter', _counter);
    await HomeWidget.updateWidget(
        name: 'AppWidgetProvider', iOSName: 'AppWidgetProvider');
  }
}

late AndroidNotificationChannel channel;

bool isFlutterLocalNotificationsInitialized = false;
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) {
    return;
  }
  channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Create an Android Notification Channel.
  ///
  /// We use this channel in the `AndroidManifest.xml` file to override the
  /// default FCM channel to enable heads up notifications.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  /// Update the iOS foreground notification presentation options to allow
  /// heads up notifications.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  isFlutterLocalNotificationsInitialized = true;
}

FirebaseDatabase database = FirebaseDatabase.instance;
DatabaseReference ref = FirebaseDatabase.instance.ref();
String deviceTokenToSendPushNotification = "";

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Code',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
    );
  }
}

List<Widget> receivedtextfields = [];
List<Widget> sendtextfields = [];

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    getDeviceTokenToSendNotification();
    getLocation();
    readFcmTokenData();
    firebaseInit();
    super.initState();
  }

  getLocation() async {
    try {
      var location = await determinePosition();
      debugPrint("Location Fetced");
      try {
        await flutterBackgroundInit();
      } catch (e) {
        debugPrint(e.toString());
      }
    } catch (e) {
      debugPrint("Locarion fetcg $e");
    }
  }

  Future<void> flutterBackgroundInit() async {
    // final service = FlutterBackgroundService();
    // await service.configure(
    //   androidConfiguration: AndroidConfiguration(
    //     onStart: onStart,
    //     autoStart: true,
    //     isForegroundMode: true,
    //   ),
    //   iosConfiguration: IosConfiguration(
    //     autoStart: true,
    //     onForeground: onStart,
    //     onBackground: onIosBackground,
    //   ),
    // );
    FirebaseMessaging.onMessage.listen(showFlutterNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    });
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        // notificationChannelId: 'my_foreground',
        // initialNotificationTitle: 'AWESOME SERVICE',
        // initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    service.startService();
  }

  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  String? _token;
  String? initialMessage;
  bool _resolved = false;
  firebaseInit() {
    // FirebaseMessaging.instance.getInitialMessage().then(
    //       (value) => setState(
    //         () {
    //           _resolved = true;
    //           initialMessage = value?.data.toString();
    //         },
    //       ),
    //     );

    FirebaseMessaging.onMessage.listen(showFlutterNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      // Navigator.pushNamed(
      //   context,
      //   '/message',
      //   arguments: MessageArguments(message, true),
      // );
    });
  }

  Future<void> sendPushMessage() async {
    if (_token == null) {
      print('Unable to send FCM message, no token exists.');
      return;
    }

    try {
      await http.post(
        Uri.parse('https://api.rnfirebase.io/messaging/send'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: constructFCMPayload(_token),
      );
      print('FCM request for device sent!');
    } catch (e) {
      print(e);
    }
  }

  int _messageCount = 0;

  String constructFCMPayload(String? token) {
    _messageCount++;
    return jsonEncode({
      'token': token,
      'data': {
        'via': 'FlutterFire Cloud Messaging!!!',
        'count': _messageCount.toString(),
      },
      'notification': {
        'title': 'Hello FlutterFire!',
        'body': 'This notification (#$_messageCount) was created via FCM!',
      },
    });
  }

  Future<void> onActionSelected(String value) async {
    switch (value) {
      case 'subscribe':
        {
          print(
            'FlutterFire Messaging Example: Subscribing to topic "fcm_test".',
          );
          await FirebaseMessaging.instance.subscribeToTopic('fcm_test');
          print(
            'FlutterFire Messaging Example: Subscribing to topic "fcm_test" successful.',
          );
        }
        break;
      case 'unsubscribe':
        {
          print(
            'FlutterFire Messaging Example: Unsubscribing from topic "fcm_test".',
          );
          await FirebaseMessaging.instance.unsubscribeFromTopic('fcm_test');
          print(
            'FlutterFire Messaging Example: Unsubscribing from topic "fcm_test" successful.',
          );
        }
        break;

      default:
        break;
    }
  }

  void showFlutterNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    if (notification != null && android != null && !kIsWeb) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: 'logo',
          ),
        ),
      );
    }
  }

  Future<void> getDeviceTokenToSendNotification() async {
    final FirebaseMessaging _fcm = FirebaseMessaging.instance;
    final token = await _fcm.getToken();
    setState(() {
      deviceTokenToSendPushNotification = token.toString();
    });

    sendTokenValue();
    debugPrint("Token Value: $deviceTokenToSendPushNotification");
  }

  sendTokenValue() async {
    await ref.update({
      fcmtoken: deviceTokenToSendPushNotification,
    });
  }

  readFcmTokenData() async {
    Stream<DatabaseEvent> stream = ref.onValue;
    stream.listen((DatabaseEvent event) {
      print('Event Type: ${event.type}');
      print('Snapshot: ${event.snapshot.value}');
      if (event.snapshot.child(readfcmtoken).value != "") {
        setState(() {
          debugPrint("${event.snapshot.child(readfcmtoken).value}");
          fcmTokenGot = event.snapshot.child(readfcmtoken).value.toString();
        });
      }
    });
  }

  final pages = [
    const Chat(),
    const Notifications(),
    const ToLCD(),
  ];
  var currentIndex = 0;
  changeIndex(int index) {
    setState(() {
      pages[index];
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        drawer: const DrawerMenu(),
        appBar: AppBar(
          // leading: const Icon(Icons.connect_without_contact_rounded),

          title: Text(widget.title),
          actions: [
            IconButton(onPressed: (){
              showAlert(context);
            }, icon: const Icon(Icons.post_add))
            // IconButton(
            //     onPressed: () {
            //       Navigator.push(
            //         context,
            //         MaterialPageRoute(
            //             builder: (context) => const ProfileScreen()),
            //       );
            //     },
            //     icon: const Icon(Icons.person))
          ],
        ),
        body: pages[currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor:
              currentIndex == 0 ? AppConstants().blue : AppConstants().grey,
          type: BottomNavigationBarType.fixed,
          onTap: (value) => changeIndex(value),
          items: [
            BottomNavigationBarItem(
              label: "Home",
              icon: Icon(
                Icons.chat,
                color: currentIndex == 0
                    ? AppConstants().blue
                    : AppConstants().grey,
              ),
            ),
            BottomNavigationBarItem(
              label: "Notifications",
              icon: Icon(
                Icons.notification_important_outlined,
                color: currentIndex == 1
                    ? AppConstants().blue
                    : AppConstants().grey,
              ),
            ),
            BottomNavigationBarItem(
              label: "Live",
              icon: Icon(
                Icons.screenshot_monitor_outlined,
                color: currentIndex == 2
                    ? AppConstants().blue
                    : AppConstants().grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
Future<void> showAlert(BuildContext context) async {
  final TextEditingController txtMessage = TextEditingController();
  showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
            child: Container(
          width: MediaQuery.of(context).size.width - 10,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: Colors.blue,
                width: 3,
              )),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                height: MediaQuery.of(context).size.width/7,
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(0),
                      topRight: Radius.circular(0),
                    ),
                    border: Border.all(
                      color: Colors.blue,
                      width: 1,
                    )),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Story",style: TextStyle(color: AppConstants().white),),
                      GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Icon(
                            Icons.cancel,
                            color: Colors.white,
                            size: 25,
                          ))
                    ],
                  ),
                )),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: TextFormField(
                    style: const TextStyle(height: 1, color: Colors.black),
                    controller: txtMessage,
                    readOnly: false,
                    keyboardType: TextInputType.text,
                    maxLines: 6,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9.0),
                          borderSide:
                              const BorderSide(color: Color(0xFFAAAAAA))),
                      hintText: "Write Something here",
                      hintStyle: TextStyle(color: AppConstants().black),
                      filled: true,
                      fillColor: Colors.transparent,
                      //contentPadding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
                      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Message is required';
                      }
                      return null;
                    }),
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.width/25,
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 20, right: 20, top: 5, bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      txtMessage.clear();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width / 3.5,
                      height: MediaQuery.of(context).size.width / 9,
                      decoration: BoxDecoration(
                          color: const Color(0xFFD9D9D9),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(0xFFD9D9D9),
                            width: 1,
                          )),
                      child: const Center(
                        child:
                             Text("Cancel"),
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await ref.update({
                        storySend: txtMessage.text,
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width / 3.5,
                      height: MediaQuery.of(context).size.width / 9,
                      decoration: BoxDecoration(
                          color: const Color(0xFFD9D9D9),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(0xFFD9D9D9),
                            width: 1,
                          )),
                      child: const Center(
                        child: Text("Post On Top"),
                      ),
                    ),
                  )
                ],
              ),
            )
          ]),
        ));
      });
}


@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
  
  // bring to foreground
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    Future<String> str = readStory();
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: partnerName,
          content: await str,
        );
      }
    }
    debugPrint('FLUTTER BACKGROUND SERVICE IS ON');
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
 Future<String> readStory() async{
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
    Stream<DatabaseEvent> stream = ref.onValue;
    var data = await ref.child(story).get();
    return data.value.toString();
  }