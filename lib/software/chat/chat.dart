import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:get/get.dart';
import 'package:tapmetoremember/apicalls/apicalls.dart';

import '../../constants.dart';
import '../../controllers/chatController.dart';
import '../../main.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  @override
  void initState() {
    readData();
    super.initState();
  }

  final ChatController controller = !Get.isRegistered<ChatController>()
      ? Get.put(ChatController())
      : Get.find<ChatController>();
  @override
  var data;

  TextEditingController message = TextEditingController();
  readData() async {
    Stream<DatabaseEvent> stream = ref.onValue;
    stream.listen((DatabaseEvent event) {
      print('Event Type: ${event.type}');
      print('Snapshot: ${event.snapshot.value}');
      if (event.snapshot.child(readSms).value != "") {
        setState(() {
          controller.messagetextfields.add(
              ChatBubble(
            clipper: ChatBubbleClipper1(type: BubbleType.receiverBubble),
            backGroundColor: Color(0xffE7E7ED),
            margin: EdgeInsets.only(top: 20),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Text(
                event.snapshot.child(readSms).value.toString(),
                style: TextStyle(color: Colors.black),
              ),
            ),
          ));
        });
        ref.update({
          readSms: "",
        });
      }
    });
    setState(() {
      data = "";
    });
  }

  void sendFcmNotification(String message) async {
    var data = {
      "to": fcmTokenGot,
      "notification": {
        "title": name,
        "body": message,
        "mutable_content": true,
        "sound": "Tri-tone"
      },
      "data": {
        "url": "https://wallpapercave.com/wp/wp11330816.jpg",
        "dl": "<deeplink action on tap of notification>"
      }
    };
    var headers = {
      "Content-Type": "application/json",
      "Authorization": "key=$serverKey"
    };
    ApiServices().post(data, "https://fcm.googleapis.com/fcm/send", headers);
  }


  void sendMessage(String value) async {
    await ref.update({
      sendSms: value,
    });
    await ref.update({
      sendSms: "",
    });

    setState(() {
      controller.messagetextfields.add(
          //   Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Align(
          //     alignment: Alignment.topLeft,
          //     child: Text("me : $value"),
          //   ),
          // )
          ChatBubble(
        clipper: ChatBubbleClipper1(type: BubbleType.sendBubble),
        alignment: Alignment.topRight,
        margin: EdgeInsets.only(top: 20),
        backGroundColor: Colors.blue,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          child: Text(
            value,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ));
    });
    message.clear();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar:  Padding(
          padding: const EdgeInsets.only(left:15,right: 15,bottom: 15),
          child: TextField(
            scrollPadding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 200),
            controller: message,
            obscureText: false,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                  onPressed: () {
                    sendMessage(data);
                    sendFcmNotification(data);
                  },
                  icon: const Icon(
                    Icons.send,
                    color: Colors.black,
                  )),
              labelText: 'Message',
              hintText: 'Enter Message',
            ),
            onChanged: (value) {
              setState(() {
                data = value;
              });
            },
          ),
        ),
      body: Column(
      children: <Widget>[
        Expanded(
            child: ListView.builder(
                itemCount: controller.messagetextfields.length,
                itemBuilder: (BuildContext context, int index) {
                  return controller.messagetextfields[index];
                }))
      ],
    ),);
  }
}
