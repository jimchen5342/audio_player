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
  static Future<String> root() async {
    List<String>? pathes = await ExternalPath.getExternalStorageDirectories();
    if (pathes != null && pathes.isNotEmpty) {
      return pathes[0];
    }
    return "";
  }

  Future<List<dynamic>> getDirectories(String directoryPath, String blackList) async {
    // blackList = "'MyTube'";
    String root = await Archive.root();
    List<dynamic> list = [];
    String path = directoryPath.replaceAll("$root/", "");
    
    if(!(path.startsWith(".") || path.startsWith("Android") || blackList.contains("'$path'"))) {
      var dirList1 = Directory(directoryPath).list();
      int count = 0;
      await for (final FileSystemEntity f1 in dirList1) {
        if (f1 is Directory) {
          if(!isIgnoreDirectory(f1.path)) {
            var list2 = await getDirectories(f1.path, blackList);
            if(list2.isNotEmpty) {
              list = list + list2;
            }
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

  bool isIgnoreDirectory(String path) {
    return path.contains("DCIM")
      || path.contains("LINE") 
      || path.contains("來電")
      || path.contains("Ringtone");
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
    return list..sort();
  }

  bool isMusic(File file) {
    if(file.path.contains("/大家的日本語/") && file.path.contains(".trashed")) {
      deleteExternalFile(file.path);
      return false;
    } else {
      return file.path.toLowerCase().endsWith('.mp3') 
        || file.path.toLowerCase().endsWith('.mp4')
        || file.path.toLowerCase().endsWith('.3gpp')
        || file.path.toLowerCase().endsWith('.webm');
    }
  }

  Future<void> deleteExternalFile(String externalFilePath) async {
    try {
      final file = File(externalFilePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }

  Future<void> createFolder(String externalFilePath) async {
    final directory = Directory(externalFilePath);
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } catch (e) {
      print('Failed to create folder: $e');
    }
  }
}