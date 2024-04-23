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

class _PlayerState extends State<Player> {
  String title = "";
  List<String> list = [];
  int index = -1;
  Duration _duration = Duration(seconds: 1000);
  Duration _position = Duration(seconds: 100);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      dynamic arg = ModalRoute.of(context)!.settings.arguments;
      title = arg["title"] as String;
      String path = arg["path"] as String;

      Archive archive = Archive();
      list = await archive.getFiles("$path");
      setState(() { });
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
  dispose() {
    super.dispose();
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
                      // Navigator.pushNamed(context, '/player', arguments: list[index]);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Text(list[index],
                      style: const TextStyle(
                        // color:Colors.white,
                        fontSize: 18
                      )
                    ),
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

  Widget footer() {
    // _controller!.value.isPlaying ? Icons.pause :
    return Row(
      children: [
        IconButton(
          icon: Icon( Icons.play_arrow, size: 30,),
          color:   Colors.black54,
          iconSize: 20,
          onPressed: () {
            // _controller!.value.isPlaying ? pause() : play();
            setState(() { });
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
              setState(() {
                // _controller!.seekTo(Duration(seconds: value.toInt()));
                // Timer(Duration(milliseconds: 300), () {
                //   _position = _controller!.value.position;
                //   this.widget.onProcessing(_position.inSeconds);
                  this.setState((){});
                });
              }
          ),
        ),

      ]
    );

  }
}