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
  List<dynamic> list = [];
  var loadingContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await invokePermission();

      // await Storage.remove("Directories"); // 測試用
      list = await Storage.getJSON("Directories");
      if(list.isEmpty) {
        await refresh();        
      }
      setState(() {});
    });
  }

  invokePermission() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    AndroidDeviceInfo build = await deviceInfoPlugin.androidInfo;
    await [
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
      return status.isGranted;
    }
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

  refresh() async {
    loading(context, onReady: (_) {
      loadingContext = _;      
    });
    Archive archive = Archive();
    list = await archive.getDirectories(await Archive.root()); 
    await Storage.setJSON("Directories", list); 

    if(loadingContext != null) {
      Navigator.pop(loadingContext);
    }
    loadingContext = null;
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
          actions: [
            IconButton( icon: const Icon( Icons.refresh, color: Colors.white),
              onPressed: () async {
                await refresh();
                setState(() {});
              },
            )
          ],
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
        return Container(
          decoration: BoxDecoration(           // 裝飾內裝元件
            // color: Colors.green, // 綠色背景
            border: Border(bottom: BorderSide(width: 1.5, color: Colors.blue.shade100)), // 藍色邊框
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: InkWell (
                onTap: () {
                    Navigator.pushNamed(context, '/player', arguments: list[index]);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Text("${list[index]["title"]}",
                      style: const TextStyle(
                        // color:Colors.white,
                        fontSize: 18
                      )
                    ),
                    
                  ),
                )
              ),
              IconButton(
                iconSize: 20,
                icon: const Icon(Icons.delete),
                onPressed: () {
            
                },
              ),
            ],
          )
        );
      },
    );
  }

}
