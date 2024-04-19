import 'package:external_path/external_path.dart';
import 'dart:io';
/*
await ExternalPath.getExternalStorageDirectories();

await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_MUSIC);
ExternalPath.DIRECTORY_PICTURES
ExternalPath.DIRECTORY_DOWNLOADS
ExternalPath.DIRECTORY_DCIM
ExternalPath.DIRECTORY_DOCUMENTS
 */

class Archive {
  static String root = "";

  Future<List<String>> search() async {
    List<String> list = [];
    var pathes = await ExternalPath.getExternalStorageDirectories();
    for (var path in pathes) {
      var dir = Directory(path);
      var dirList = dir.list();
      await for (final FileSystemEntity f in dirList) {
        if (f is Directory) {
          await isMP3(f.path);
        }
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


  Future<bool> isMP3(String directoryPath) async {
    final Directory dir = Directory(directoryPath);
     try {
      var dirList = dir.list();
      await for (final FileSystemEntity f in dirList) {
        if (f is File) {
          if (f.path.endsWith('.mp3')) {
            return true;
          }
          print('Found file ${f.path}');
        } else if (f is Directory) {
          print('Found dir ${f.path}');
        }
      }
    } catch (e) {
      print(e.toString());
    }
    return false;
  }
}