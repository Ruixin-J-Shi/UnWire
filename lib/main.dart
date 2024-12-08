/// Main entry point for the Nearby Group Chat app.
/// Accessibility Notes:
/// - The login page and subsequent pages should be accessible with screen readers.
/// - Buttons and images have semantic labels or descriptive text.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_room.dart';
import 'help_page.dart'; // Import our new HelpPage

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nearby Group Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController(text: "");
  final picker = ImagePicker();
  String? image;

  void chooseImage() async {
    XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery, maxHeight: 600, maxWidth: 600);

    if (pickedFile != null) {
      List<int> fileBytes = await File(pickedFile.path).readAsBytes();
      String base64String = base64Encode(fileBytes);
      setState(() {
        image = base64String;
      });
    }
  }

  void loginWithNameAndImage() {
    final name = _usernameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please input a name.")));
      return;
    }
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please choose an image.")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoom(
          myName: name,
          myImage: image!,
        ),
      ),
    );
  }

  void loginWithoutNameAndImage() async {
    final randomName = "User${Random().nextInt(10000)}";
    String defaultImageBase64 = "";

    try {
      // Load default avatar from images/default_avatar.png
      final bytes = await rootBundle.load('images/default_avatar.png');
      defaultImageBase64 = base64Encode(bytes.buffer.asUint8List());
    } catch (e) {
      // If not found or fails, just use an empty string (no image)
      defaultImageBase64 = "";
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoom(
          myName: randomName,
          myImage: defaultImageBase64,
        ),
      ),
    );
  }

  void toHelp() {
    // Navigate to HelpPage
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Accessibility: Buttons have descriptive text. Images have semantic labels.
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          shadowColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.transparent,
          leading: Container(),
          toolbarHeight: 80,
          systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light)),
      backgroundColor: const Color(0xff252d38),
      body: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                const Text(
                  "UnWire",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 45,
                      fontStyle: FontStyle.italic),
                  semanticsLabel: 'App title: UnWire',
                ),
                const Text(
                  "Choose an Image & Display Name",
                  style: TextStyle(color: Colors.white),
                  semanticsLabel: 'Instruction: Choose an Image & Display Name',
                ),
                const SizedBox(height: 50),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: chooseImage,
                  child: image == null
                      ? Image.asset(
                          "images/img.jpg",
                          width: 100,
                          semanticLabel: 'Default avatar image placeholder',
                        )
                      : Image.memory(
                          base64Decode(image!),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          semanticLabel: 'User selected avatar',
                        ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Enter",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold),
                  semanticsLabel: 'Enter your display name',
                ),
                const SizedBox(height: 20),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10)),
                  child: Semantics(
                    label: 'Username TextField',
                    child: TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Username',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                InkWell(
                  onTap: loginWithNameAndImage,
                  child: Container(
                    height: 40,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: const Color(0xff455b5d),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text(
                      "Login",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      semanticsLabel: 'Login button',
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Or",
                  style: TextStyle(color: Colors.white),
                  semanticsLabel: 'Or',
                ),
                const SizedBox(height: 20),
                InkWell(
                    onTap: loginWithoutNameAndImage,
                    child: Container(
                      height: 40,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: const Color(0xff455b5d),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        "Login without name and image",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        semanticsLabel: 'Login without name and image button',
                      ),
                    )),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: toHelp,
                  child: const Text(
                    "Need help? Visit our help center",
                    style: TextStyle(color: Colors.white),
                    semanticsLabel: 'Go to help center',
                  ),
                )
              ],
            ),
          )),
    );
  }
}
