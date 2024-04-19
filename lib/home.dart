import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:external_path/external_path.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:audio_player/system/system.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool permission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initial();
      
      
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
    // writeFile();
  }

  writeFile() async { // 測好了，可以用
    var path = await ExternalPath.getExternalStorageDirectories();
    var file = File('${path[0]}/counter.txt');

    file.writeAsString('jim'); 
    /* 測好了，可以用
    var path = await ExternalPath.getExternalStorageDirectories();
    print("path: ${path[0]}");
    var path2 = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_MUSIC);
    print("DIRECTORY_MUSIC: ${path2}");
    */
  }

  @override
  void reassemble() async { // develope mode
    super.reassemble();

    Future.delayed(const Duration(milliseconds: 100), () {
    }); 
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  @override
  dispose() {
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }
        // if(await _controller.currentUrl() == "https://m.youtube.com/") {
        //   exit(0);
        // } else {
        // }
      },
      child: Container()
    );
  }

  // Future<List<File>> findMP3Files(String directoryPath) async {
  //   List<File> mp3Files = [];

  //   final Directory directory = Directory(directoryPath);
  //   if (!directory.exists) {
  //     throw Exception('Directory does not exist: $directoryPath');
  //   }

  //   final List<FileSystemEntity> entities = await directory.list();
  //   for (FileSystemEntity entity in entities) {
  //     if (entity is File) {
  //       if (entity.path.endsWith('.mp3')) {
  //         mp3Files.add(entity);
  //       }
  //     } else if (entity is Directory) {
  //       mp3Files.addAll(await findMP3Files(entity.path));
  //     }
  //   }

  //   return mp3Files;
  // }
}
