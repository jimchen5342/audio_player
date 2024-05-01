import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:audio_player/system/module.dart';

class Player extends StatefulWidget {
  // String directory;
  Player({Key? key}) : super(key: key);
  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver{
  String title = "", path = "", playState = "stop";
  List<String> list = [];
  int active = -1;

  Duration _duration = Duration(seconds: 1000);
  Duration _position = Duration(seconds: 100);

  final methodChannel = const MethodChannel('com.flutter/MethodChannel');
  final eventChannel = const EventChannel('com.flutter/EventChannel');
  StreamSubscription? _streamSubscription;

  // methodChannel.invokeMethod('finish');
  /*
  await methodChannel.invokeMethod('play', {
      "title": download.title,
      "author": download.author,
      "position": ""
    });
    eventChannel.receiveBroadcastStream().listen((data) async {

      });
   */

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 注册监听器
    streamSubscription();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      dynamic arg = ModalRoute.of(context)!.settings.arguments;
      title = arg["title"] as String;
      path = arg["path"] as String;

      // active = await Storage.getString("activeFile");
      Archive archive = Archive();
      list = await archive.getFiles(path);
      setState(() { });
    });
  }
// 
  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  @override
  void reassemble() async { // develope mode
    super.reassemble();
  }

  @override
  dispose() async {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this); // 移除监听器
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if(AppLifecycleState.resumed == state) {
      streamSubscription();
    }
    else if(AppLifecycleState.paused == state) {
      _streamSubscription?.cancel();
      _streamSubscription = null;
      debugPrint("didChangeAppLifecycleState: $state");
    }
  }

  streamSubscription() { // 事件監聽
    _streamSubscription ??= eventChannel.receiveBroadcastStream().listen((data) async {
      var json = jsonDecode(data);
      String action = json["action"] ??= "";
      
      if(action == "play") {
        playState = "play";
        // duration
        // _position = Duration(seconds: 100);
      } else if(action == "pause") {
        playState = "pause";
      } else if(action == "stop") {
        playState = "stop";
        _position = const Duration(seconds: 0);
      }
      if(action.isEmpty) {
        setState(() {});
      }
    });
  }

  backTo() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_sharp,
              color: Colors.white,
            ),
            onPressed: () => backTo(),
          ),
          title: Text(title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle( color:Colors.white,)
          ),
          // actions: [
          //   IconButton( icon: const Icon( Icons.refresh, color: Colors.white),
          //     onPressed: () async {
          //       setState(() {});
          //     },
          //   )
          // ],
          backgroundColor: Colors.deepOrangeAccent, 
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
            child: Container(
              color: Colors.black87,
              child:Column(children: [ 
                Expanded(
                  flex: 1,
                  child: body(),
                ),
                if(active > -1)
                  footer()
              ]
            ),
          ),
        )
      )
    );
  }

  Widget body() {
    return ListView.builder(
      itemCount: list.length,
      itemExtent: 50.0, //强制高度为50.0
      itemBuilder: (BuildContext context, int index) {
        return Container(
          decoration: const BoxDecoration(           // 裝飾內裝元件
            // color: Colors.green, // 綠色背景
            border: Border(bottom: BorderSide(width: 1, color: Colors.deepOrange)), // 藍色邊框
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: InkWell (
                  onTap: () {
                    play(index);
                      // Navigator.pushNamed(context, '/player', arguments: list[index]);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          margin: const EdgeInsets.only(right: 5),
                          // decoration: BoxDecoration(
                              // border: Border.all(width: 1.0, color: Colors.black),
                          // ),
                          child: active != index ? null : const Icon(Icons.play_arrow, size: 20, color: Colors.white),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(list[index],
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              color:Colors.white,
                              fontSize: 16
                            )
                          ),
                        )
                      ]
                    )
                  ),
                )
              ),
            ],
          )
        );
      },
    );
  }

  play(index, {position = 0}) async {
    if(playState == "stop") {
      String root = await Archive.root();
      await methodChannel.invokeMethod('initial', {
        "path": "$root/$path",
        "list": jsonEncode(list)
      });
      print("$root/$path/${list[0]}");
    }
    
    active = index;
    await methodChannel.invokeMethod('play', {
      "song": list[index],
      "position": position
    });
  }
  
  Widget footer() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(           // 裝飾內裝元件
            // color: Colors.green, // 綠色背景
        border: Border(top: BorderSide(width: 1, color: Colors.deepOrange)), // 藍色邊框
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(playState != "play" ? Icons.play_arrow : Icons.pause, 
              size: 30,
              color: Colors.white
            ),
            color:   Colors.black54,
            iconSize: 20,
            onPressed: () async {
              if(playState == "play") {
                String result = await methodChannel.invokeMethod('pause');
              } else {
                play(active, position: _position.inSeconds);
              }
            }
          ),
          Expanded(
            flex: 1,
            child: Slider(
              value: _position.inSeconds.toDouble(),
              min: 0,
              max: _duration.inSeconds.toDouble(),
              label: _position.toString(),
              onChanged: (double value) {
                methodChannel.invokeMethod('seek', {
                  // "title": download.title,
                  // "author": download.author,
                  "position": value
                });
                _position = Duration(seconds: value.toInt());
                setState((){});
              }
            ),
          ),
          if(playState != "stop")
            IconButton(
              icon: const Icon( Icons.stop,  size: 30, color: Colors.white),
              color: Colors.black54,
              iconSize: 20,
              onPressed: () async {
                String result = await methodChannel.invokeMethod('stop');
              }
            ),
        ]
      )
    );
  }
}