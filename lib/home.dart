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
  List<dynamic> list = [], listBlackList = [];
  String activeDirectory = "", myBlackList = "";
  final ScrollController _controller = ScrollController();
  final double _height = 70.0;
  int activeBar = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await invokePermission();
      
      //2024-06-01 刪除 -----------------------------
      String blacklist = await Storage.getString("blackList");
      if(blacklist.isNotEmpty) {
        List<String> arr = blacklist.split("''");
        arr[0] = arr[0].substring(1);
        String s2 = arr[arr.length - 1];
        arr[arr.length - 1] = s2.substring(0, s2.length - 1);
        await Storage.remove("blackList");
        await Storage.setJsonList("BlackList", arr); 
      }
      //2024-06-01 刪除 -----------------------------


      listBlackList = await Storage.getJsonList("BlackList");
      

      activeBar = await Storage.getInt("activeBar");
      switchBar();
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

    // listBlackList = await Storage.getJsonList("BlackList");
    // print(listBlackList);
    setTimeout(() => {

    }, 1000);
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  switchBar() async {
    list = [];
    if(activeBar == 0) {
      await initialDirectory();
    } else {
      await initialCollection();
    }
  }

  initialDirectory() async {
    activeDirectory = await Storage.getString("activeDirectory");
    list = await Storage.getJsonList("Directories");
    int activeIndex = -1;
    if(list.isEmpty) {
      await refreshDirectory();        
    } else {
      if(list.length > 10) {
        for(var i = 0; i < list.length; i++) {
          if(activeDirectory == list[i]["path"]){
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
  }

  refreshDirectory() async {
    await EasyLoading.show(status: 'loading...');
    Archive archive = Archive();

    String blackList = "";
    for(var i = 0; i < listBlackList.length; i++) {
      blackList += "'${listBlackList[i]}'";
    }
    print(blackList);

    list = await archive.getDirectories(await Archive.root(), blackList);
    list.sort((a, b) => a["title"].compareTo(b["title"]));
    await Storage.setJsonList("Directories", list); 
    setState(() {});
    await EasyLoading.dismiss();
  }

  initialCollection() async {
    activeDirectory = await Storage.getString("activeCollect");
    // print("activeCollect: ${await Storage.getString("activeCollect")}");
    list = await Storage.getJsonList("Collects");
    if(list.isEmpty) {
      list.add({"title": "我的最愛", "datas": []});
      list.add({"title": "VOA", "datas": []});
      list.add({"title": "日語", "datas": []});
      await Storage.setJsonList("Collects", list);
    } else {
      int activeIndex = -1;

      if(list.length > 10) {
        for(var i = 0; i < list.length; i++) {
          if(activeDirectory == list[i]["title"]){
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
    setState(() {});
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
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text('音樂播放器',
            style: TextStyle( color:Colors.white,)
          ),
          actions: [
            if(activeBar == 0 && myBlackList.isEmpty) // 更新
              IconButton( icon: const Icon( Icons.refresh, color: Colors.white),
                onPressed: () async {
                  await refreshDirectory();
                },
              ),
            if(activeBar == 0 && myBlackList.isNotEmpty) // 取消刪除
              IconButton( icon: const Icon( Icons.cancel, color: Colors.white),
                  onPressed: () async {
                    myBlackList = "";
                    setState(() {});
                  }
              ),
            if(activeBar == 0 && myBlackList.isNotEmpty) // 確定刪除
              IconButton( icon: const Icon( Icons.check_rounded, color: Colors.white),
                onPressed: () async {
                  for(var i = list.length - 1; i >= 0; i--) {
                    // print("'${list[i]["path"]}'");
                    if(myBlackList.contains("'${list[i]["path"]}'")) {
                      listBlackList.add("${list[i]["path"]}");
                      list.removeAt(i);
                    }
                  }
                  await Storage.setJsonList("Directories", list);
                  await Storage.setJsonList("BlackList", listBlackList);
                  myBlackList = "";
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
          child: Container( color: Colors.black87, child: body() ),
        ),
        drawer: drawer(),
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.folder),
              label: "檔案"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.featured_play_list),
              label: "清單"
            ),
          ],
          currentIndex: activeBar,
          selectedItemColor: Colors.amber[800],
          onTap: (int index) {
            activeBar = index;
            Storage.setInt("activeBar", activeBar);
            setState(() {
              switchBar();
            });
          },
       ),
      )
    );
  }

  Drawer drawer() {
    Widget header = Container(
      height: 60,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color:  Colors.deepOrange,
        // border: Border(top: BorderSide(width: 1, color: Colors.deepOrange)), // 藍色邊框
      )
    );

    Widget footer = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(width: 1, color: Colors.deepOrange)), // 藍色邊框
      ),
      child: const Text("JimC, 2024-05-23",
        textAlign: TextAlign.center,
        style: TextStyle(
          // color: Colors.white
          fontSize: 20
        )
      )
    );

    List<Widget> children = [];
    final titles = ['黑名單'];
    for(var i = 0; i < titles.length; i++) {
      children.add(ListTile(
          title: Text(titles[i]),
          onTap: () {
            Navigator.pop(context);
            if(titles[i] == '黑名單') {
              if(activeBar == 0) {
                showBlackList();
              } else {
                alert("請切回檔案頁面");
              }
            }
          }
      ));
    }
    return  Drawer(
      child: Column(
        children: [
          header,
          Expanded(flex: 1,
            child: ListView(
              children: children,
            )
          ),
          footer
        ]
      )
    );
  }

  showBlackList() {
    listBlackList.sort();
    Widget listview =  Container(
      height: 300.0, // Change as per your requirement
      width: 310.0, // Change as per your requirement
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: listBlackList.length,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: Text(listBlackList[index]),
            onTap: () async {
              List arr = listBlackList[index].split("/");
              int count = 0;

              Archive archive = Archive();
              count = (await archive.getFiles(listBlackList[index])).length;

              list.add({"title": arr[arr.length - 1], "path": listBlackList[index], "count": count});
              list.sort((a, b) => a["title"].compareTo(b["title"]));
              await Storage.setJsonList("Directories", list);

              listBlackList.removeAt(index);
              await Storage.setJsonList("BlackList", listBlackList);              
              setState(() { });
              Navigator.of(context).pop();
            },
            // selected: selectedFriends.contains(string),
            // style:  ListTileTheme(selectedColor: Colors.white,),
          );
        },
      ),
    );
    
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      // barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('清單'),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5.0))),
          content: listview,
        );
      }
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
            color: (activeBar == 0 && activeDirectory == list[index]["path"]) 
              ||  (activeBar == 1 && activeDirectory == list[index]["title"]) 
              ? Colors.orange : Colors.transparent,
            border: const Border(bottom: BorderSide(width: 1, color: Colors.deepOrange)), // 藍色邊框
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Material(
                  color: activeDirectory == list[index]["path"] ? Colors.orange : Colors.transparent,
                  child: InkWell (
                    // onLongPress: () {
                    //   alert("longpress");
                    // },
                    onTap: () async {
                      if(activeBar == 1 && list[index]["datas"].length == 0) {
                        alert("沒有檔案");
                        return;
                      }

                      var dirty = await Navigator.pushNamed(context, '/player', arguments: list[index]);

                      activeDirectory = activeBar == 0 ? list[index]["path"] : list[index]["title"];
                      if(activeBar == 0) {
                        await Storage.setString("activeDirectory", activeDirectory);
                      } else {
                        await Storage.setString("activeCollect", activeDirectory);
                      }
                      if(dirty is bool && dirty ) {
                        await initialCollection();
                      } else {
                        setState(() {});
                      }
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
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18
                            )
                          ),
                          if(activeBar == 0 &&list[index]["title"] != "MyTube2" && list[index]["count"] != null)
                            Text("   ${list[index]["count"]}首",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14
                              )
                            ),
                          if(activeBar == 1)
                            Text("   ${list[index]["datas"].length}首",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14
                              )
                            )
                        ]
                      )
                    ),
                  )
                )
              ),
              if(activeBar == 0 && myBlackList.isEmpty)
                IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    myBlackList = path;
                    setState(() { });
                  },
                ),
              if(myBlackList.isNotEmpty && myBlackList.contains(path))
                IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.check_box_rounded, color: Colors.white),
                  onPressed: () {
                    myBlackList = myBlackList.replaceAll(path, "");
                    setState(() { });
                  },
                ),
              if(myBlackList.isNotEmpty && ! myBlackList.contains(path))
                IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.check_box_outline_blank_rounded, color:Colors.white),
                  onPressed: () {
                    myBlackList += path;
                    setState(() { });
                  },
                ),
            ],
          )
        );
      },
    );
  }

  void _animateToIndex(int index) {
    _controller.animateTo(
      (index - 2) * _height,
      duration: const Duration(seconds: 2),
      curve: Curves.fastOutSlowIn,
    );
  }
}
