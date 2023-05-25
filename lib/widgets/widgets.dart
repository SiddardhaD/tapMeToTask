import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../software/profile/profile.dart';
import '../software/todo/todo.dart';

class DrawerMenu extends StatelessWidget {
  const DrawerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
      UserAccountsDrawerHeader(
        // <-- SEE HERE
        decoration: BoxDecoration(color: const Color(0xff764abc)),
        accountName: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        accountEmail: const Text(
          "pinkesh.earth@gmail.com",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        currentAccountPicture: FlutterLogo(),
      ),
      ListTile(
        leading: Icon(
          Icons.home,
        ),
        title: const Text('ToDo'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ToDoScreen()),
          );
        },
      ),
      ListTile(
        leading: const Icon(
          Icons.person,
        ),
        title: const Text('Profile'),
        onTap: () {
          Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfileScreen()),
                  );
        },
      ),
    ]));
  }
}
