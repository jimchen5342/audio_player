import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_player/system/module.dart';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;

AudioPlayerHandler? _audioHandler;
List<MediaItem> songs = [];
int spendSeconds = 0, sleepTime = 30;
String mode = "Directory";
MethodChannel _platform = const MethodChannel('com.flutter/MethodChannel');

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
        if (defaultSleepTime > 0) {
          sleepTime = defaultSleepTime;
        }
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
        int defaultSleepTime = await Storage.getInt("sleepTime$mode");
        if (defaultSleepTime > 0) {
          sleepTime = defaultSleepTime;
        } else if (title == "日語") {
          sleepTime = 10;
        }

        songs = [];
        // print(arg["datas"]);
        await initialCollect(arg["datas"]);
        await Storage.setString("playDirectory", "");
      }

      await Storage.setString("active$mode", mode == "Directory" ? path : title);

      if (songs.isEmpty) {
        dirty = true;
        backTo();
        await EasyLoading.dismiss();
        alert("「${title}」內無音樂檔");
        return;
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

      try {
        final file = File(datas[i]);
        if (await file.exists()) {
          var duration = await player.setUrl(datas[i]);
          var item = MediaItem(
            id: datas[i],
            title: trimExtName(paths[paths.length - 1]),
            album: title,
            artist: paths[paths.length - 2],
            duration: duration,
          );
          songs.add(item);
        } else {
          dirty = true;
          continue;
        }
      } catch (e) {
        dirty = true;
        continue;
      }
    }
    if (dirty) {
      List<dynamic> list = await Storage.getJsonList("Collects");
      int index = list.indexWhere((el) => el["title"] == title);
      if (index != -1) {
        list[index]["datas"] = [];
        for (var i = 0; i < songs.length; i++) {
          list[index]["datas"].add(songs[i].id);
        }
      }
      await Storage.setJsonList("Collects", list);
    }
    if (songs.isNotEmpty) {
      await intitialAudio();
    }
  }

  Future<void> intitialAudio() async {
    if (songs.isNotEmpty) {
      int index = -1, start = 0;
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
    await EasyLoading.dismiss();
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
    if(mode == "Collect") {
      Navigator.of(context).pop(dirty);
    } else if(dirty) {
      Navigator.of(context).pop(songs.length);
    } else {
      Navigator.of(context).pop();
    }
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
    var arr =
        mode == "Collect" && (title == "日語" || title == "英語" || title == "VOA")
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
            if ((mode == "Directory" && title == "大家的日本語") || (mode == "Collect" && title == "日語"))
              _button(Icons.cloud_download_outlined, () {
                downloadMP3();
              }),

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
                    setState(() {
                      _audioHandler!.seek(Duration(seconds: value.toInt()));
                    });
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

  downloadMP3() async {
    _audioHandler?.stop();
    const String url = "https://jimchen5342.github.io/japan/node/重點.mp3";
    Archive archive = Archive();
    String root = await Archive.root();
    String saveDirectory = "$root/Download/大家的日本語";
    await archive.createFolder(saveDirectory);
    String fileName = '重點.mp3';

    void addMP3(String fullName) async {
      final player = AudioPlayer();
      var duration = await player.setUrl(fullName);
      String songName = trimExtName(fileName);
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
      setState(() {});
      dirty = true;
      alert("下載成功！！");
    }

    Future<void> download() async {
      String filePath = "$saveDirectory/$fileName";
      try {
        await EasyLoading.show(status: '下載中...');
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
          addMP3(filePath);
        } else {
          alert("下載失敗，伺服器回應狀態碼: ${response.statusCode}");
        }
      } catch (e) {
        alert("\n🚨 發生運行時錯誤：$e；\n請檢查網路連線和權限。");
      } finally {
        await EasyLoading.dismiss();
      }
    }

    void showFileNameDialog() {
      final formKey = GlobalKey<FormState>();
      final textController =
          TextEditingController(text: fileName.replaceAll(".mp3", ""));

      showDialog(
        context: context,
        barrierDismissible: false, // 避免點擊外部直接關閉，強制使用者決定取消或確定
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('請輸入檔案名稱'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: textController,
                decoration: const InputDecoration(
                  // hintText: '例如: my_song.mp3',
                  // labelText: '檔名 (必須為 .mp3 結尾)',
                  border: OutlineInputBorder(),
                ),
                // 在這裡進行檔名與副檔名的校驗
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '檔名不能為空';
                  }
                  return null; // 驗證通過
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 關閉對話框
                },
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  // 觸發 Form 的 validator
                  if (formKey.currentState!.validate()) {
                    fileName = textController.text.trim();
                    if (!fileName.toLowerCase().endsWith('.mp3')) {
                      fileName += ".mp3";
                    }
                    Navigator.of(context).pop(); // 驗證成功，關閉並回傳檔名
                    download();
                  }
                },
                child: const Text('確定'),
              ),
            ],
          );
        },
      ).then((value) {
        if (value != null) {
          // 在這裡處理驗證通過後的檔名
          debugPrint('使用者輸入的合法檔名為: $value');
        }
      });
    }

    Future<void> getUniqueFile() async {
      // 1. 拆分主檔名與副檔名 (例如: "重點" 與 "mp3")
      final dotIndex = fileName.lastIndexOf('.');
      final String baseName;
      final String extension;

      if (dotIndex != -1) {
        baseName = fileName.substring(0, dotIndex);
        extension = fileName.substring(dotIndex); // 包含 "."，例如 ".mp3"
      } else {
        baseName = fileName;
        extension = '';
      }

      // 2. 先檢查原始檔名是否存在
      String currentPath = '$saveDirectory/$baseName$extension';
      File file = File(currentPath);

      int counter = 1;

      // 3. 迴圈檢查，直到檔案不存在為止
      while (await file.exists()) {
        // 格式化新檔名，例如: "重點(1).mp3"
        currentPath = '$saveDirectory/$baseName$counter$extension';
        file = File(currentPath);
        counter++;
      }

      fileName = file.path.replaceAll("$saveDirectory/", "");
    }

    await getUniqueFile();

    showFileNameDialog();
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
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    int start = -1;
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
