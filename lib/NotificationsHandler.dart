import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path_provider/path_provider.dart';

// Streams are created so that app can respond to notification-related events since the plugin is initialised in the `main` function
final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
BehaviorSubject<ReceivedNotification>();

final BehaviorSubject<String> selectNotificationSubject =
BehaviorSubject<String>();

class ReceivedNotification {
  final int id;
  final String title;
  final String body;
  final String payload;

  ReceivedNotification({
    @required this.id,
    @required this.title,
    @required this.body,
    @required this.payload,
  });
}

class SecondScreen extends StatefulWidget {
  SecondScreen(this.payload);

  final String payload;

  @override
  State<StatefulWidget> createState() => SecondScreenState();
}

class SecondScreenState extends State<SecondScreen> {
  String _payload;
  @override
  void initState() {
    super.initState();
    _payload = widget.payload;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('test')),
      body: Center(
        child: RaisedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('${(_payload ?? '')} Go back!'),
        ),
      ),
    );
  }
}

class NotificationsHandler {
  void _configureDidReceiveLocalNotificationSubject(BuildContext context) {
    didReceiveLocalNotificationSubject.stream
        .listen((ReceivedNotification receivedNotification) async {
      await showDialog(
        context: context,
        builder: (BuildContext contex2) => AlertDialog(
          title: receivedNotification.title != null
              ? Text(receivedNotification.title)
              : null,
          content: receivedNotification.body != null
              ? Text(receivedNotification.body)
              : null,
          actions: [
            FlatButton(
              child: Text('Ok'),
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context2) =>
                        SecondScreen(receivedNotification.payload),
                  ),
                );
              },
            )
          ],
        ),
      );
    });
  }

  void _configureSelectNotificationSubject(BuildContext context) {
    selectNotificationSubject.stream.listen((String payload) async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context2) => SecondScreen(payload)),
      );
    });
  }

  NotificationAppLaunchDetails notificationAppLaunchDetails;
  FirebaseMessaging fcm = FirebaseMessaging();
  StreamSubscription iosSubscription;
  NotificationsHandler();

  initializeFcmNotification(BuildContext context) async {
    _configureDidReceiveLocalNotificationSubject(context);
    _configureSelectNotificationSubject(context);
    fcm.configure(
      onMessage: (Map<String, dynamic> message) async {
        debugPrint("[initializeFcmNotification] onMessage: $message");
        message['data']['callback'] = 'onMessage';
        _showBigTextNotification(message);
      },
      onBackgroundMessage: Platform.isIOS ? null : _myBackgroundMessageHandler,
      onLaunch: (Map<String, dynamic> message) async {
        debugPrint("[initializeFcmNotification] onLaunch: $message");
        // await Navigator.push(
        //   HERE_I_USED_A_STATIC_BUILDCONTEXT_VAR,
        //   MaterialPageRoute(builder: (context2) => SecondScreen('onLaunch')),
        // );
      },
      onResume: (Map<String, dynamic> message) async {
        debugPrint("[initializeFcmNotification] onResume: $message");
        // await Navigator.push(
        //   HERE_I_USED_A_STATIC_BUILDCONTEXT_VAR,
        //   MaterialPageRoute(builder: (context2) => SecondScreen('onResume')),
        // );
      },
    );

    //modify this to have your own app icon
    var initializationSettingsAndroid = AndroidInitializationSettings('ic_launcher_foreground');
    // Note: permissions aren't requested here just to demonstrate that can be done later using the `requestPermissions()` method
    // of the `IOSFlutterLocalNotificationsPlugin` class
    var initializationSettingsIOS = IOSInitializationSettings(
        onDidReceiveLocalNotification:
            (int id, String title, String body, String payload) async {
          didReceiveLocalNotificationSubject.add(ReceivedNotification(
              id: id, title: title, body: body, payload: payload));
        });
    var initializationSettings = InitializationSettings(
       android: initializationSettingsAndroid,iOS: initializationSettingsIOS);
    await FlutterLocalNotificationsPlugin().initialize(initializationSettings,
        onSelectNotification: (String payload) async {
          if (payload != null) {
            debugPrint('notification payload: ' + payload);
          }
          selectNotificationSubject.add(payload);
        });

    if (Platform.isIOS) {
      iosSubscription = fcm.onIosSettingsRegistered.listen((data) {
        // save the token  OR subscribe to a topic here
      });

      fcm.requestNotificationPermissions(IosNotificationSettings());
    } else {
      _saveDeviceToken();
    }
  }

  static Future<dynamic> _myBackgroundMessageHandler(Map<String, dynamic> message) async {
    debugPrint("[myBackgroundMessageHandler] onBackgroundMessage: $message");
    message['data']['callback'] = 'onBackgroundMessage';
    _showBigTextNotification(message);
    // Or do other work.
    return Future<void>.value();
  }

  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    Directory directory = await getTemporaryDirectory();
    var filePath = '${directory.path}/$fileName';
    var response = await get(url);
    var file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  static Future<void> _showBigTextNotification(Map<String, dynamic> message) async {
    var largeIconPath = await _downloadAndSaveFile(
        message['data']['image'], 'largeIcon');
    var bigTextStyleInformation = BigTextStyleInformation(
      '${message['data']['body']}',
      htmlFormatBigText: true,
      contentTitle: '${message['data']['title']}',
      htmlFormatContentTitle: true,
      //summaryText: '$summary',
    );
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      '0',
      '${message['data']['title']}',
      '${message['data']['body']}',
      enableLights: true,
      // color: Color(int.parse(message['data']['mainColor'], radix: 16) + 0xFF000000),
      color: Colors.blue,
      largeIcon: FilePathAndroidBitmap(largeIconPath),
      ledOnMs: 1000,
      ledOffMs: 500,
      importance: Importance.high,
      priority: Priority.high,
      // ledColor: Color(int.parse(message['data']['secondaryColor'], radix: 16)),
      ledColor: Colors.red,
      ticker: 'ticker',
      styleInformation: bigTextStyleInformation,
    );
    var iOSPlatformChannelSpecifics =
    IOSNotificationDetails(attachments: [IOSNotificationAttachment(largeIconPath)]);
    var platformChannelSpecifics =
    NotificationDetails(android:androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);
    await FlutterLocalNotificationsPlugin().show(
        0, '${message['data']['title']}', '${message['data']['body']}', platformChannelSpecifics, payload: message['data']['callback']);
  }

  /// Get the token, save it to the database for current user
  _saveDeviceToken() async {
    print("[_saveDeviceToken] FCM_TOKEN: ${await fcm.getToken()}");
  }

  Future<void> onDidReceiveLocalNotification(
      int id, String title, String body, String payload) async {
    // display a dialog with the notification details, tap ok to go to another page
  }
}