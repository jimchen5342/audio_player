import 'package:flutter/material.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:audio_player/system/module.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<dynamic> list = [];
  String active = "", blackList = "";
  final ScrollController _controller = ScrollController();
  final double _height = 70.0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await invokePermission();
      active = await Storage.getString("activeDirectory");
      list = await Storage.getJsonList("Directories");
      int activeIndex = -1;
      if(list.isEmpty) {
        await refresh();        
      } else {
        if(list.length > 10) {
          for(var i = 0; i < list.length; i++) {
            if(active == list[i]["path"]){
              activeIndex = i;
              break;
            }
          }
        }
        setState(() {
          if(activeIndex > -1) {
            setTimeout(() => {
              _animateToIndex(activeIndex)
            }, 600);
          }
        });
      }
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
  void reassemble() async { // 測試用, develope mode
    super.reassemble();
    // await Storage.remove("Directories"); // 測試用
    // await Storage.remove("blackList"); // 測試用

    setTimeout(() => {

    }, 1000);
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  refresh() async {
    await EasyLoading.show(status: 'loading...');
    Archive archive = Archive();
    list = await archive.getDirectories(await Archive.root());
    list.sort((a, b) => a["title"].compareTo(b["title"]));
    await Storage.setJsonList("Directories", list); 
    setState(() {});
    await EasyLoading.dismiss();
  }

  @override
  dispose() {
    super.dispose();
    _controller.dispose();
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
            if(blackList.isEmpty)
              IconButton( icon: const Icon( Icons.refresh, color: Colors.white),
                onPressed: () async {
                  await refresh();
                },
              ),
            if(blackList.isNotEmpty)
            IconButton( icon: const Icon( Icons.cancel, color: Colors.white),
                onPressed: () async {
                  blackList = "";
                  setState(() {});
                }
            ),
            if(blackList.isNotEmpty)
              IconButton( icon: const Icon( Icons.check_rounded, color: Colors.white),
                onPressed: () async {
                  for(var i = list.length - 1; i >= 0; i--) {
                    if(blackList.contains("'${list[i]["path"]}'")) {
                      list.removeAt(i);
                    }
                  }
                  await Storage.setJsonList("Directories", list);

                  blackList += await Storage.getString("blackList");
                  await Storage.setString("blackList", blackList);
                  blackList = "";
                  setState(() {});
                },
              ),
          ],
          backgroundColor: Colors.deepOrangeAccent, 
        ),
        body: PopScope(
          canPop: false,
          onPopInvoked: (bool didPop) {
            if (didPop) {
              return;
            }
            backTo();
          },
          child: Container(
            color: Colors.black87,
            child: body()
          ),
        ),
      )
    );
  }

  Widget body() {
    return ListView.builder(
      controller: _controller,
      itemCount: list.length,
      itemExtent: _height, //强制高度
      itemBuilder: (BuildContext context, int index) {
        String path = "'${list[index]["path"]}'";
        return Container(
          decoration: BoxDecoration(
            color: active == list[index]["path"] ? Colors.orange : Colors.transparent,
            border: Border(bottom: BorderSide(width: 1, color: Colors.deepOrange)), // 藍色邊框
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: InkWell (
                onTap: () async {
                    Navigator.pushNamed(context, '/player', arguments: list[index]);
                    active = list[index]["path"];
                    setState(() {});
                    await Storage.setString("activeDirectory", active);
                  },
                  child: Container(
                    padding: const EdgeInsets.only(left: 5),
                    // padding: const EdgeInsets.all(5),
                    // padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${list[index]["title"]}",
                          style: const TextStyle(
                            color: Colors.white, // active == list[index]["path"] ? Colors.white : null,
                            fontWeight: FontWeight.w600,
                            fontSize: 18
                          )
                        ),
                        if(list[index]["count"] != null)
                          Text(list[index]["title"] == "MyTube2" ? "" : "   ${list[index]["count"]}首",
                            style: const TextStyle(
                              color: Colors.white, // active == list[index]["path"] ?Colors.white : null,
                              fontSize: 14
                            )
                          )
                      ]
                    )
                  ),
                )
              ),
              if(blackList.isEmpty)
                IconButton(
                  iconSize: 20,
                  icon: Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    blackList = path;
                    setState(() { });
                  },
                ),
              if(blackList.isNotEmpty && blackList.contains(path))
                IconButton(
                  iconSize: 20,
                  icon: Icon(Icons.check_box_rounded, color: Colors.white),
                  onPressed: () {
                    blackList = blackList.replaceAll(path, "");
                    setState(() { });
                  },
                ),
              if(blackList.isNotEmpty && ! blackList.contains(path))
                IconButton(
                  iconSize: 20,
                  icon: Icon(Icons.check_box_outline_blank_rounded, color:Colors.white),
                  onPressed: () {
                    blackList += path;
                    setState(() { });
                  },
                ),
            ],
          )
        );
      },
    );
  }

  void _animateToIndex(int index) { // 還沒寫
    
    _controller.animateTo(
      (index - 2) * _height,
      duration: const Duration(seconds: 2),
      curve: Curves.fastOutSlowIn,
    );
  }
}
