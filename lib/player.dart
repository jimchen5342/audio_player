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
int spendSeconds = 0, sleepTime = 30;

class Player extends StatefulWidget {
  Player({Key? key}) : super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver{
  String title = "", path = "", mode = "Directory", marked = "";
  bool isReady = false, bEdit = false, dirty = false;
  int defaultSleepTime = 0, loop = 0;
  final double _height = 70;
  final ScrollController _controller = ScrollController();

  Widget _button(IconData iconData, VoidCallback onPressed, {bool visible = true}){
    return Container(
      width: 50,
      height: 50,
      // decoration: BoxDecoration(
      //   border: Border.all(color: Colors.blueAccent),
      //   borderRadius: BorderRadius.circular(10),
      // ),
      child:  IconButton(
        color: Colors.white,
        icon: Icon(iconData, color: visible ? Colors.white : Colors.grey, size: visible ? 30 : 20),
        onPressed: visible ? onPressed : null,
      ) // visible ? btn : null
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    spendSeconds = 0;
    sleepTime = 30;
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      dynamic arg = ModalRoute.of(context)!.settings.arguments;
      title = arg["title"] as String; // 目錄名稱
      setState(() {});

      if(arg["path"] is String) {
        mode = "Directory";
        path = arg["path"] as String;

        String active = await Storage.getString("playDirectory");
        defaultSleepTime = await Storage.getInt("sleepTime");
        loop = await Storage.getInt("loop");

        if(songs.isEmpty || active != path || title == "MyTube2") {
          songs = [];
          await initialDirectory();
          await Storage.setString("playDirectory", path);
        }        
      } else {
        mode = "Collect";
        songs = [];
        // print(arg["datas"]);
        await initialCollect(arg["datas"]);
        await Storage.setString("playDirectory", "");
      }
      isReady = true;
      setState(() { });
    });
   
  }
  String trimFullName(String fullName) {
    var arr = fullName.split("/");
    var ss = arr[arr.length -1].replaceAll("yt-", "").replaceAll("T", " ");
    String title = "${ss.substring(0, 2)}-${ss.substring(2, 4)}-${ss.substring(4, 6)}";
    title +=  " ${ss.substring(7, 9)}:${ss.substring(9, 11)}";
    
    return title;
  }

  String trimExtName(String title) {
    List list = ['3gpp', 'webm', 'mp4', 'mp3'];
    for(var i = 0; i < list.length; i++) {
      title = title.replaceAll(".${list[i]}", "");
    }
    return title;
  }

  Future<void> initialDirectory() async {
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
        // print("file: $fullName: ${f1.lengthSync()}");
        if(f1.lengthSync() == 0){
          f1.deleteSync();
          continue;
        }
      }

      var duration = await player.setUrl(fullName);
      String songName = trimExtName(list[i]);
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

    await intitialAudio();

