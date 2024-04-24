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
  String title = "", playState = "stop";
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
      String path = arg["path"] as String;


      // active = await Storage.getString("activeFile");
      Archive archive = Archive();
      list = await archive.getFiles(path);

      setState(() { });

      String root = await Archive.root();
      await methodChannel.invokeMethod('initital', {
        "path": "$root/$path",
        "list": jsonEncode(list)
      });
    });
  }

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
      if(action == "start") {
        playState = "play";
        _position = Duration(seconds: 0);
      } else if(action == "play") {
        playState = "play";
        _position = Duration(seconds: 100);
      } else if(action == "pause") {
        playState = "pause";
      } else if(action == "stop") {
        playState = "stop";
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
            style: TextStyle( color:Colors.white,)
          ),
          // actions: [
          //   IconButton( icon: const Icon( Icons.refresh, color: Colors.white),
          //     onPressed: () async {
          //       setState(() {});
          //     },
          //   )
          // ],
          backgroundColor: Colors.blueAccent, 
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
            child: Column(children: [ 
              Expanded(
                flex: 1,
                child: body(),
              ),
              if(active > -1)
                footer()
            ],),
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
                          child: active != index ? null : Icon(Icons.play_arrow, size: 20),
                        ),
                        Text(list[index],
                          style: const TextStyle(
                            // color:Colors.white,
                            fontSize: 18
                          )
                        ),
                      ]
                    )
                  ),
                )
              ),
              // IconButton(
              //   iconSize: 20,
              //   icon: const Icon(Icons.delete),
              //   onPressed: () {
            
              //   },
              // ),
            ],
          )
        );
      },
    );
  }

  play(index) async {
    active = index;
    _position = const Duration(seconds: 0);
    await methodChannel.invokeMethod('play', {
      // "title": download.title,
      // "author": download.author,
      "mp3": list[index],
      "position": 0
    });
    setState(() {});
  }
  
  Widget footer() {
    // _controller!.value.isPlaying ? Icons.pause :
    return Row(
      children: [
        IconButton(
          icon: Icon(playState == "pause" ? Icons.play_arrow : Icons.pause, 
            size: 30,),
          color:   Colors.black54,
          iconSize: 20,
          onPressed: () {
            if(playState == "pause") {
              methodChannel.invokeMethod('play');
            } else {
              methodChannel.invokeMethod('pause');
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
        if(playState == "play")
          IconButton(
            icon: const Icon( Icons.stop,  size: 30,),
            color: Colors.black54,
            iconSize: 20,
            onPressed: () {
              // _controller!.value.isPlaying ? pause() : play();
              methodChannel.invokeMethod('stop');
            }
          ),
      ]
    );
  }
}