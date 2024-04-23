import 'package:external_path/external_path.dart';
import 'dart:io';
import 'package:audio_player/system/storage.dart';
/*
await ExternalPath.getExternalStorageDirectories();

await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_MUSIC);
ExternalPath.DIRECTORY_PICTURES
ExternalPath.DIRECTORY_DOWNLOADS
ExternalPath.DIRECTORY_DCIM
ExternalPath.DIRECTORY_DOCUMENTS
 */

class Archive {
  static Future<String> root() async {
    var pathes = await ExternalPath.getExternalStorageDirectories();
    return "${pathes[0]}";
  }

  Future<List<dynamic>> getDirectories(String directoryPath) async {
    String blackList = await Storage.getString("blackList");
    // blackList = "'MyTube'";
    String root = await Archive.root();
    List<dynamic> list = [];
    String path = directoryPath.replaceAll("$root/", "");
    
    if(path.startsWith(".") == false) {
      var dirList1 = Directory(directoryPath).list();
      var b1 = false;
      await for (final FileSystemEntity f1 in dirList1) {
        if (f1 is Directory) {
          if(!(f1.path.startsWith(".") == false || f1.path.startsWith("Android"))) {
            var list2 = await getDirectories(f1.path);
            if(list2.isNotEmpty) {
              list = list + list2;
            }
          }
        } else if(b1 == true) {
          continue;
        } else if(f1 is File && isMP3(f1)) {
          print(path);
          var paths = directoryPath.split('/');
          String title = paths[paths.length - 1];
          b1 = true;
          if(!blackList.contains("'$path'")) {
            dynamic json = {"title": title, "path": path};
            list.add(json);              
          }
        }
      }
    }
    return list;
  }

  Future<List<String>> getFiles(String directoryPath) async {
    String root = await Archive.root();
    List<String> list = [];
    var dirList1 = Directory("$root/$directoryPath").list();
    await for (final FileSystemEntity f1 in dirList1) {
      if(f1 is File && isMP3(f1)) {
        var paths = f1.path.split('/');
        String title = paths[paths.length - 1];
        list.add(title);
      }
    }
    return list;
  }


  writeFile() async { // 測好了，可以用
    var path = await ExternalPath.getExternalStorageDirectories();
    var file = File('${path[0]}/counter.txt');

    file.writeAsString('jim'); 
    /* 測好了，可以用
    var path = await ExternalPath.getExternalStorageDirectories();
    print("path: ${path[0]}");
    var path2 = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_MUSIC);
    print("DIRECTORY_MUSIC: ${path2}");
    */
  }


  bool isMP3(File file) {
    return file.path.toLowerCase().endsWith('.mp3') 
      || file.path.toLowerCase().endsWith('.mp4');
  }
}