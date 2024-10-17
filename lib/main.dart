import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:firebase_core/firebase_core.dart';

import 'login.dart';
import 'register.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(PrivateChatApp());
}

class PrivateChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.hasData) {
            return ChatScreen();
          } else {
            return LoginScreen();
          }
        },
      ),
      routes: {
        '/chat': (context) => ChatScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class Message {
  final String? text;
  final Uint8List? file;
  final String? mimeType;
  final String? type;

  Message({this.text, this.file, this.mimeType, this.type});
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  final ImagePicker _picker = ImagePicker();
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _openRecorder();
    _openPlayer();
  }

  Future<void> _openRecorder() async {
    try {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException("Microphone permission not granted");
      }
      if (_recorder != null) {
        await _recorder!.openRecorder();
      }
    } catch (e) {
      print("Error opening recorder: \$e");
    }
  }

  Future<void> _openPlayer() async {
    await _player!.openPlayer();
  }

  Future<void> _sendMessage({String? text, XFile? file, String? type}) async {
    if (text == null && file == null) return;

    Uint8List? fileData;
    String? mimeType;

    if (file != null) {
      fileData = await file.readAsBytes();
      mimeType = lookupMimeType(file.path);
    }

    setState(() {
      _messages.add(Message(
        text: text,
        file: fileData,
        mimeType: mimeType,
        type: type,
      ));
      _controller.clear();
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _sendMessage(file: image, type: 'image');
    }
  }

  Future<void> _startRecording() async {
    if (_recorder != null) {
      await _recorder!.startRecorder(toFile: 'voice_note.aac');
    }
  }

  Future<void> _stopRecording() async {
    if (_recorder != null) {
      String? filePath = await _recorder!.stopRecorder();
      if (filePath != null) {
        await _sendMessage(file: XFile(filePath), type: 'audio');
      }
    }
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _player?.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Elle"),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // TODO: Open settings screen in future
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: index % 2 == 0 ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    decoration: BoxDecoration(
                      color: index % 2 == 0 ? Colors.deepPurple[400] : Colors.blueGrey[700],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.text != null)
                          Text(
                            message.text!,
                            style: TextStyle(color: Colors.white),
                          ),
                        if (message.file != null && message.type == 'image')
                          Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Image.memory(
                              message.file!,
                              width: 150,
                            ),
                          ),
                        if (message.file != null && message.type == 'audio')
                          Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Row(
                              children: [
                                Icon(Icons.audiotrack, color: Colors.tealAccent),
                                SizedBox(width: 10),
                                Text(
                                  "Audio message",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                IconButton(
                                  icon: Icon(Icons.play_arrow, color: Colors.tealAccent),
                                  onPressed: () async {
                                    if (_player!.isPlaying) {
                                      await _player!.stopPlayer();
                                    } else {
                                      await _player!.startPlayer(
                                        fromURI: File.fromRawPath(message.file!).path,
                                        codec: Codec.aacADTS, // Using AAC format for the file recorded
                                        whenFinished: () {
                                          // Update UI when playback finishes
                                        },
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.mic),
                  onPressed: () async {
                    await _startRecording();
                  },
                  color: Colors.redAccent,
                ),
                IconButton(
                  icon: Icon(Icons.stop),
                  onPressed: () async {
                    await _stopRecording();
                  },
                  color: Colors.redAccent,
                ),
                IconButton(
                  icon: Icon(Icons.photo),
                  onPressed: _pickImage,
                  color: Colors.tealAccent,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => _sendMessage(text: _controller.text),
                  color: Colors.tealAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
