import 'package:flutter_platform_alert/flutter_platform_alert.dart';
export 'package:flutter_platform_alert/flutter_platform_alert.dart';
// ignore: unused_import
import 'package:flutter_easyloading/flutter_easyloading.dart';
export 'package:flutter_easyloading/flutter_easyloading.dart';


Future<void> setTimeout(Function() callback, int ms) async {
  await Future.delayed(Duration(milliseconds: ms), callback); 
}


Future<String> alert(String text, {AlertButtonStyle btn = AlertButtonStyle.ok}) async {
  await FlutterPlatformAlert.playAlertSound();

  final clickedButton = await FlutterPlatformAlert.showAlert(
    windowTitle: '播放器',
    text: text,
    alertStyle: btn,
    iconStyle: IconStyle.information,
  );
  // print("btn: ${clickedButton.toString()} / ${clickedButton.name}");
  return clickedButton.name.replaceAll("Button", "");
}
