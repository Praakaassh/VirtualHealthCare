import 'package:flutter/material.dart';


class splashscreen extends StatefulWidget {
  final Widget? child;
  const splashscreen({super.key, this.child});

  @override
  State<splashscreen> createState() => _splashscreenState();
}

class _splashscreenState extends State<splashscreen> {
  @override
  void initState() {
    Future.delayed(
      Duration(seconds: 3),
        (){
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => widget.child!),(route) => false);
        }
    );
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Logo'),
      ),
    );
  }
}
