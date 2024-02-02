// ignore_for_file: curly_braces_in_flow_control_structures, prefer_const_constructors, sort_child_properties_last, unused_local_variable, unused_import, must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:hold_down_button/hold_down_button.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => DashboardState();
}

class DashboardState extends State<Dashboard> {
  Timer? timer;
  TimeOfDay _time = TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _duration = TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _stopAt = TimeOfDay(hour: 0, minute: 0);
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool stoveState = false;
  String _lastWords = '';
  DateTime now = DateTime.now();
  int timerDoneRunning = 0;
  int sensorGas = 5;
  bool sensorApi = false;

  void _selectTime() async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    setState((){
      timerDoneRunning = 1;
    });
    if (newTime != null) {
      setState(() {
        _time = newTime;
      });
    }
  }
  void _selectTime2() async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: _duration,
    );
    setState((){
      timerDoneRunning = 1;
    });
    if (newTime != null) {
      setState(() {
        _duration = newTime;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(Duration(milliseconds: 100), (Timer t) => updateValue());
    _initSpeech();
    super.initState();
  }

  void updateValue() async {
    var end_hour = _time.hour + _duration.hour;
    var end_minute = _time.minute + _duration.minute;
    if(end_minute >= 60){
      end_minute = end_minute - 60;
      end_hour = end_hour+1;
    }
    if(end_hour >= 24){
      end_hour = end_hour - 24;
    }
    var format = DateFormat("HH:mm");
    var start = format.parse("${now.hour}:${now.minute}");
    var end = format.parse("${_time.hour}:${_time.minute == 0 ? _time.minute : _time.minute-1}");
    var end2 = format.parse("${end_hour}:${end_minute == 0 ? end_minute : end_minute-1}");

    if(timerDoneRunning == 1 && start.isAfter(end)){
      print("Timer Running");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Timer Berjalan")));
      setState((){
        timerDoneRunning = 2;
        stoveState = true;
      });
    }
    if(timerDoneRunning == 2){
      if(start.isAfter(end2)){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Timer Berhenti")));
        print("Timer Stopped");
        setState((){
          timerDoneRunning = 0;
          stoveState = false;
        });
      }
    }
    
    setState((){
      if(end_hour >= 0 && end_minute >= 0){
        _stopAt = TimeOfDay(hour: end_hour, minute: end_minute);
      }
      now = DateTime.now();
    });
  }
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    if(result.recognizedWords.toUpperCase() == "NYALAKAN KOMPOR"){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Menjalankan Perintah : " + result.recognizedWords)));
      setState(() {
        stoveState = true;
      });
    }
    else if(result.recognizedWords.toUpperCase() == "MATIKAN KOMPOR"){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Menjalankan Perintah : " + result.recognizedWords)));
      setState(() {
        stoveState = false;
      });
    }
    else if(result.recognizedWords.toUpperCase() == "NYALAKAN TIMER"){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Menjalankan Perintah : " + result.recognizedWords)));
      setState(() {
        timerDoneRunning = 1;
      });
    }
    else if(result.recognizedWords.toUpperCase() == "MATIKAN TIMER"){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Menjalankan Perintah : " + result.recognizedWords)));
      setState(() {
        timerDoneRunning = 0;
      });
    }
    else if(_speechToText.isNotListening){
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Perintah tidak dikenali : " + result.recognizedWords)));
    }
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMART STOVE',
                  style: TextStyle(color: Colors.white),
                ),
        backgroundColor: Colors.blue,
        actions: <Widget>[
          // IconButton(
          //   icon: const Icon(Icons.add_alert),
          //   tooltip: 'Show Snackbar',
          //   onPressed: () {
          //     // ScaffoldMessenger.of(context).showSnackBar(
          //     //     const SnackBar(content: Text('This is a snackbar')));
          //   },
          // ),
          // IconButton(
          //   icon: const Icon(Icons.navigate_next),
          //   tooltip: 'Go to the next page',
          //   onPressed: () {
          //     Navigator.push(context, MaterialPageRoute<void>(
          //       builder: (BuildContext context) {
          //         return Scaffold(
          //           appBar: AppBar(
          //             title: const Text('Next page'),
          //           ),
          //           body: const Center(
          //             child: Text(
          //               'This is the next page',
          //               style: TextStyle(fontSize: 24),
          //             ),
          //           ),
          //         );
          //       },
          //     ));
          //   },
          // ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
              Padding(padding: EdgeInsets.all(10)),
              Text("Sekarang Jam = " +  (now.hour < 10 ? "0" : "") + now.hour.toString() + ":" +  (now.minute < 10 ? "0" : "") + now.minute.toString() + ":" +  (now.second < 10 ? "0" : "") + now.second.toString()),
              Padding(padding: EdgeInsets.all(10)),
              Divider(color: Colors.black),
              Padding(padding: EdgeInsets.all(10)),
              Text("Kompor Status = " + (stoveState ? "ON" : "OFF")),
              Text("Sensor GAS  = " + sensorGas.toString() + " ppm"),
              Text("Sensor Api = " + (sensorApi ? "Ada Api" : "Tidak Ada Api")),
              Padding(padding: EdgeInsets.all(10)),
              Divider(color: Colors.black),
              Padding(padding: EdgeInsets.all(10)),
              ElevatedButton(
                onPressed: _selectTime,
                child: Text('SET JAM KOMPOR AKTIF',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold
                ),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
              ),
              Padding(padding: EdgeInsets.all(5)),
              Text("Kompor aktif di jam = " + (_time.hour < 10 ? "0" : "") + _time.hour.toString() + ":" + (_time.minute < 10 ? "0" : "") + _time.minute.toString()),
              Padding(padding: EdgeInsets.all(10)),
              Divider(color: Colors.black),
              Padding(padding: EdgeInsets.all(10)),
              ElevatedButton(
                onPressed: _selectTime2,
                child: Text('SET TIMER KOMPOR',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold
                ),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
              ),
              Padding(padding: EdgeInsets.all(5)),
              Text("Timer kompor = " + (_duration.hour < 10 ? "0" : "") + _duration.hour.toString() + ":" + (_duration.minute < 10 ? "0" : "") + _duration.minute.toString()),
              Padding(padding: EdgeInsets.all(5)),
              Divider(color: Colors.black),
              Padding(padding: EdgeInsets.all(10)),
              Text("Kompor mati di jam = " + (_stopAt.hour < 10 ? "0" : "") + _stopAt.hour.toString() + ":" + (_stopAt.minute < 10 ? "0" : "") + _stopAt.minute.toString()),
              Text("Timer telah selesai berjalan = " + (timerDoneRunning > 0 ? "Belum" : "Sudah")),
              Padding(padding: EdgeInsets.all(10)),
              Divider(color: Colors.black),
              Padding(padding: EdgeInsets.all(10)),
                // Text(
                //   // If listening is active show the recognized words
                //   _speechToText.isListening
                //       ? '$_lastWords'
                //       // If listening isn't active but could be tell the user
                //       // how to start it, otherwise indicate that speech
                //       // recognition is not yet ready or not supported on
                //       // the target device
                //       : _speechEnabled
                //           ? 'Tap the microphone to start listening...\n\n'
                //           : 'Speech not available\n\n',
                // ),
                // Container(),
                // Text('$_lastWords'),
                
                
                
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: 30, left: 10, right: 10),
        child: 
          HoldDownButton(
            onHoldDown: _startListening,
            child: ElevatedButton(
              onPressed: _startListening,
              child: Text(_speechToText.isNotListening ? 'Tahan Untuk Memberi Perintah Suara' : 'Listening',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold
                ),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
            ),
          ),
      ),
    );
  }
}