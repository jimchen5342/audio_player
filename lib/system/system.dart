import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_platform_alert/flutter_platform_alert.dart';
export 'package:flutter_platform_alert/flutter_platform_alert.dart';

import 'package:flutter_easyloading/flutter_easyloading.dart';
export 'package:flutter_easyloading/flutter_easyloading.dart';


Future<void> setTimeout(Function() callback, int ms) async {
  await Future.delayed(Duration(milliseconds: ms), callback); 
}


Future<String> alert(String text, {AlertButtonStyle btn = AlertButtonStyle.ok}) async {
  await FlutterPlatformAlert.playAlertSound();

  final clickedButton = await FlutterPlatformAlert.showAlert(
    windowTitle: 'MyTube2',
    text: text,
    alertStyle: btn,
    iconStyle: IconStyle.information,
  );
  // print("btn: ${clickedButton.toString()} / ${clickedButton.name}");
  return clickedButton.name.replaceAll("Button", "");
}

Future<int> customAlert(String text, {required String positive, String? negative, String? neutral}) async { // 還沒好, 2024-05-10
  await FlutterPlatformAlert.playAlertSound();

  final result = await FlutterPlatformAlert.showCustomAlert(
    windowTitle: 'MyTube2',
    text: 'This is body',
    positiveButtonTitle: positive, // result.index = 0
    negativeButtonTitle: negative, // result.index = 1
    neutralButtonTitle: null, // result.index = 2
    options: PlatformAlertOptions(
      windows: WindowsAlertOptions(
        additionalWindowTitle: 'Window title',
        showAsLinks: true,
      ),
    ),
  );
  print(result.index);
  return result.index;
}