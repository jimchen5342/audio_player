 import 'package:flutter/material.dart';

 void loading(BuildContext context, {Function(BuildContext)? onReady}){
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      if(onReady is Function) {
        onReady!(context);
      }
      return Dialog(
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
