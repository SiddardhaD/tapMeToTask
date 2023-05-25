import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:tapmetoremember/widgets/widgets.dart';

import '../../constants.dart';

class ToDoScreen extends StatefulWidget {
  const ToDoScreen({super.key});

  @override
  State<ToDoScreen> createState() => _ToDoScreenState();
}

DatabaseReference ref = FirebaseDatabase.instance.ref();
DatabaseReference starCountRef = FirebaseDatabase.instance.ref(todo);

class _ToDoScreenState extends State<ToDoScreen> {
  @override
  int _counter = 0;
  Object listtodo = {};
  var listData;
  bool isLoading = false;
  void initState() {
    try {
      starCountRef.onValue.listen((DatabaseEvent event) {
        setState(() {
          isLoading = true;
        });
        final data = event.snapshot.value;
        listData = event.snapshot.value;
        listtodo = data! ;
        debugPrint("TODO data is $data");
        setState(() {
          isLoading = false;
        });
      });
    } catch (e) {
      debugPrint("Todo Get $e");
    }

    super.initState();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
      drawer: const DrawerMenu(),
      appBar: AppBar(title: const Text("ToDo")),
      body: listData.length > 0
          ? isLoading == false
              ? ListView.builder(
                  itemCount: listData.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Text(
                            listData["data${index+1}"].toString().substring(0,1),
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20),
                          ),
                        ),
                        title: Text(listData["data${index+1}"]),
                        subtitle: Text('Australia'),
                      ),
                    );
                  })
              : const Center(
                  child: CircularProgressIndicator(),
                )
          : const Center(
              child: Text("No Data"),
            ),
    );
  }
}
