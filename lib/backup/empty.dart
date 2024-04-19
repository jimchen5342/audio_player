import 'package:flutter/material.dart';

class Empty extends StatefulWidget {
  Empty({Key? key}) : super(key: key);
  @override
  _EmptyState createState() => _EmptyState();
}

class _EmptyState extends State<Empty> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {

    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  @override
  void reassemble() async { // develope mode
    super.reassemble();
  }


  @override
  dispose() {
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {

    return Container();
  }
}