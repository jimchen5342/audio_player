import 'dart:async';
import 'package:flutter/material.dart';

Future<void> alert(BuildContext context, String msg, {List<Widget>? btns}) {
  btns = btns ?? [
    TextButton(
      child: const Text('確定',
          style: TextStyle(
            color:Colors.blue,
            fontSize: 16
          )),
      onPressed: () async {
        Navigator.of(context).pop();
      },
    )
  ];
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5.0))),
        title: const Text('音樂播放器'),
        // barrierDismissible: false,
        // contentPadding: EdgeInsets.all(20),
        content: Text(msg,
          style: const TextStyle(
            // color:Colors.white,
            fontSize: 18
          )
        ),
        actions: btns,
      );
    },
  );
}

void loading(BuildContext context, {Function(BuildContext)? onReady}){
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      if(onReady is Function) {
        onReady!(context);
      }
      return Dialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5.0))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(height: 15, width: 0),
            CircularProgressIndicator(),
            Container(height: 15, width: 0),
            const Text("Loading......",
              style: TextStyle(
                color: Colors.blue,
                fontSize: 20,
              )
            ),
            Container(height: 15, width: 0),
          ],
        ),
      );
    },
  );
}

Future<void> setTimeout(Function() callback, int ms) async {
  await Future.delayed(Duration(milliseconds: ms), callback); 
}