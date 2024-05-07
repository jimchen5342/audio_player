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
  String title = "", path = "";
  Duration _position = Duration(seconds: 0);
  bool isReady = false;
  

  Widget _button(IconData iconData, VoidCallback onPressed, {bool visible = true}){
    Widget btn = IconButton(
      icon: Icon(iconData, color: Colors.white, size: 30),
      onPressed: onPressed,
    );

    return Container(
      width: 60,
      height: 60,
      // decoration: BoxDecoration(
      //   border: Border.all(color: Colors.blueAccent),
      //   borderRadius: BorderRadius.circular(10),
      // ),
      child: visible ? btn : null
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 注册监听器

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      dynamic arg = ModalRoute.of(context)!.settings.arguments;
      title = arg["title"] as String;
      path = arg["path"] as String;
      setState(() {});
      String active = await Storage.getString("playDirectory");
      if(songs.isEmpty || active != path) {
        songs = [];
        initial();
        await Storage.setString("playDirectory", path);
      } else {
        isReady = true;
        setState(() {});
      }
    });
    AudioService.position.listen((Duration position) { // 還沒測
      _position = position;
      print("position: $_position");
    });
  }

  initial() async {
    String root = await Archive.root();
    Archive archive = Archive();
    List<String> list = await archive.getFiles(path);
    final player = AudioPlayer();
    for(var i = 0; i < list.length; i++) {
      var fullName = "$root/$path/${list[i]}";
      var duration = await player.setUrl(fullName);
    
      var item = MediaItem(
        id: fullName,
        title: list[i].replaceAll(".mp3", "").replaceAll(".mp4", ""),
        album: title,
        duration: duration,
      );
      songs.add(item);
    }
    
    _audioHandler ??= await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.flutter.audio_player', // 'com.ryanheise.myapp.channel.audio',
        androidNotificationChannelName: '音樂播放器',
        androidNotificationOngoing: true,
      ),
    );
    _audioHandler!.init();
    isReady = true;
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
    final Widget child;
    if(isReady) {
      child = StreamBuilder<MediaItem?>(
      stream: _audioHandler!.currentSong,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }
        final song = snapshot.data!;

        return Container(
          color: Colors.black87,
          child: Column(children: [ 
              Expanded(
                flex: 1,
                child: body(song),
              ),
              if(_audioHandler != null && songs.isNotEmpty)
                _buildControls(),
            ]
          ),
        );
      });
    } else {
      child = const Center(
        child: CircularProgressIndicator(),
      );
    }
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
        body: PopScope(
            canPop: false,
            onPopInvoked: (bool didPop) {
              if (didPop) {
                return;
              }
              backTo();
            },
            child: child
        )
      )
    );
  }

  Widget body(MediaItem song) {
    return ListView.builder(
      itemCount: songs.length,
      itemExtent: 50.0, //强制高度为50.0
      itemBuilder: (BuildContext context, int index) {
        return _buildRow(songs[index], song.id == songs[index].id); 
      },
    );
  }

  Widget _buildRow(MediaItem song, bool active) {
    var duration = "${song.duration}".split(".")[0];
    if(duration.startsWith("0:")) {
      duration = duration.substring(2);
    }
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
                _audioHandler!.setSong(song);
                _audioHandler!.play();
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
                      child:! active ? null : const Icon(Icons.play_arrow, size: 20, color: Colors.white),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(song.title,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color:Colors.white,
                          fontSize: 18
                        )
                      ),
                    ),
                    Padding(padding: const EdgeInsets.only(left: 8.0),
                      child: Text(duration,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color:Colors.white,
                          fontSize: 14
                        )
                      )
                    )
                  ]
                )
              ),
            )
          ),
        ],
      )
    );
  }
  
  Widget _buildControls() {
    return StreamBuilder<bool>(
      stream: _audioHandler!.playbackState.map((state) => state.playing).distinct(),
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;
        final queueIndex = songs.indexOf(_audioHandler!.currentSong.value);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _button(Icons.skip_previous, _audioHandler!.skipToPrevious, visible: queueIndex > 0),
            if (playing)
              _button(Icons.pause, _audioHandler!.pause)
            else
              _button(Icons.play_arrow, _audioHandler!.play),
            _button(Icons.stop, _audioHandler!.stop),
            _button(Icons.skip_next, _audioHandler!.skipToNext, visible: queueIndex < songs.length -1),
          ],
        );
      },
    );
  }

  Future<void> sleepAndStop() async { // 還沒試
    await Future.delayed(const Duration(minutes: 10));
    _audioHandler?.stop();
  }
}

class AudioPlayerHandler extends BaseAudioHandler with QueueHandler {
  final _player = AudioPlayer();
  final currentSong = BehaviorSubject<MediaItem>();

  void init() async {
    _player.playbackEventStream.listen(_broadcastState);
    if(queue.value.isNotEmpty) {
      stop();
      queue.value.clear();
    }
    
    queue.add(songs);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) skipToNext();
    });

    setSong(songs.first);
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
    if (index < 0 || index >= queue.value.length) {
      return;
    }
    await setSong(songs[index]);
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    
    final queueIndex = songs.indexOf(currentSong.value);
  
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
