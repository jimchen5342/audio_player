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
    var pathes = await ExternalPath.getExternalStorageDirectories();
    return "${pathes[0]}";
  }

  Future<List<dynamic>> getDirectories_old() async {
    String root = await Archive.root();
    var xx = await getDirectories(root);
    print(xx);
    List<dynamic> list = [];

    // var dirList1 = Directory(root).list();
    // var b1 = false;
    // await for (final FileSystemEntity f1 in dirList1) {
    //   if (f1 is Directory) {
    //     // 第一層 start
    //     print("Directory: " + f1.path);
    //     var dirList2 = Directory(f1.path).list();
    //     var b2 = false;
    //     await for (final FileSystemEntity f2 in dirList2) {
    //       if (f2 is Directory) {
    //         // 第二層 start
    //         print("Directory: " + f2.path);
    //         var dirList3 = Directory(f2.path).list();
    //         var b3 = false;
    //         await for (final FileSystemEntity f3 in dirList3) {
    //           if (f3 is Directory) {
                
    //           } else if(b3 == true) {
    //             continue;
    //           } else if(f3 is File && (f3.path.toLowerCase().endsWith('.mp3') || f3.path.toLowerCase().endsWith('.mp4'))) {
    //             b3 = true;
    //             list.add({"title": f2.path.replaceAll("${f1.path}/", ""), "path": f2.path});
    //           }
    //         }
    //         // 第二層 end
    //       } else if(b2 == true) {
    //         continue;
    //       } else if(f2 is File && (f2.path.toLowerCase().endsWith('.mp3') || f2.path.toLowerCase().endsWith('.mp4'))) {
    //         b2 = true;
    //         list.add({"title": f1.path.replaceAll("$root/", ""), "path": f1.path});
    //         print("==> 2: " + f1.path.replaceAll(root + "/", ""));
    //       }
    //     }
    //     // 第一層 end
    //   } else if(b1 == true) {
    //     continue;
    //   } else if(f1 is File && (f1.path.toLowerCase().endsWith('.mp3') || f1.path.toLowerCase().endsWith('.mp4'))) {
    //     b1 = true;
    //     list.add({"title": f1.path.replaceAll("$root/", ""), "path": f1.path});
    //     print("==> 2: " + f1.path.replaceAll(root + "/", ""));
    //   }
    // }
    return list;
  }

  Future<List<dynamic>> getDirectories(String directoryPath) async {
    String root = await Archive.root();
    List<dynamic> list = [];
    String path = directoryPath.replaceAll("$root/", "");
    if(path.startsWith(".") == false) {
      var dirList1 = Directory(directoryPath).list();
      var b1 = false;
      await for (final FileSystemEntity f1 in dirList1) {
        if (f1 is Directory) {
          if(f1.path.startsWith(".") == false) {
            var list2 = await getDirectories(f1.path);
            if(list2.isNotEmpty) {
              list = list + list2;
            }
          }
        } else if(b1 == true) {
          continue;
        } else if(f1 is File && (f1.path.toLowerCase().endsWith('.mp3') || f1.path.toLowerCase().endsWith('.mp4'))) {
          print(f1.path);
          var paths = directoryPath.split('/');
          String title = paths[paths.length - 1];
          if(title.startsWith(".") == false) {
            b1 = true;
            
            print("$title; $path");
            dynamic json = {"title": title, "path": path};
            list.add(json);            
          }
        }
      }
    }
    // print(list);
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