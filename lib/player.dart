import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:audio_player/system/module.dart';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

AudioPlayerHandler? _audioHandler;
List<MediaItem> songs = [];

class Player extends StatefulWidget {
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      dynamic arg = ModalRoute.of(context)!.settings.arguments;
      title = arg["title"] as String;
      path = arg["path"] as String;
      initial();
    });
  }

  initial() async {
    String root = await Archive.root();
    Archive archive = Archive();
    list = await archive.getFiles(path);
    for(var i = 0; i < list.length; i++) {
      var item = MediaItem(
        id: "$root/$path/${list[i]}",
        title: list[i].replaceAll(".mp3", "").replaceAll(".mp4", ""),
        album: title,
        // artist: 'Artist name',
        // duration: const Duration(milliseconds: 123456),
        // artUri: Uri.parse('https://example.com/album.jpg'),
      );
      songs.add(item);
    }
    
    _audioHandler ??= await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ryanheise.myapp.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
      ),
    );
    _audioHandler!.init();
    setState(() { });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  @override
  void reassemble() async { // develope mode
    super.reassemble();
    // initial();
  }

  @override
  dispose() async {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this); // 移除监听器
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if(AppLifecycleState.resumed == state) {
    }
    else if(AppLifecycleState.paused == state) {
      debugPrint("didChangeAppLifecycleState: $state");
    }
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


class AudioPlayerHandler extends BaseAudioHandler with QueueHandler {
  final _player = AudioPlayer();
  final currentSong = BehaviorSubject<MediaItem>();

  void init() {
    _player.playbackEventStream.listen(_broadcastState);
    queue.add(songs!);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) skipToNext();
    });

    setSong(songs!.first);
  }

  Future<void> setSong(MediaItem song) async {
    currentSong.add(song);
    mediaItem.add(song);
    await _player.setAudioSource(
      ProgressiveAudioSource(Uri.parse(song.id)), // 
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await playbackState.firstWhere(
        (state) => state.processingState == AudioProcessingState.idle);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index <= 0 || index >= queue.value.length) {
      // TODO: remove this when QueueHandler._skip is fixed
      return;
    }
    // await setSong(_songs![index]);
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final queueIndex = songs!.indexOf(currentSong.value);
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: queueIndex,
    ));
  }
}
