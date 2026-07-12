import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_player/system/module.dart';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

AudioPlayerHandler? _audioHandler;
List<MediaItem> songs = [];
int spendSeconds = 0, sleepTime = 30;
dynamic history = {};
String mode = "Directory";
MethodChannel _platform = MethodChannel('com.flutter/MethodChannel');

class Player extends StatefulWidget {
  Player({Key? key}) : super(key: key);

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver {
  String title = "", path = "", marked = "";
  bool isReady = false, bRowLongPress = false, dirty = false;
  int loop = 0;
  final double _height = 70;
  final ScrollController _controller = ScrollController();

  Widget _button(IconData iconData, VoidCallback onPressed,
      {bool visible = true, active = false}) {
    return Container(
        width: 50,
        height: 50,
        // decoration: BoxDecoration(
        //   border: Border.all(color: Colors.blueAccent),
        //   borderRadius: BorderRadius.circular(10),
        // ),
        child: IconButton(
          color: Colors.white,
          icon: Icon(iconData,
              color: active
                  ? Colors.deepOrangeAccent
                  : (visible ? Colors.white : Colors.grey),
              size: visible ? 30 : 20),
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
      await EasyLoading.show(status: 'loading...');
      dynamic arg = ModalRoute.of(context)!.settings.arguments;
      title = arg["title"] as String; // 目錄名稱
      setState(() {});

      if (arg["path"] is String) {
        mode = "Directory";
        path = arg["path"] as String;
        loop = await Storage.getInt("loop$mode");

        String active = await Storage.getString("playDirectory");
        int defaultSleepTime = await Storage.getInt("sleepTime$mode");
        if(defaultSleepTime > 0) {
          sleepTime = defaultSleepTime;
        }
        history = await Storage.getJson("history$mode");
        if (history['title'] is String && history['title'] != title) {
          history = {};
        }
        history['title'] = title;
        // if (songs.isEmpty || active != path) {
        songs = [];
        await initialDirectory();
        await Storage.setString("playDirectory", path);
        // } else {
        //   await EasyLoading.dismiss();
        // }
      } else {
        mode = "Collect";
        loop = await Storage.getInt("loop$mode");
        history = await Storage.getJson("history$mode");
        int defaultSleepTime = await Storage.getInt("sleepTime$mode");
        if(defaultSleepTime > 0) {
          sleepTime = defaultSleepTime;
        } else if(title == "日語") {
          sleepTime = 10;
        }
        
        if (history['title'] is String && history['title'] != title) {
          history = {};
        }
        history['title'] = title;
        songs = [];
        // print(arg["datas"]);
        await initialCollect(arg["datas"]);
        await Storage.setString("playDirectory", "");
      }
      isReady = true;
      setState(() {});
    });
  }

  String trimFullName(String fullName) {
    var arr = fullName.split("/");
    var ss = arr[arr.length - 1].replaceAll("yt-", "").replaceAll("T", " ");
    String title =
        "${ss.substring(0, 2)}-${ss.substring(2, 4)}-${ss.substring(4, 6)}";
    title += " ${ss.substring(7, 9)}:${ss.substring(9, 11)}";

    return title;
  }

  String trimExtName(String title) {
    List list = ['3gpp', 'webm', 'mp4', 'mp3'];
    for (var i = 0; i < list.length; i++) {
      title = title.replaceAll(".${list[i]}", "");
    }
    return title;
  }

  Future<void> initialDirectory() async {
    // 資料夾
    String root = await Archive.root();
    Archive archive = Archive();
    List<String> list = await archive.getFiles(path);
    final player = AudioPlayer();

    List playlist = [];
    for (var i = 0; i < list.length; i++) {
      var fullName = "$root/$path/${list[i]}";
      var duration = await player.setUrl(fullName);
      String songName = trimExtName(list[i]);
      String author = "";
      if (songName.contains("-") && !songName.contains("=")) {
        List<String> arr = songName.split("-");
        songName = arr[1].trim();
        if (!arr[0].trim().isNumeric()) {
          // 有可能是數字，不要
          author = arr[0].trim();
        }
      }

      var item = MediaItem(
        id: fullName,
        title: songName,
        album: title, // 目錄名稱
        artist: author,
        duration: duration,
      );
      songs.add(item);
    }

    await intitialAudio();
    return;
  }

  Future<void> initialCollect(List datas) async {
    // 清單
    // datas.sort();
    final player = AudioPlayer();
    for (var i = 0; i < datas.length; i++) {
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
    if (songs.isNotEmpty) {
      int index = -1, start = 0;
      if (loop == 1) {
        String? historyId;
        if (history != null) {
          if (history["id"] is String) {
            historyId = history["id"] as String;
          }
        }
        if (historyId != null) {
          final found = songs.indexWhere((item) => item.id == historyId);
          if (found != -1) {
            index = found;
          } else if(mode == "Collect") {
            history["start"] = null;
            history["end"] = null;
          }
        }

        if (index > -1) {
          if (history["start"] is num) {
            start = history["start"];
          }
        }
      }
      _audioHandler ??= await AudioService.init(
        builder: () => AudioPlayerHandler(),
        config: const AudioServiceConfig(
            androidNotificationChannelId:
                'com.flutter.audio_player', // 'com.ryanheise.myapp.channel.audio',
            androidNotificationChannelName: '音樂播放器',
            androidNotificationOngoing: true,
            androidNotificationIcon: "mipmap/ic_launcher"),
      );
      _audioHandler!.init(index, start);
      if (loop == 1) {
        _audioHandler!.setLoopMode(LoopMode.one); // 0 off/1 one/10 all
        // } else if (loop == 10) { // 不好用
        //   _audioHandler!.setLoopMode(LoopMode.all); // 0 off/1 one/10 all
      }
      EasyLoading.dismiss();
    }
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  @override
  void reassemble() async {
    // develope mode
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
    if (isReady) {
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
                if (!bRowLongPress && _audioHandler != null && songs.isNotEmpty)
                  _buildSlider(),
                if (!bRowLongPress && _audioHandler != null && songs.isNotEmpty)
                  _buildPlayerControls(),
                if (bRowLongPress) _buildCollectButton() // 新增或移除清單按鈕
              ]),
            );
          });
    } else {
      child = const Center(
        child: CircularProgressIndicator(),
      );
    }

    Widget iconLoop = const Icon(Icons.repeat, color: Colors.white);
    if (loop == 1) {
      iconLoop = const Icon(Icons.repeat_one, color: Colors.white);
    } else if (loop == 10) {
      iconLoop = const Icon(Icons.repeat_on, color: Colors.white);
    } else {
      iconLoop = const Icon(Icons.repeat, color: Colors.white);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light, // 強制 Android 圖示為白色
      ),
      child: Container(
        color: Colors.black,
        child: SafeArea(
          top: true,
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
                  style: const TextStyle(
                    color: Colors.white,
                  )),
              actions: [
                if (_audioHandler != null && songs.isNotEmpty)
                  _buildPopMenuSleep(),
                if (_audioHandler != null && songs.isNotEmpty)
                  IconButton(
                    icon: iconLoop,
                    onPressed: () async {
                      LoopMode loopMode = LoopMode.off;
                      if (loop == 0) {
                        loop = 1;
                        loopMode = LoopMode.one;
                        // } else if (loop == 1) {
                        //   loopMode = LoopMode.all; // 不好用
                        //   loop = 10;
                      } else {
                        loop = 0;
                      }
                      _audioHandler!
                          .setLoopMode(loopMode); // 0 off/1 one/10 all
                      await Storage.setInt("loop$mode", loop);
                      setState(() {});
                    },
                  ),
              ],
              backgroundColor: Colors.deepOrangeAccent,
            ),
            body: PopScope(
                canPop: false,
                onPopInvokedWithResult: (bool didPop, dynamic result) {
                  if (didPop) {
                    return;
                  }
                  backTo();
                },
                child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildPopMenuSleep() {
    var arr = mode == "Collect" && (title == "日語" || title == "英語" || title == "VOA") 
      ? [5, 10, 15, 20, 30, 45, 60] 
      : [15, 20, 30, 45, 60, 90, 120];

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
                          color: sleepTime == arr[i]
                              ? Colors.red
                              : Colors.black))),
          ];
        },
        onSelected: (int value) {
          sleepTime = value;
          spendSeconds = 0;
          Storage.setInt("sleepTime$mode", sleepTime);
          setState(() {});
        });
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
    if (duration.startsWith("0:")) {
      duration = duration.substring(2);
    }
    Widget widget1 = Container(
        width: 20,
        margin: const EdgeInsets.only(right: 2),
        // decoration: BoxDecoration(
        //   border: Border.all(width: 1.0, color: Colors.white),
        // ),
        child: active && !bRowLongPress
            ? const Icon(Icons.play_arrow, size: 20, color: Colors.white)
            : Text((index < 9 ? "0" : "") + (index + 1).toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12)));
    Widget? widget2B = (song.artist != null && song.artist!.isNotEmpty)
        ? Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                if (song.artist != null && song.artist!.isNotEmpty)
                  Text("  ${song.artist!}",
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                Expanded(
                    flex: 1,
                    child: Container(
                      width: 5,
                    )),
              ])
        : null;
    Widget widget2 = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(song.title,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Colors.white, fontSize: 18)),
          if (widget2B != null) Container(child: widget2B)
        ]);

    return Container(
        decoration: const BoxDecoration(
          // color: Colors.green,
          border:
              Border(bottom: BorderSide(width: 1, color: Colors.deepOrange)),
        ),
        child: Row(
          children: [
            Expanded(
                flex: 1,
                child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onLongPress: () {
                        if (bRowLongPress == false) {
                          onLongPress(index);
                        }
                      },
                      onTap: () {
                        if (bRowLongPress == false) {
                          _audioHandler!.setSong(song);
                          _audioHandler!.play();
                        } else {}
                      },
                      child: Container(
                          padding: const EdgeInsets.all(5),
                          child: Row(children: [
                            widget1,
                            Expanded(flex: 1, child: widget2),
                            if (!bRowLongPress)
                              Padding(
                                  padding: const EdgeInsets.only(left: 2.0),
                                  child: Text(duration,
                                      // softWrap: true,
                                      // overflow: TextOverflow.ellipsis,
                                      // textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14))),
                            if (bRowLongPress && marked.contains("'$index'"))
                              IconButton(
                                iconSize: 20,
                                icon: const Icon(Icons.check_box_rounded,
                                    color: Colors.white),
                                onPressed: () {
                                  marked = marked.replaceAll("'$index'", "");
                                  setState(() {});
                                },
                              ),
                            if (bRowLongPress && !marked.contains("'$index'"))
                              IconButton(
                                iconSize: 20,
                                icon: const Icon(
                                    Icons.check_box_outline_blank_rounded,
                                    color: Colors.white),
                                onPressed: () {
                                  marked += "'$index'";
                                  setState(() {});
                                },
                              ),
                          ])),
                    )))
          ],
        ));
  }

  onLongPress(int index) {
    _audioHandler!.stop();
    marked = "'$index'";
    if (mode == "Directory") {
    } else {}
    bRowLongPress = true;
    setState(() {});
  }

  Widget _buildPlayerControls() {
    return StreamBuilder<bool>(
      stream:
          _audioHandler!.playbackState.map((state) => state.playing).distinct(),
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;
        final queueIndex = songs.indexOf(_audioHandler!.currentSong.value);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (mode == "Collect" && loop == 1 && history["title"] == "日語") // "日語" 目錄才有下載功能
              _button(
                  history["start"] is num
                      ? Icons.cloud_download
                      : Icons.cloud_download_outlined, () {
                donwloadLRC();
              }, active: history["start"] is num),
            if(mode == "Collect" && loop == 1 && history["title"] != "日語")
              _button(history["start"] is num
                ? Icons.add_location : Icons.add_location_outlined,
                () {
                setupRange();
              }, active: history["start"] is num),

            Expanded(flex: 1, child: Container()),
            _button(Icons.skip_previous, _audioHandler!.skipToPrevious,
                visible: queueIndex > 0),
            if (playing)
              _button(Icons.pause, _audioHandler!.pause)
            else
              _button(Icons.play_arrow, () {
                _audioHandler!.play();
                setState(() {});
              }),
            _button(Icons.stop, _audioHandler!.stop),
            _button(Icons.skip_next, _audioHandler!.skipToNext,
                visible: queueIndex < songs.length - 1),
            Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Expanded(flex: 1, child: Container()),
                    _buildSpendTime(),
                    const SizedBox(
                      width: 5,
                    )
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
          String total = "-${Duration(seconds: sub).format()}";

          return Text(total,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 18,
              ));
        });
  }

  Widget _buildSlider() {
    return StreamBuilder<Duration>(
        stream: _audioHandler!.currentPosition,
        builder: (context, snapshot) {
          var currentPosition = (snapshot.data ?? const Duration(seconds: 0))
              .inSeconds
              .toDouble();
          Duration? duration = _audioHandler!.currentSong.value.duration;
          final xx =
              (duration ?? const Duration(seconds: 0)).inSeconds.toDouble();
          if (currentPosition > xx) currentPosition = 0;

          var str1 = Duration(seconds: currentPosition.toInt()).format();
          var str2 = Duration(seconds: (xx).toInt()).format(); // (x

          return Row(children: [
            Expanded(
                flex: 1,
                child: Slider(
                  value: currentPosition,
                  max: xx,
                  // divisions: 5,
                  // label: currentPosition.format(),
                  onChanged: (double value) {
                    if (!(loop == 1 &&
                        history["start"] is num &&
                        history["end"] is num)) {
                      setState(() {
                        _audioHandler!.seek(Duration(seconds: value.toInt()));
                      });
                    }
                  },
                )),
            Column(
              children: [
                Text(str1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    )),
                // const Divider(
                //   color: Colors.orange,
                //   height: 8,
                //   thickness: 2,
                // ),
                Text(str2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    )),
              ],
            ),
            const SizedBox(width: 5),
          ]);
        });
  }

  Widget _buildCollectButton() {
    // 新增或移除清單按鈕
    return Container(
      height: 60,
      // decoration: BoxDecoration(
      //   border: Border.all(color: Colors.blueAccent),
      //   // borderRadius: BorderRadius.circular(10),
      // ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (mode == "Directory" && marked.isNotEmpty)
            _button(Icons.bookmark, addCollect, visible: true),
          if (mode != "Directory" && marked.isNotEmpty)
            _button(Icons.content_cut, removeCollect, visible: true),
          _button(Icons.undo, undo, visible: true),
        ],
      ),
    );
  }

  addCollect() async {
    // 加入清單
    List<String> books = marked.split("''");
    List list = await Storage.getJsonList("Collects");
    if (list.isEmpty) {
      list.add({"title": "我的最愛", "datas": []});
      list.add({"title": "英語", "datas": []});
      list.add({"title": "日語", "datas": []});
      await Storage.setJsonList("Collects", list);
    }
    Widget listview = Container(
      height: 300.0, // Change as per your requirement
      width: 310.0, // Change as per your requirement
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: list.length,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: Text(list[index]["title"]),
            onTap: () async {
              for (var i = 0; i < books.length; i++) {
                int j = int.parse(books[i].replaceAll("'", ""));
                var b = list[index]["datas"].any((item) => item == songs[j].id);
                if (!b) {
                  list[index]["datas"].add(songs[j].id);
                }
              }
              list[index]["datas"].sort();
              await Storage.setJsonList("Collects", list);
              // ignore: use_build_context_synchronously
              marked = "";
              bRowLongPress = false;
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
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(5.0))),
            content: listview,
          );
        });
  }

  removeCollect() async {
    // 移除清單
    List list = await Storage.getJsonList("Collects");
    int index = list.indexWhere((el) => el["title"] == title);
    if (index != -1) {
      List<String> books = marked.split("''");
      List<int> arr = [];
      for (var i = 0; i < books.length; i++) {
        arr.add(int.parse(books[i].replaceAll("'", "")));
      }
      arr.sort();
      for (var i = arr.length - 1; i >= 0; i--) {
        int j = arr[i];

        int index2 = list[index]["datas"].indexWhere((el) => el == songs[j].id);
        if (index2 != -1) {
          list[index]["datas"].removeAt(index2);
          songs.removeAt(j);
          dirty = true;
        }
      }
      await Storage.setJsonList("Collects", list);
    }

    marked = "";
    bRowLongPress = false;
    setState(() {});
  }

  delete() async {
    _audioHandler!.stop();
    List<String> books = marked.split("''");
    List<int> arr = [];
    for (var i = 0; i < books.length; i++) {
      arr.add(int.parse(books[i].replaceAll("'", "")));
    }
    arr.sort();
    for (var i = arr.length - 1; i >= 0; i--) {
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
    bRowLongPress = false;
    initialDirectory();
    // _audioHandler!.init();
    setState(() {});
  }

  undo() {
    bRowLongPress = false;
    marked = "";
    setState(() {});
  }

  void _animateToIndex(int index) {
    if (_controller.positions.isEmpty) {
      return;
    }

    final visibleRange = _controller.position.viewportDimension;
    double pos = -1, newPos = index * _height;
    if (newPos < _controller.offset) {
      pos = index * _height;
    } else if (newPos > _controller.offset + visibleRange) {
      pos = index * _height;
    }

    if (pos > -1) {
      _controller.animateTo(
        pos,
        duration: const Duration(seconds: 2),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  void setupRange() { // 設定播放範圍
    _audioHandler!.pause();
    history["id"] = _audioHandler?.currentSong.value.id;
    final int? startInitial =
        history["start"] is num ? (history["start"] as num).toInt() : null;
    final int? endInitial =
        history["end"] is num ? (history["end"] as num).toInt() : null;
    final Duration currentDuration =
        _audioHandler?.currentSong.value.duration ?? Duration.zero;
    final int durationSeconds = currentDuration.inSeconds;
    final String durationHint =
        '${(durationSeconds ~/ 60).toString().padLeft(2, '0')}:${(durationSeconds % 60).toString().padLeft(2, '0')}';

    final startSecondController = TextEditingController();
    final endSecondController = TextEditingController();

    if (startInitial != null) {
      startSecondController.text = startInitial.toString();
    }
    if (endInitial != null) {
      endSecondController.text = endInitial.toString();
    }

    bool canConfirm() {
      if (startSecondController.text.isEmpty &&
          endSecondController.text.isEmpty) {
        return false;
      }
      final int start = int.tryParse(startSecondController.text) ?? 0;
      final int end = int.tryParse(endSecondController.text) ?? 0;
      if (startInitial == null && endInitial == null) {
        return start != 0 || end != 0;
      }
      return start != (startInitial ?? 0) || end != (endInitial ?? 0);
    }

    String formatSeconds(String secondsStr) {
      final int seconds = int.tryParse(secondsStr) ?? 0;
      final int minutes = seconds ~/ 60;
      final int secs = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false, // 使用者必須點按鈕關閉
      builder: (BuildContext context) {
        bool confirmedEnabled = canConfirm();
        String? errorText;

        void updateState(VoidCallback fn) {
          fn();
          confirmedEnabled = canConfirm();
        }

        return StatefulBuilder(builder: (context, setDialogState) {
          void onFieldChanged() {
            setDialogState(() {
              confirmedEnabled = canConfirm();
              errorText = null;
            });
          }

          return AlertDialog(
            title: const Text(
              '設定播放範圍',
              // style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5.0)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      '開始時間：',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Expanded(
                      child: TextField(
                        controller: startSecondController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          suffixText: '秒',
                        ),
                        onChanged: (_) => onFieldChanged(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Center(
                        child: Text(
                          formatSeconds(startSecondController.text),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      '結束時間：',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Expanded(
                      child: TextField(
                        controller: endSecondController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          hintText: '$durationSeconds',
                          // hintStyle: TextStyle(color: Colors.grey[400]),
                          suffixText: '秒',
                        ),
                        onChanged: (_) => onFieldChanged(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Center(
                        child: Text(
                          formatSeconds(endSecondController.text),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                if (durationSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '歌曲長度：$durationHint',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      errorText!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              if (history['start'] is num)
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () async {
                    history['start'] = null;
                    history['end'] = null;
                    await Storage.setJson('history$mode', history);
                    Navigator.of(context).pop();
                    setState(() {});
                  },
                  child: const Text('移除'),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: confirmedEnabled
                    ? () async {
                        final int start =
                            int.tryParse(startSecondController.text) ?? 0;
                        final int end =
                            int.tryParse(endSecondController.text) ?? 0;
                        if (end <= start + 10) {
                          setDialogState(() {
                            errorText = '結束時間需大於開始時間 10 秒';
                          });
                          return;
                        }
                        if (durationSeconds > 0 && end > durationSeconds) {
                          setDialogState(() {
                            errorText = '結束時間不得大於歌曲長度';
                          });
                          return;
                        }
                        history['start'] = start;
                        history['end'] = end;
                        await Storage.setJson('history$mode', history);
                        Navigator.of(context).pop();
                        _audioHandler!.seek(Duration(seconds: start));
                        setState(() {});
                      }
                    : null,
                child: const Text('確定'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('關閉'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> donwloadLRC() async { // 下載 LRC
    _audioHandler?.pause();
    history["id"] = _audioHandler?.currentSong.value.id;
    final String songTitle = _audioHandler?.currentSong.value.title ?? '';
    final int start = songTitle.indexOf('-');
    final String title2 =
        start == -1 ? songTitle.trim() : songTitle.substring(0, start).trim();
    int indexStart = -1, indexEnd = -1;

    final String url =
        'https://jimchen5342.github.io/japan/大家的日本語/${Uri.encodeComponent(title2)}.json';

    final client = HttpClient();
    try {
      await EasyLoading.show(status: '下載中...');
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('下載失敗: ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! List) {
        throw Exception('資料格式錯誤');
      }

      final items = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      if(history["start"] is num && history["end"] is num) {
        final int startHistory = history["start"];
        final int endHistory = history["end"];
        for(int i = 0; i < items.length; i++) {
          final item = items[i];
          int startItem = item['start'] is num ? item['start'] as int : 0;
          int endItem = item['end'] is num 
            ? item['end'] as int 
            : (items[i + 1]['start'] as int) - 1;
          
          if(indexStart == -1 && startItem >= startHistory) {
            indexStart = i;
          } else if(endItem <= endHistory) {
            indexEnd = i;
          } else {
            break;
          }
        }
      }

      await EasyLoading.dismiss();

      int dialogIndexStart = indexStart;
      int dialogIndexEnd = indexEnd;
      final ScrollController lrcListController = ScrollController();

      await showDialog<void>(
        context: context,
        builder: (context) {
          final screenSize = MediaQuery.of(context).size;
          final dialogWidth = screenSize.width;
          final dialogHeight = screenSize.height - 40;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (indexStart > -1 && lrcListController.hasClients) {
              final maxScrollExtent = lrcListController.position.maxScrollExtent;
              final targetOffset = (indexStart * 56.0).clamp(0.0, maxScrollExtent);
              lrcListController.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('$title2'),
                content: SizedBox(
                  width: dialogWidth,
                  height: dialogHeight,
                  child: items.isEmpty
                      ? const Center(child: Text('沒有找到資料'))
                      : ListView.separated(
                          controller: lrcListController,
                          itemCount: items.length,
                          // itemExtent: 56,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final String id = item['id']?.toString() ?? '';
                            final String kana = item['kana']?.toString() ?? '';
                            final String displayTitle =
                                id.isEmpty ? kana : '$id. $kana';

                            final bool inRange =
                                dialogIndexStart != -1 &&
                                dialogIndexEnd != -1 &&
                                index >= dialogIndexStart &&
                                index <= dialogIndexEnd;

                            final num? startValue = item['start'] is num
                                ? item['start'] as num
                                : num.tryParse(item['start']?.toString() ?? '');
                            final int startSeconds = startValue?.toInt() ?? 0;
                            final String displayStart =
                                '${(startSeconds ~/ 60).toString().padLeft(2, '0')}:${(startSeconds % 60).toString().padLeft(2, '0')}';

                            return ListTile(
                              onTap: () {
                                setDialogState(() {
                                  if (dialogIndexStart == -1) {
                                    dialogIndexStart = index;
                                    dialogIndexEnd = index;
                                  } else if (index == dialogIndexEnd && dialogIndexEnd != dialogIndexStart) {
                                    dialogIndexEnd--;
                                  } else if (index == dialogIndexStart && dialogIndexEnd != dialogIndexStart) {
                                    dialogIndexStart++;
                                  } else if (index == dialogIndexEnd && dialogIndexEnd == dialogIndexStart) {
                                    dialogIndexStart = -1;
                                    dialogIndexEnd = -1;
                                  } else if (index > dialogIndexEnd) {
                                    dialogIndexEnd = index;
                                  } else if (index < dialogIndexEnd) {
                                    dialogIndexStart = index;
                                  // } else {
                                  //   dialogIndexStart = -1;
                                  //   dialogIndexEnd = -1;
                                  }
                                });
                              },
                              // tileColor: inRange ? Colors.deepOrangeAccent : null,
                              // textColor: inRange ? Colors.white : null,
                              // iconColor: inRange ? Colors.white : null,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 2),
                              title: Text(
                                displayTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: inRange ? Colors.deepOrangeAccent : null,
                                ),
                              ),
                              trailing: Text(
                                displayStart,
                                style: TextStyle(
                                  color: inRange ? Colors.deepOrangeAccent : Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  if(indexStart != -1 && indexEnd != -1)
                    TextButton(
                      onPressed: () async {
                        setDialogState(() {
                          indexStart = -1;
                          indexEnd = -1;
                          dialogIndexStart = -1;
                          dialogIndexEnd = -1;
                          history["start"] = null;
                          history["end"] = null;
                        });
                        await Storage.setJson("history$mode", history);
                        _audioHandler!.seek(const Duration(seconds: 0));
                      },
                      child: const Text('取消', style: TextStyle(color: Colors.red)),
                    ),
                  if(dialogIndexStart != indexStart || dialogIndexEnd != indexEnd)
                    TextButton(
                      onPressed: () async {
                        int startValue = 0;
                        if(dialogIndexStart == -1 || dialogIndexEnd == -1) {
                          history["start"] = null;
                          history["end"] = null;
                        } else {
                          startValue = items[dialogIndexStart]["start"] is num
                              ? items[dialogIndexStart]["start"] as int
                              : 0;
                          history["start"] = startValue;
                          int endValue = items[dialogIndexEnd]["end"] is num
                              ? items[dialogIndexEnd]["end"] as int
                              : (items[dialogIndexEnd + 1]["start"] as int) - 1;
                          history["end"] = endValue;
                        }

                        await Storage.setJson("history$mode", history);
                        _audioHandler!.seek(Duration(seconds: startValue));
                        Navigator.of(context).pop();
                      },
                      child: const Text('確定'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('關閉', style: TextStyle(color: Colors.green)),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      await EasyLoading.dismiss();
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('下載失敗'),
            content: Text(error.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('關閉'),
              ),
            ],
          );
        },
      );
    } finally {
      client.close();
    }
  }
}

class AudioPlayerHandler extends BaseAudioHandler with QueueHandler {
  final _player = AudioPlayer();
  final currentSong = BehaviorSubject<MediaItem>();
  final currentPosition = BehaviorSubject<Duration>();
  int _oldSeconds = 0;
  bool bInitial = false;

  void init(int index, int start) async {
    currentPosition.add(Duration.zero);
    if (bInitial == false) {
      _player.playbackEventStream.listen(_broadcastState);

      AudioService.position.listen((Duration position) async {
        if (position.inSeconds != _oldSeconds) {
          currentPosition.add(position);
          _oldSeconds = position.inSeconds;


          // var timeline = DateTime.now().format(pattern: "mm:ss"); // "mm:ss"
          if (sleepTime != 0 && spendSeconds >= sleepTime * 60) {
            pause();
            spendSeconds = 0;
            return;
            // print("positition: pause, spendSeconds: $spendSeconds, $timeline");
          } else if (position.inSeconds > 0 && _player.playing) {
            spendSeconds++;
            // print("positition: playing: ${_player.playing}, spendSeconds: $spendSeconds, $timeline");
          }

          if (_player.loopMode == LoopMode.one &&
              history["start"] is num &&
              history["end"] is num) {
            if (position.inSeconds >= history["end"]) {
              await pause();
              try {
                await Future.delayed(const Duration(seconds: 1));
                final String? result =
                    await _platform.invokeMethod<String>("beep");
                await seek(Duration(seconds: history["start"]));
                await Future.delayed(const Duration(seconds: 3));
                play();
              } on PlatformException catch (e) {
                debugPrint("Failed: '${e.message}'.");
              }
            }
          }
        }
      });

      _player.processingStateStream.listen((state) async {
        if (state == ProcessingState.completed) {
          skipToNext();
        }
      });
      bInitial = true;
    } else {
      stop();
      queue.value.clear();
    }
    queue.add(songs);
    if (songs.isNotEmpty) {
      if (index == -1) {
        setSong(songs.first);
      } else {
        setSong(songs[index]);
        if (start is int) {
          Timer(const Duration(milliseconds: 600), () async {
            await _player.seek(Duration(seconds: start));
          });
        }
      }
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
  Future<void> play() async {
    _player.play();
    if (history["id"] is! String || history["id"] != currentSong.value.id) {
      history["id"] = currentSong.value.id;
      if(mode == "Collect") {
        history["start"] = null;
        history["end"] = null;
      }

      history["start"] = null;
      history["end"] = null;
      await Storage.setJson("history$mode", history);
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    int start = -1;
    if (history["start"] is num) {
      start = history["start"];
    }
    await _player.seek(start > 0 ? Duration(seconds: start) : Duration.zero);
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
    if (event.processingState == ProcessingState.completed &&
        queueIndex == songs.length - 1) {
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
