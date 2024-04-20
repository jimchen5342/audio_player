import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:audio_player/system/system.dart';
import 'package:audio_player/system/archive.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool permission = false;
  List<dynamic> list = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initial();
      if(permission) {
        Archive archive = Archive();
        list = await archive.getDirectories();        
      } else {
        exit(0);
      }
    });
  }

  initial() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    AndroidDeviceInfo build = await deviceInfoPlugin.androidInfo;

    Map<Permission, PermissionStatus> statuses = await [
          build.version.sdkInt < 30 
          ? Permission.storage
          : Permission.manageExternalStorage
    ].request();
    var status = build.version.sdkInt < 30 
      ? await Permission.storage.status
      : await Permission.manageExternalStorage.status;
    if(! status.isGranted) {
      exit(0);
    } else {
      permission = status.isGranted;
    }
  }

  @override
  void reassemble() async { // develope mode
    super.reassemble();

    Future.delayed(const Duration(milliseconds: 100), () {
    }); 

    Archive archive = Archive();
    list = await archive.getDirectories();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  @override
  dispose() {
    super.dispose();
  }
  backTo(){
    exit(0);
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          // leading: IconButton(
          //   icon: const Icon(
          //     Icons.arrow_back_ios_sharp,
          //     color: Colors.white,
          //   ),
          //   onPressed: () => backTo(),
          // ),
          title: const Text('音樂播放器',
            style: TextStyle( color:Colors.white,)
          ),
          // actions: [
          //   IconButton( icon: Icon( Icons.menu, color: Colors.white),
          //     onPressed: () {
          //       setup();
          //     },
          //   )
          // ],
          backgroundColor: Colors.blue, 
        ),
        body:
          PopScope(
              canPop: false,
              onPopInvoked: (bool didPop) {
                if (didPop) {
                  return;
                }
                backTo();
              },
              child: body(),
            ),
      )
    );
  }

  Widget body() {
    return ListView.builder(
      itemCount: list.length,
      // itemExtent: 50.0, //强制高度为50.0
      itemBuilder: (BuildContext context, int index) {
        return InkWell(
            child: Text("${list[index]["title"]}"),
            onTap: () => {

            }
          );

      },
    );
  }
}
