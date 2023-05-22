import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';
import 'package:tapmetoremember/constants.dart';
import 'package:tapmetoremember/software/chat/chat.dart';
import 'package:tapmetoremember/software/notifications/notifications.dart';
import 'package:tapmetoremember/software/profile/profile.dart';
import 'package:tapmetoremember/software/splash.dart';
import 'package:tapmetoremember/widgets/widgets.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'hardware/toLCDscreen.dart';
import 'login/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerBackgroundCallback(backgroundCallback);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
    readFcmTokenData();
    firebaseInit();
    super.initState();
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
            // TODO add a proper drawable resource to android, for now using
            //      one that already exists in example app.
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
            IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfileScreen()),
                  );
                },
                icon: const Icon(Icons.person))
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
