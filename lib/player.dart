import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:audio_player/system/module.dart';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

AudioPlayerHandler? _audioHandler;
List<MediaItem> songs = [];
int spendSeconds = 0, sleepTime = 0;

class Player extends StatefulWidget {
  Player({Key? key}) : super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver{
  String title = "", path = "";
  bool isReady = false;
  int defaultSleepTime = 0, loop = 0;
  final double _height = 70;
  final ScrollController _controller = ScrollController();

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
    WidgetsBinding.instance.addObserver(this);
    spendSeconds = 0;
    sleepTime = 0;
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      dynamic arg = ModalRoute.of(context)!.settings.arguments;
      title = arg["title"] as String; // 目錄名稱
      path = arg["path"] as String;
      setState(() {});

      String active = await Storage.getString("playDirectory");
      defaultSleepTime = await Storage.getInt("sleepTime");
      loop = await Storage.getInt("loop");

      if(songs.isEmpty || active != path || title == "MyTube2") {
        songs = [];
        await initial();
        await Storage.setString("playDirectory", path);
      }
      isReady = true;
      setState(() { });
    });
   
  }

  String trim(String title) {
    List list = ['3gpp', 'webm', 'mp4', 'mp3'];
    for(var i = 0; i < list.length; i++) {
      title = title.replaceAll(".${list[i]}", "");
    }
    return title;
  }

  Future<void> initial() async {
    String root = await Archive.root();
    Archive archive = Archive();
    List<String> list = await archive.getFiles(path);
    final player = AudioPlayer();

    List playlist = [];
    if(title == "MyTube2") {
      PlayList pl = PlayList();
      playlist = await pl.read(root);
    }

    for(var i = 0; i < list.length; i++) {
      var fullName = "$root/$path/${list[i]}";
      if(title == "MyTube2") {
        var f1 = File(fullName);
        print("file: $fullName: ${f1.lengthSync()}");
        if(f1.lengthSync() == 0){
          f1.deleteSync();
          continue;
        }
      }

      var duration = await player.setUrl(fullName);
      String songName = trim(list[i]);
      String author = "";
      if(title == "MyTube2") {
        for(var x = 0; x < playlist.length; x++) {
          var e = playlist[x];
          if(e["audioName"] == fullName) {
            songName = e["title"];
            author = e["author"];
            break;
          }
        }
      } else if(songName.contains("-") && ! songName.contains("=")) {
        List<String> arr = songName.split("-");
        songName = arr[1].trim();
        if(! arr[0].trim().isNumeric()) { // 有可能是數字，不要
          author = arr[0].trim();          
        }
      }

      var item = MediaItem(
        id: fullName,
        title: songName,
        album: title,  // 目錄名稱
        artist: author,
        duration: duration,
      );
      songs.add(item);
    }
    if(songs.isNotEmpty) {
      _audioHandler ??= await AudioService.init(
        builder: () => AudioPlayerHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.flutter.audio_player', // 'com.ryanheise.myapp.channel.audio',
          androidNotificationChannelName: '音樂播放器',
          androidNotificationOngoing: true,
          androidNotificationIcon: "drawable/ic_stat_music_note"
        ),
      );
      
      _audioHandler!.init();
      if(loop == 1) {
        _audioHandler!.setLoopMode(LoopMode.one); // 0 off/1 one/10 all
      }
    }

    return;
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  @override
  void reassemble() async { // develope mode
    super.reassemble();
    // initial();
    _animateToIndex(0);
  }

  @override
  dispose() async {
    super.dispose();
    _controller.dispose();
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
                child: _buildListview(song),
              ),
              if(_audioHandler != null && songs.isNotEmpty)
                _buildSlider(),
              if(_audioHandler != null && songs.isNotEmpty)
                _buildControls(),
            ]),
          );
        }
      );
    } else {
      child = const Center(
        child: CircularProgressIndicator(),
      );
    }

    Widget iconLoop = const Icon(Icons.repeat, color: Colors.white);
    if(loop == 1) {
      iconLoop = const Icon(Icons.repeat_one, color: Colors.white);
    } else if(loop == 10) {
      iconLoop = const Icon(Icons.repeat, color: Colors.white);
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
            style: const TextStyle( color:Colors.white,)
          ),
          actions: [
            if(_audioHandler != null && songs.isNotEmpty)
              _buildPopMenuSleep(),
            if(_audioHandler != null && songs.isNotEmpty)
              IconButton(
                icon: iconLoop,
                onPressed: () async {
                  LoopMode mode = LoopMode.off;
                  if(loop == 0) {
                    loop = 1;
                    mode = LoopMode.one;
                  // } else if(loop == 1) {
                  //   loop = 10;
                  //   mode = LoopMode.all;
                  } else {
                    loop = 0;
                  }
                  _audioHandler!.setLoopMode(mode); // 0 off/1 one/10 all
                  await Storage.setInt("loop", loop);
                  setState(() { });
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
            child: child
        )
      )
    );
  }

  Widget _buildPopMenuSleep() {
    var arr = [5, 10, 15, 20, 25, 30, 45, 60];

    return PopupMenuButton<int>(
      icon: const Icon(Icons.alarm, color: Colors.white),
      offset: const Offset(0, 40),
      itemBuilder: (context) {
        int sub = (sleepTime * 60) - spendSeconds;
        String total = sub == 0 ? ""  : " (${Duration(seconds: sub).format()})";
        return [
          for (var i = 0; i < arr.length; i++)
            CheckedPopupMenuItem<int>(
              value: arr[i],
              checked: sleepTime == arr[i],
              child: Text('${arr[i]} 分鐘${sleepTime == arr[i] ? total : ""}', 
                style: TextStyle(
                  fontSize: 18,
                  color: defaultSleepTime == arr[i] ? Colors.red : Colors.black
                )
              )
            ),
        ];
      },
      onSelected: (int value) {
        sleepTime = sleepTime == value ? 0 : value;
        defaultSleepTime = -1;
        spendSeconds = 0;
        if(sleepTime != 0) {
          Storage.setInt("sleepTime", sleepTime);
        }
      }
    );
  }

  Widget _buildListview(MediaItem song) {
    final queueIndex = songs.indexOf(song);
    _animateToIndex(queueIndex);

    return ListView.builder(
      controller: _controller,
      itemCount: songs.length,
      itemExtent: _height,
      itemBuilder: (BuildContext context, int index) {
        return _buildRow(index, song.id == songs[index].id); 
      },
    );
  }

  Widget _buildRow(int index, bool active) {
    MediaItem song = songs[index];
    var duration = "${song.duration}".split(".")[0];
    if(duration.startsWith("0:")) {
      duration = duration.substring(2);
    }
    Widget widget1 = Container(
      width: 20,
      margin: const EdgeInsets.only(right: 2),
      // decoration: BoxDecoration(
      //   border: Border.all(width: 1.0, color: Colors.white),
      // ),
      child: active 
        ? const Icon(Icons.play_arrow, size: 20, color: Colors.white)
        : Text((index < 9 ? "0" : "") + (index + 1).toString(), 
            textAlign: TextAlign.center,
            style: const TextStyle(color:Colors.grey, fontSize: 12)
          ) 
    );
    Widget widget2 = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(song.title,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: const TextStyle(color:Colors.white, fontSize: 18)
        ),
        if(song.artist != null && song.artist!.isNotEmpty)
          Text("  ${song.artist!}",
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color:Colors.white, fontSize: 12)
          ),
      ]
    );

    return Container(
      decoration: const BoxDecoration(
        // color: Colors.green,
        border: Border(bottom: BorderSide(width: 1, color: Colors.deepOrange)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _audioHandler!.setSong(song);
                  _audioHandler!.play();
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      widget1,
                      Expanded( flex: 1, child: widget2),
                      Padding(padding: const EdgeInsets.only(left: 2.0),
                        child: Text(duration,
                          // softWrap: true,
                          // overflow: TextOverflow.ellipsis,
                          // textDirection: TextDirection.ltr,
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
            )
          )
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

  Widget _buildSlider() {
    return StreamBuilder<Duration>(
      stream: _audioHandler!.currentPosition,
      builder: (context, snapshot) {
        var currentPosition = (snapshot.data ?? const Duration(seconds: 0)).inSeconds.toDouble();
        Duration? duration = _audioHandler!.currentSong.value.duration; 
        final xx = (duration ?? const Duration(seconds: 0)).inSeconds.toDouble();
        if(currentPosition > xx) currentPosition = 0;

        var str = (xx - currentPosition) == 0 ? "" 
          : "-${Duration(seconds: (xx - currentPosition).toInt()).format()}";

        return  Row(
          children: [
            Expanded(flex: 1, 
              child:  Slider(
                value: currentPosition,
                max: xx,
                // divisions: 5,
                // label: currentPosition.format(),
                onChanged: (double value) {
                  setState(() {
                    _audioHandler!.seek(Duration(seconds: value.toInt()));
                  });
                },
              )
            ),
            if(currentPosition > 0)
              Text(str,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                )
              ),
            const SizedBox(width: 10),
            // Text(spendSeconds.toString(),
            //   style: const TextStyle(
            //     color: Colors.red,
            //     fontSize: 20,
            //   )
            // ),
          ]
        );
      }
    );
  }

  void _animateToIndex(int index) {
    if(_controller == null || _controller.positions.isEmpty) return;
    
    final visibleRange = _controller.position.viewportDimension;
    double pos = -1, newPos = index * _height;
    if(newPos < _controller.offset) {
      pos = index * _height;
    } else if(newPos > _controller.offset + visibleRange) {
      pos = index * _height;
    }

    if(pos > -1) {
      _controller.animateTo(pos,
        duration: const Duration(seconds: 2),
        curve: Curves.fastOutSlowIn,
      );      
    }
  }
}

class AudioPlayerHandler extends BaseAudioHandler with QueueHandler {
  final _player = AudioPlayer();
  final currentSong = BehaviorSubject<MediaItem>();
  final currentPosition = BehaviorSubject<Duration>();
  int _oldSeconds = 0;

  void init() async {
    _player.playbackEventStream.listen(_broadcastState);
    currentPosition.add(Duration.zero);

    AudioService.position.listen((Duration position) {
      if(position.inSeconds != _oldSeconds) {
        currentPosition.add(position);
        _oldSeconds = position.inSeconds;

        if(sleepTime != 0) {
          if(spendSeconds >= sleepTime * 60) {
            pause();
            spendSeconds = 0;
          } else if(position.inSeconds > 0) {
            spendSeconds++;
          }
        } 
      }
    });

    if(queue.value.isNotEmpty) {
      stop();
      queue.value.clear();
    }
    queue.add(songs);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) skipToNext();
    });
    if(songs.isNotEmpty) {
      setSong(songs.first);
    }
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _player.setLoopMode(mode);
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

    // print("state: ${event.processingState}, index: $queueIndex / ${songs.length -1}");
    if(event.processingState == ProcessingState.completed && queueIndex == songs.length -1) {
      spendSeconds = 0;
    }
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

class PlayList {

  // PlayList() { }

  Future<List> read(String root) async { 
    String s = "";
    File file = File("$root/MyTube2/playlist.txt");
    if(file.existsSync()) {
      s = file.readAsStringSync();
    }
    List datas = [];
    if(s.isNotEmpty) {
      datas = jsonDecode(s);
    }
    return datas;
  }
}