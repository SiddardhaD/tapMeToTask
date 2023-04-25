import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../main.dart';
class ToLCD extends StatefulWidget {
  const ToLCD({super.key});

  @override
  State<ToLCD> createState() => _ToLCDState();
}

class _ToLCDState extends State<ToLCD> {
  @override
  void initState() {
     readData();
    super.initState();
  }
  @override
  var data;
  List<Widget> messagetextfields = [];
  TextEditingController message = TextEditingController();
  readData() async {
    Stream<DatabaseEvent> stream = ref.onValue;
    stream.listen((DatabaseEvent event) {
      var d = const Duration(seconds: 2);
      Future.delayed(d, () {
        print('Event Type: ${event.type}');
        print('Snapshot: ${event.snapshot.value}');
        if (event.snapshot.child("sendmessage").value != "") {
          setState(() {
            messagetextfields.add(Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.topRight,
                child:
                    Text("Their :${event.snapshot.child("sendmessage").value}"),
              ),
            ));
          });
          ref.update({
            "sendmessage": "",
          });
        }
      });
      setState(() {
        data = "";
      });
    });
  }

  void sendData(String value) async {
    await ref.update({
      "readmessage": value,
    });
    await ref.update({
      "readmessage": "",
    });

    setState(() {
      messagetextfields.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text("me : $value"),
        ),
      ));
    });
    message.clear();
    const snackdemo = SnackBar(
      content: Text('Sent'),
      backgroundColor: Colors.green,
      elevation: 10,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(5),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackdemo);
  }

  Widget build(BuildContext context) {
    return Column(
        // mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Text("Your token $deviceTokenToSendPushNotification"),
          // ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: TextField(
                controller: message,
                obscureText: false,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      onPressed: () {
                        sendData(data);
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
          ),
          // Expanded(
          //     child: ListView.builder(
          //         itemCount: receivedtextfields.length,
          //         itemBuilder: (BuildContext context, int index) {
          //           return Padding(
          //             padding: const EdgeInsets.all(8.0),
          //             child: Align(
          //               alignment: Alignment.topRight,
          //               child: receivedtextfields[index],
          //             ),
          //           );
          //         })),
          Expanded(
              child: ListView.builder(
                  itemCount: messagetextfields.length,
                  itemBuilder: (BuildContext context, int index) {
                    return messagetextfields[index];
                  }))
        ],
      );
  }
}