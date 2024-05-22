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
    String blackList = "";
    List<dynamic> arr = await Storage.getJsonList("BlackList");
    for(var i = 0; i < arr.length; i++) {
      blackList += "'${arr[i]}'";
    }

    // blackList = "'MyTube'";
    String root = await Archive.root();
    List<dynamic> list = [];
    String path = directoryPath.replaceAll("$root/", "");
    
    if(!(path.startsWith(".") || path.startsWith("Android") || blackList.contains("'$path'"))) {
      var dirList1 = Directory(directoryPath).list();
      int count = 0;
      await for (final FileSystemEntity f1 in dirList1) {
        if (f1 is Directory) {
          var list2 = await getDirectories(f1.path);
          if(list2.isNotEmpty) {
            list = list + list2;
          }
        } else if(f1 is File && isMusic(f1)) {
          count++;          
        }
      }
      if(count > 0) {
        var paths = directoryPath.split('/');
        String title = paths[paths.length - 1];
        dynamic json = {"title": title, "path": path, "count": count};
        list.add(json);
        // print(json);
      }
    }
    return list;
  }

  Future<List<String>> getFiles(String directoryPath) async {
    String root = await Archive.root();
    List<String> list = [];
    var dirList1 = Directory("$root/$directoryPath").list();
    await for (final FileSystemEntity f1 in dirList1) {
      if(f1 is File && isMusic(f1)) {
        var paths = f1.path.split('/');
        String title = paths[paths.length - 1];
        list.add(title);
      }
    }
    if(directoryPath == "MyTube2") {
      return list..sort((b, a) => a.compareTo(b));
    } else {
      return list..sort();
    }
  }

  bool isMusic(File file) {
    return file.path.toLowerCase().endsWith('.mp3') 
      || file.path.toLowerCase().endsWith('.mp4')
      || file.path.toLowerCase().endsWith('.3gpp')
      || file.path.toLowerCase().endsWith('.webm');
  }
}