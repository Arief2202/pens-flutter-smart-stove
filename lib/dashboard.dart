// ignore_for_file: curly_braces_in_flow_control_structures, prefer_const_constructors, sort_child_properties_last, unused_local_variable, unused_import, must_be_immutable, use_build_context_synchronously

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

import 'package:pens_smart_stove/global_var.dart' as globals;
import 'notification.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => DashboardState();
}

class DashboardState extends State<Dashboard> {
  List<TextEditingController> _data = [TextEditingController()];
  bool status = false;
  Timer? timer;
  TimeOfDay _time = TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _duration = TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _stopAt = TimeOfDay(hour: 0, minute: 0);
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  DateTime now = DateTime.now();
  int timerDoneRunning = 0;
  bool stoveState = false;
  int sensorGas = 0;
  int sensorGas2 = 0;
  bool sensorApi = false;
  bool kebocoran = false;
  String lastUpdatedData = '';

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
    timer = Timer.periodic(Duration(milliseconds: 1000), (Timer t) => updateValue());
    _initSpeech();
    getEndpoint();
    notif.initialize(flutterLocalNotificationsPlugin);
    super.initState();
  }

  void getEndpoint() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? endpoint = prefs.getString('endpoint');
    if (endpoint != null) {
      setState(() {
        _data[0].text = endpoint;
        globals.endpoint = endpoint;
      });
    } else {
      _data[0].text = "0.0.0.0";
      globals.endpoint = "0.0.0.0";
    }
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
      notif.showNotif(
      id: 1,
      head: "Status Timer",
      body: "Timer Berjalan",
      fln: flutterLocalNotificationsPlugin);
      await http.post(
        Uri.parse("http://${globals.endpoint}/api.php"),
        headers: <String, String>{
          'Content-Type':
              'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: "createStove&status=1",
      );
    }
    if(timerDoneRunning == 2){
      if(start.isAfter(end2)){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Timer Berhenti")));
        print("Timer Stopped");
        setState((){
          timerDoneRunning = 0;
          stoveState = false;
        });
        notif.showNotif(
        id: 1,
        head: "Status Timer",
        body: "Timer Berhenti",
        fln: flutterLocalNotificationsPlugin);
        await http.post(
          Uri.parse("http://${globals.endpoint}/api.php"),
          headers: <String, String>{
            'Content-Type':
                'application/x-www-form-urlencoded; charset=UTF-8',
          },
          body: "createStove&status=0",
        );
      }
    }
    
    setState((){
      if(end_hour >= 0 && end_minute >= 0){
        _stopAt = TimeOfDay(hour: end_hour, minute: end_minute);
      }
      now = DateTime.now();
    });

    var url = Uri.parse("http://${globals.endpoint}/api.php?read");
    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          // Time has run out, do what you wanted to do.
          return http.Response(
              'Error', 408); // Request Timeout response status code
        },
      );
      print(response.statusCode);
      // context.loaderOverlay.hide();
      if (response.statusCode == 200) {
        var respon = Json.tryDecode(response.body);
        if (this.mounted) {
          setState(() {            
            stoveState = respon['data']['stove_status'] == '1' ? true : false;
            sensorGas = int.parse(respon['data']['sensor_1']);
            sensorGas2 = int.parse(respon['data']['sensor_2']);
            sensorApi = respon['data']['sensor_fire'] == '1' ? true : false;
            kebocoran = respon['data']['bocor'] == '1' ? true : false;
            lastUpdatedData = respon['data']['created_at'];
          });
        }
        if(respon['notifs'].length > 0){
          for(int a=0; a<respon['notifs'].length; a++){
            notif.showNotif(
                id: int.parse(respon['notifs'][a]['id']),
                head: respon['notifs'][a]['header'],
                body: respon['notifs'][a]['body'],
                fln: flutterLocalNotificationsPlugin);
            await http.post(
              Uri.parse("http://${globals.endpoint}/api.php"),
              headers: <String, String>{
                'Content-Type':
                    'application/x-www-form-urlencoded; charset=UTF-8',
              },
              body: "updateNotif&id=${respon['notifs'][a]['id']}&is_show=1",
            );
          }
        }
        // if (respon['notifs']['notif']['show']) {
        //   notif.showNotif(
        //       id: respon['mq4']['notif']['id'],
        //       head: respon['mq4']['notif']['header'],
        //       body: respon['mq4']['notif']['body'],
        //       fln: flutterLocalNotificationsPlugin);
        //   await http.post(
        //     Uri.parse("http://${globals.endpoint}/updateNotif"),
        //     headers: <String, String>{
        //       'Content-Type':
        //           'application/x-www-form-urlencoded; charset=UTF-8',
        //     },
        //     body: "sensor=MQ4",
        //   );
        // }
        // if (respon['mq7']['notif']['show']) {
        //   notif.showNotif(
        //       id: respon['mq7']['notif']['id'],
        //       head: respon['mq7']['notif']['header'],
        //       body: respon['mq7']['notif']['body'],
        //       fln: flutterLocalNotificationsPlugin);
        //   await http.post(
        //     Uri.parse("http://${globals.endpoint}/updateNotif"),
        //     headers: <String, String>{
        //       'Content-Type':
        //           'application/x-www-form-urlencoded; charset=UTF-8',
        //     },
        //     body: "sensor=MQ7",
        //   );
        // }
      }
    } on Exception catch (_) {
      // rethrow;
    }


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
  void _onSpeechResult(SpeechRecognitionResult result) async {
    if(result.recognizedWords.toUpperCase() == "NYALAKAN KOMPOR"){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Menjalankan Perintah : " + result.recognizedWords)));
      setState(() {
        stoveState = true;
      });
      await http.post(
        Uri.parse("http://${globals.endpoint}/api.php"),
        headers: <String, String>{
          'Content-Type':
              'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: "createStove&status=1",
      );
    }
    else if(result.recognizedWords.toUpperCase() == "MATIKAN KOMPOR"){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Menjalankan Perintah : " + result.recognizedWords)));
      setState(() {
        stoveState = false;
      });
      await http.post(
        Uri.parse("http://${globals.endpoint}/api.php"),
        headers: <String, String>{
          'Content-Type':
              'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: "createStove&status=0",
      );
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
              IconButton(
                  icon: const Icon(Icons.settings,
                      color: Colors.white, size: 20.0),
                  onPressed: () async {
                    //================================ ALERT UNTUK SETTING API ========================================
                    Alert(
                      context: context,
                      // type: AlertType.info,
                      desc: "Setting API",
                      content: Column(
                        children: <Widget>[
                          SizedBox(
                              height: MediaQuery.of(context).size.width / 15),
                          TextField(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'IP Endpoint',
                              labelStyle: TextStyle(fontSize: 20),
                            ),
                            controller: _data[0],
                          ),
                        ],
                      ),
                      buttons: [
                        DialogButton(
                            child: Text(
                              "Save",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20),
                            ),
                            onPressed: () async {
                              if (_data[0].text.isEmpty) {
                                status = false;
                                Alert(
                                  context: context,
                                  type: AlertType.error,
                                  title: "Value Cannot be Empty!",
                                  buttons: [
                                    DialogButton(
                                      child: Text(
                                        "OK",
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 20),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                    )
                                  ],
                                ).show();
                              } else {
                                var url = Uri.parse('http://' +
                                    _data[0].text +
                                    '/checkConnection.php');
                                try {
                                  final response = await http.get(url).timeout(
                                    const Duration(
                                        seconds: globals.httpTimeout),
                                    onTimeout: () {
                                      // Time has run out, do what you wanted to do.
                                      return http.Response('Error',
                                          408); // Request Timeout response status code
                                    },
                                  );
                                  // context.loaderOverlay.hide();
                                  if (response.statusCode == 200) {
                                    Alert(
                                      context: context,
                                      type: AlertType.success,
                                      title: "Connection OK",
                                      buttons: [
                                        DialogButton(
                                            child: Text(
                                              "OK",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20),
                                            ),
                                            onPressed: () async {
                                              final SharedPreferences prefs =
                                                  await SharedPreferences
                                                      .getInstance();
                                              setState(() {
                                                globals.endpoint =
                                                    _data[0].text;
                                                prefs.setString(
                                                    "endpoint", _data[0].text);
                                              });
                                              Navigator.pop(context);
                                              Navigator.pop(context);
                                            })
                                      ],
                                    ).show();
                                  } else {
                                    Alert(
                                      context: context,
                                      type: AlertType.error,
                                      title: "Connection Failed!",
                                      desc: "Please check Endpoint IP",
                                      buttons: [
                                        DialogButton(
                                          child: Text(
                                            "OK",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20),
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                        )
                                      ],
                                    ).show();
                                  }
                                } on Exception catch (_) {
                                  Alert(
                                    context: context,
                                    type: AlertType.error,
                                    title: "Connection Failed!",
                                    desc: "Please check Endpoint IP",
                                    buttons: [
                                      DialogButton(
                                        child: Text(
                                          "OK",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20),
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      )
                                    ],
                                  ).show();
                                  // rethrow;
                                }
                              }
                            }),
                      ],
                    ).show();

                    //================================ END ALERT UNTUK SETTING API ========================================
                  })
            ],
      ),
      body: SingleChildScrollView(
        child: 
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                  Padding(padding: EdgeInsets.all(10)),
                  Text("Sekarang Jam = " +  (now.hour < 10 ? "0" : "") + now.hour.toString() + ":" +  (now.minute < 10 ? "0" : "") + now.minute.toString() + ":" +  (now.second < 10 ? "0" : "") + now.second.toString()),
                  Padding(padding: EdgeInsets.all(10)),
                  Divider(color: Colors.black),
                  Padding(padding: EdgeInsets.all(10)),
                  Text("Data Timestamp = " + lastUpdatedData),
                  Text("Kompor Status = " + (stoveState ? "ON" : "OFF")),
                  Text("Sensor GAS   = " + sensorGas.toString() + " ppm"),
                  Text("Sensor GAS 2 = " + sensorGas2.toString() + " ppm"),
                  Text("Sensor Api = " + (sensorApi ? "Ada Api" : "Tidak Ada Api")),
                  Text("Kebocoran = " + (sensorApi ? "Terdeteksi Kebocoran" : "Tidak Ada Kebocoran")),
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
              ],
            ),
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


class Json {
  static String? tryEncode(data) {
    try {
      return jsonEncode(data);
    } catch (e) {
      return null;
    }
  }

  static dynamic tryDecode(data) {
    try {
      return jsonDecode(data);
    } catch (e) {
      return null;
    }
  }
}