    return;
  }

  Future<void> initialCollect(List datas) async {
    final player = AudioPlayer();
    for(var i = 0; i < datas.length; i++) {
      String path = datas[i];
      List paths = path.split("/");
      // print(datas[i]);
      var duration = await player.setUrl(datas[i]);
      var item = MediaItem(
        id: datas[i],
        title: trimExtName(paths[paths.length - 1]),
        album: title,
        artist: paths[paths.length - 2],
        duration: duration,
      );
      songs.add(item);
    }
    await intitialAudio();
  }

  Future<void> intitialAudio() async {
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
  }
  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  @override
  void reassemble() async { // develope mode
    super.reassemble();
    // initialDirectory();
    _animateToIndex(0);
  }

  @override
  dispose() async {
    super.dispose();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // _audioHandler!.destroy();
    // _audioHandler = null;
    // songs = [];
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // if(AppLifecycleState.resumed == state) {
    // }
    // else if(AppLifecycleState.paused == state) {
    //   debugPrint("didChangeAppLifecycleState: $state");
    // }
  }

  backTo() {
    Navigator.of(context).pop(dirty);
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
              if(!bEdit && _audioHandler != null && songs.isNotEmpty)
                _buildSlider(),
              if(!bEdit && _audioHandler != null && songs.isNotEmpty)
                _buildControls(),
              if(bEdit)
                _buildEdit()
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
    var arr = [3, 5, 10, 15, 20, 30, 45, 60, 90, 120];

    return PopupMenuButton<int>(
      icon: const Icon(Icons.alarm, color: Colors.white),
      offset: const Offset(0, 40),
      itemBuilder: (context) {
        return [
          for (var i = 0; i < arr.length; i++)
            CheckedPopupMenuItem<int>(
              value: arr[i],
              checked: sleepTime == arr[i],
              child: Text('${arr[i]} 分鐘', 
                style: TextStyle(
                  fontSize: 18,
                  color: defaultSleepTime == arr[i] ? Colors.red : Colors.black
                )
              )
            ),
        ];
      },
      onSelected: (int value) {
        sleepTime = value;
        defaultSleepTime = -1;
        spendSeconds = 0;
        Storage.setInt("sleepTime", sleepTime);
        setState(() {});
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
      child: active && !bEdit
        ? const Icon(Icons.play_arrow, size: 20, color: Colors.white)
        : Text((index < 9 ? "0" : "") + (index + 1).toString(), 
            textAlign: TextAlign.center,
            style: const TextStyle(color:Colors.grey, fontSize: 12)
          ) 
    );
    Widget? widget2B = title == "MyTube2" || (song.artist != null && song.artist!.isNotEmpty) ? 
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if(song.artist != null && song.artist!.isNotEmpty)
            Text("  ${song.artist!}",
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color:Colors.white, fontSize: 12)
            ),
          Expanded(flex: 1, child: Container(width: 5,)), 
          if(title == "MyTube2")
            Text(trimFullName(song.id),
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color:Colors.white, fontSize: 12)
            ),
        ]
      ) : null;
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
        if(widget2B != null)
          Container(child: widget2B)
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
                onLongPress: () {
                  if(bEdit == false) {
                    onLongPress(index);
                  }
                },
                onTap: () {
                  if(bEdit == false) {
                    _audioHandler!.setSong(song);
                    _audioHandler!.play();
                  } else {

                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      widget1,
                      Expanded( flex: 1, child: widget2),
                      if(!bEdit) 
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
                        ),
                      if(bEdit && marked.contains("'$index'"))
                        IconButton(
                          iconSize: 20,
                          icon: const Icon(Icons.check_box_rounded, color: Colors.white),
                          onPressed: () {
                            marked = marked.replaceAll("'$index'", "");
                            setState(() { });
                          },
                        ),
                      if(bEdit && ! marked.contains("'$index'"))
                        IconButton(
                          iconSize: 20,
                          icon: const Icon(Icons.check_box_outline_blank_rounded, color:Colors.white),
                          onPressed: () {
                            marked += "'$index'";
                            setState(() { });
                          },
                        ),
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
  
  onLongPress(int index) {
    _audioHandler!.stop();
    marked = "'$index'";
    if(mode == "Directory") {
      
    } else {

    }
    bEdit = true;
    setState(() { });
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
            Expanded(flex: 1, child: Container()),
            _button(Icons.skip_previous, _audioHandler!.skipToPrevious, visible: queueIndex > 0),
            if (playing)
              _button(Icons.pause, _audioHandler!.pause)
            else
              _button(Icons.play_arrow, () {
                _audioHandler!.play();
                setState(() { });
              }),
            _button(Icons.stop, _audioHandler!.stop),
            _button(Icons.skip_next, _audioHandler!.skipToNext, visible: queueIndex < songs.length -1),
            Expanded(flex: 1, 
              child: Row(children: [
                Expanded(flex: 1, child: Container()),
               _buildSpendTime(),
               const SizedBox(width: 5,)
              ],
            )),
          ],
        );
      },
    );
  }

  Widget _buildSpendTime() {
     return StreamBuilder<Duration>(
      stream: _audioHandler!.currentPosition,
      builder: (context, snapshot) {
        int sub = (sleepTime * 60) - spendSeconds;
        String total =  "-${Duration(seconds: sub).format()}";

        return Text(total,
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 18,
          )
        );
      }
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

        var str = "-${Duration(seconds: (xx - currentPosition).toInt()).format()}"; // (xx - currentPosition) == 0 ? ""  : 
        
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
            // if(currentPosition > 0)
              Text(str,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                )
              ),
            const SizedBox(width: 5),
          ]
        );
      }
    );
  }

  Widget _buildEdit() {
    return Container(   
      height: 60,
      // decoration: BoxDecoration(
      //   border: Border.all(color: Colors.blueAccent),
      //   // borderRadius: BorderRadius.circular(10),
      // ),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if(mode == "Directory" && marked.isNotEmpty)
              _button(Icons.bookmark, addBookMark, visible: true),
            if(mode != "Directory" && marked.isNotEmpty)
              _button(Icons.content_cut, cut, visible: true),
            if(mode == "Directory" && marked.isNotEmpty && title == "MyTube2")
              _button(Icons.delete, delete, visible: true),
            _button(Icons.undo, undo, visible: true),
          ],
        ),
    );
  }

  addBookMark() async { // 加入清單
    List<String> books = marked.split("''");

    List list = await Storage.getJsonList("Collects");
    Widget listview =  Container(
      height: 300.0, // Change as per your requirement
      width: 310.0, // Change as per your requirement
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: list.length,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: Text(list[index]["title"]),
            onTap: () async {
              for(var i = 0; i < books.length; i++) {
                int j = int.parse(books[i].replaceAll("'", ""));
                // print(songs[j].id);
                var b = list[index]["datas"].any((item) => item == songs[j].id);
                if(! b) {
                  list[index]["datas"].add(songs[j].id);
                }
              }
              await Storage.setJsonList("Collects", list);
              // ignore: use_build_context_synchronously
              marked = "";
              bEdit = false;
              setState(() {});
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

  cut() async {
    List list = await Storage.getJsonList("Collects");
    int index = list.indexWhere((el) => el["title"] == title);
    if(index != -1) {
      List<String> books = marked.split("''");
      List<int> arr = [];
      for(var i = 0; i < books.length; i++) {
        arr.add( int.parse(books[i].replaceAll("'", "")));
      }
      arr.sort();
      for(var i = arr.length - 1; i >= 0; i--) {
        int j = arr[i];

        int index2 = list[index]["datas"].indexWhere((el) => el == songs[j].id);
        if(index2 != -1) {
          list[index]["datas"].removeAt(index2);
          songs.removeAt(j);
          dirty = true;
        }
      }
      await Storage.setJsonList("Collects", list);
    }
    
    marked = "";
    bEdit = false;
    setState(() {});
  }

  delete() async {
    _audioHandler!.stop();
    List<String> books = marked.split("''");
    List<int> arr = [];
    for(var i = 0; i < books.length; i++) {
      arr.add( int.parse(books[i].replaceAll("'", "")));
    }
    arr.sort();
    for(var i = arr.length - 1; i >= 0; i--) {
      int j = arr[i];
      var f = File(songs[j].id);
      if (f.existsSync()) {
        f.deleteSync();
      }
      // print(songs[j].id);
      songs.removeAt(j);
      dirty = true;
    }
    
    marked = "";
    bEdit = false;
    initialDirectory();
    // _audioHandler!.init();
    setState(() {});
  }

  undo() {
    bEdit = false;
    marked = "";
    setState(() {});
  }

  void _animateToIndex(int index) {
    if(_controller == null || _controller.positions.isEmpty) {
      return;
    }
    
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
  bool bInitial = false;

  void init() async {
    currentPosition.add(Duration.zero);
    if(bInitial == false) {
      _player.playbackEventStream.listen(_broadcastState);

      AudioService.position.listen((Duration position) {
        if(position.inSeconds != _oldSeconds) {
          currentPosition.add(position);
          _oldSeconds = position.inSeconds;

          // var timeline = DateTime.now().format(pattern: "mm:ss"); // "mm:ss"
          if(sleepTime != 0 && spendSeconds >= sleepTime * 60) {
            pause();
            spendSeconds = 0;
            // print("positition: pause, spendSeconds: $spendSeconds, $timeline");
          } else if(position.inSeconds > 0 && _player.playing) {
            spendSeconds++;
            // print("positition: playing: ${_player.playing}, spendSeconds: $spendSeconds, $timeline");
          }
        }
      });

      // _player.playerStateStream.listen((state) {
        // print("state: ${state.playing},  processingState: ${state.processingState}");
        // if (state.playing) ... else ...
        // switch (state.processingState) {
        //   case ProcessingState.idle: ...
        //   case ProcessingState.loading: ...
        //   case ProcessingState.buffering: ...
        //   case ProcessingState.ready: ...
        //   case ProcessingState.completed: ...
        // }
      // });
      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) skipToNext();
      });
      bInitial = true;
    } else {
      stop();
      queue.value.clear();
    }
    queue.add(songs);

    if(songs.isNotEmpty) {
      setSong(songs.first);
    }
  }
  void destroy() {
    _player.dispose();
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
    await _player.seek(Duration.zero);
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