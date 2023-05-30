import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:tapmetoremember/widgets/widgets.dart';

import '../../constants.dart';
import '../../controllers/reminderController.dart';

class ToDoScreen extends StatefulWidget {
  const ToDoScreen({super.key});

  @override
  State<ToDoScreen> createState() => _ToDoScreenState();
}

DatabaseReference ref = FirebaseDatabase.instance.ref();
DatabaseReference starCountRef = FirebaseDatabase.instance.ref(todo);
DatabaseReference starCountRefTime = FirebaseDatabase.instance.ref(todoTime);
final ReminderController remindersController =
    !Get.isRegistered<ReminderController>()
        ? Get.put(ReminderController())
        : Get.find<ReminderController>();

class _ToDoScreenState extends State<ToDoScreen> {
  @override
  int _counter = 0;
  List<String> listtodo = [];
  var originalListData;
  bool isLoading = false;

  List<String> listtodoTime = [];
  var originalListDataTime;
  bool isLoading1 = false;
  void initState() {
    try {
      starCountRef.onValue.listen((DatabaseEvent event) {
        setState(() {
          isLoading = true;
        });
        final data = event.snapshot.value;
        originalListData = event.snapshot.value.toString();
        listtodo =
            originalListData.toString().split('[')[1].split(']')[0].split(',');
        setState(() {
          isLoading = false;
        });
      });
      starCountRefTime.onValue.listen((DatabaseEvent event) {
        setState(() {
          isLoading1 = true;
        });
        final data = event.snapshot.value;
        originalListDataTime = event.snapshot.value.toString();
        listtodoTime = originalListDataTime
            .toString()
            .split('[')[1]
            .split(']')[0]
            .split(',');
        setState(() {
          isLoading1 = false;
          for (int i = 0; i < listtodoTime.length; i++) {
            setAlarm(i, listtodoTime[i].trimLeft());
          }
        });
      });
    } catch (e) {
      debugPrint("Todo Get $e");
    }
    super.initState();
  }


  setAlarm(int id, String time) async {
    AlarmSettings alarmSettings = AlarmSettings(
      id: id,
      dateTime: DateTime.parse(time),
      assetAudioPath: 'assets/alarm.mp3',
      loopAudio: true,
      vibrate: true,
      fadeDuration: 3.0,
      notificationTitle: name,
      notificationBody: "Reminder",
      enableNotificationOnKill: true,
    );
    await Alarm.set(alarmSettings: alarmSettings);
  }

  void _show(BuildContext ctx) {
    showModalBottomSheet(
        isScrollControlled: true,
        elevation: 5,
        context: ctx,
        builder: (ctx) => Padding(
              padding: EdgeInsets.only(
                  top: 15,
                  left: 15,
                  right: 15,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: remindersController.name,
                    keyboardType: TextInputType.name,
                    decoration:
                        const InputDecoration(labelText: 'What to Remember'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            TimeOfDay? pickedTime = await showTimePicker(
                              initialTime: TimeOfDay.now(),
                              context: context,
                            );
                            if (pickedTime != null) {
                              //'yyyy-MM-dd hh:mm:ss'
                              final now = DateTime.now();
                              DateTime dateTime = DateTime(now.year, now.month,
                                  now.day, pickedTime.hour, pickedTime.minute);
                              var remindertime = dateTime;
                              remindersController.timeSelected.value =
                                  remindertime.toString();
                            } else {
                              print("Date is not selected");
                            }
                          },
                          child: Container(
                              padding: EdgeInsets.all(10),
                              color: AppConstants().blue,
                              child: Text(
                                "Select Time",
                                style: TextStyle(color: AppConstants().white),
                              )),
                        ),
                        Obx(
                          () => Text(remindersController.timeSelected.value !=
                                  "Time"
                              ? DateFormat("hh:mm aaa").format(DateTime.parse(
                                  remindersController.timeSelected.value))
                              : "Time"),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  Center(
                      child: ElevatedButton(
                          onPressed: () {
                            if (remindersController.name.text == "") {
                              var snackdemo = const SnackBar(
                                content: Text("Give Reminder Name"),
                                backgroundColor: Colors.green,
                                elevation: 10,
                                behavior: SnackBarBehavior.floating,
                                margin: EdgeInsets.all(5),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackdemo);
                              debugPrint("Give Reminder Name");
                            } else if (remindersController.timeSelected.value ==
                                "Time") {
                              var snackdemo = const SnackBar(
                                content: Text("Give Reminder Time"),
                                backgroundColor: Colors.green,
                                elevation: 10,
                                behavior: SnackBarBehavior.floating,
                                margin: EdgeInsets.all(5),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackdemo);
                              debugPrint("Give Reminder Time");
                            } else {
                              listtodo.add(remindersController.name.text);
                              listtodoTime
                                  .add(remindersController.timeSelected.value);
                              ref.update({
                                todo: listtodo.toString(),
                                todoTime: listtodoTime.toString(),
                              });
                              remindersController.name.clear();
                              remindersController.timeSelected.value = "Time";
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Submit')))
                ],
              ),
            ));
  }

  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _show(context);
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
      drawer: const DrawerMenu(),
      appBar: AppBar(title: const Text("ToDo")),
      // ignore: unnecessary_null_comparison
      body: listtodo != null
          ? listtodo.isNotEmpty
              ? isLoading == false && isLoading1 == false
                  ? ListView.builder(
                      itemCount: listtodo.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Dismissible(
                            key: const Key('item'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (DismissDirection direction) async {
                              debugPrint(listtodo[index].toString() +
                                  listtodoTime[index].toString());
                              setState(() {
                                listtodo.remove(listtodo[index]);
                                listtodoTime.remove(listtodoTime[index]);
                                ref.update({
                                  todo: listtodo.toString(),
                                  todoTime: listtodoTime.toString(),
                                });
                              });
                            },
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  child: Text(
                                    listtodo[index]
                                        .trimLeft()
                                        .toString()
                                        .substring(0, 1),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20),
                                  ),
                                ),
                                // ignore: unnecessary_null_comparison
                                title: listtodo[index] != null
                                    ? Text(listtodo[index].trimLeft())
                                    : Container(),
                                subtitle: Text(DateFormat("hh:mm aaa").format(
                                    DateTime.parse(
                                        listtodoTime[index].trimLeft()))),
                              ),
                            ));
                      })
                  : const Center(
                      child: CircularProgressIndicator(),
                    )
              : const Center(
                  child: Text("No Data"),
                )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
