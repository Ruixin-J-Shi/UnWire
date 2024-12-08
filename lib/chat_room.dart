import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nearby_service/nearby_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // Ensure image_picker is added in pubspec.yaml
import 'utils/app_snack_bar.dart';

// Simple User model
class User {
  int id;
  String? headimg;
  String? nickname;
  User({required this.id, this.headimg, this.nickname});
}

// ChatMessage model
class ChatMessage {
  int? id;
  int? sender; // 1 for local, 2+ for remote
  String? headimg;
  String? nickname;
  String? type; // "text" or "image"
  String? text;
  String? image; // base64 string for image
  int? time;
}

class ChatRoom extends StatefulWidget {
  final String myName;
  final String myImage; // base64 encoded image

  const ChatRoom({
    super.key,
    required this.myName,
    required this.myImage,
  });

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> {
  final _nearbyService = NearbyService.getInstance(logLevel: NearbyServiceLogLevel.debug);
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<NearbyDevice> _connectedDevices = [];
  List<NearbyDevice> _peers = [];

  final Map<String, String> _deviceChosenNames = {};
  final Map<String, String> _deviceChosenImages = {};

  StreamSubscription<List<NearbyDevice>>? _peersSubscription;
  bool _initialized = false;
  bool _popupShown = false;
  Timer? _introTimer;
  bool _burstActive = false;

  // Users list: user id=1 local user, id=2... remote users
  List<User> users = [];
  // Chat messages
  List<ChatMessage> list = [];

  int _remoteUserIdCounter = 2; // Assign incremental IDs to connected devices
  Map<String,int> _deviceIdToUserId = {};
  Map<int,String> _userIdToDeviceId = {};

  // Cached images
  final Map<String,MemoryImage> _cachedMemoryImages = {};
  MemoryImage? _localUserImageMemory;

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initService();
    // Add local user to the user list
    users.add(User(id: 1, headimg: widget.myImage, nickname: widget.myName));
    // Cache local user image if available
    if (widget.myImage.isNotEmpty) {
      _localUserImageMemory = MemoryImage(base64Decode(widget.myImage));
    }
  }

  Future<void> _initService() async {
    await _nearbyService.initialize();
    setState(() {
      _initialized = true;
    });
    await _startDiscovery();
  }

  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      final permissionsGranted = await _nearbyService.android?.requestPermissions() ?? false;
      final wifiEnabled = await _nearbyService.android?.checkWifiService() ?? false;
      return permissionsGranted && wifiEnabled;
    }
    return true;
  }

  Future<void> _startDiscovery() async {
    final isReady = await _checkPermissions();
    if (!isReady) {
      AppSnackBar.show(context, title: 'Permissions not granted or Wi-Fi not enabled.');
      return;
    }

    final discoverySuccess = await _nearbyService.discover();
    if (discoverySuccess) {
      _peersSubscription = _nearbyService.getPeersStream().listen((peers) {
        setState(() {
          _peers = peers;
        });
        if (peers.isNotEmpty && _connectedDevices.isEmpty && !_popupShown) {
          _showDeviceSelectionDialog(peers);
          _popupShown = true;
        }
      });
    } else {
      AppSnackBar.show(context, title: 'Failed to start discovery.');
    }
  }

  void _showDeviceSelectionDialog(List<NearbyDevice> peers) {
    if (peers.isEmpty) {
      AppSnackBar.show(context, title: 'No devices discovered.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select a device to connect'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: peers.length,
              itemBuilder: (context, index) {
                final peer = peers[index];
                return ListTile(
                  title: Text(peer.info.displayName ?? 'Unknown Device'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _connectToPeer(peer);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            )
          ],
        );
      },
    );
  }

  void _connectToPeer(NearbyDevice peer) async {
    final result = await _nearbyService.connectById(peer.info.id);
    if (result) {
      setState(() {
        if (!_connectedDevices.any((d) => d.info.id == peer.info.id)) {
          _connectedDevices.add(peer);
        }
      });
      _startCommunicationChannelForDevice(peer);
      _sendIntroMessage(peer);
      _startIntroBurst();
      _startIntroTimer();

      AppSnackBar.show(context, title: 'Connected to ${peer.info.displayName}');
    } else {
      AppSnackBar.show(
        context,
        title: 'Failed to connect to ${peer.info.displayName ?? 'Unknown Device'}',
      );
    }
  }

  void _startCommunicationChannelForDevice(NearbyDevice device) {
    _nearbyService.startCommunicationChannel(
      NearbyCommunicationChannelData(
        device.info.id,
        messagesListener: NearbyServiceMessagesListener(
          onData: (message) {
            final text = message.content.byType(
              onTextRequest: (req) => req.value,
            );

            if (text == null) return;

            final devId = device.info.id;
            if (!_deviceChosenNames.containsKey(devId)) {
              _deviceChosenNames[devId] = device.info.displayName ?? 'Unknown';
            }

            int senderId = _getOrAssignUserIdForDevice(devId);

            if (text.startsWith('intro:')) {
              final content = text.substring('intro:'.length).trim();
              final parts = content.split('|');
              final introducedName = parts[0];
              final introducedImage = parts.length > 1 ? parts[1] : '';

              _deviceChosenNames[devId] = introducedName;
              _deviceChosenImages[devId] = introducedImage;

              // Cache image if available
              if (introducedImage.isNotEmpty) {
                _cachedMemoryImages[devId] = MemoryImage(base64Decode(introducedImage));
              }

              User? existingUser = users.firstWhere((u) => u.id == senderId, orElse: () => User(id: senderId));
              existingUser.nickname = introducedName;
              existingUser.headimg = introducedImage;
              if (!users.contains(existingUser)) {
                users.add(existingUser);
              }

            } else {
              // Normal text message
              final msg = ChatMessage();
              msg.id = DateTime.now().millisecondsSinceEpoch;
              msg.sender = senderId;
              msg.type = "text";
              msg.text = text;
              msg.time = DateTime.now().millisecondsSinceEpoch;
              msg.nickname = _deviceChosenNames[devId];
              msg.headimg = _deviceChosenImages[devId];
              setState(() {
                list.add(msg);
              });
              _scrollToBottom();
            }
          },
        ),
      ),
    );
  }

  int _getOrAssignUserIdForDevice(String deviceId) {
    if (_deviceIdToUserId.containsKey(deviceId)) {
      return _deviceIdToUserId[deviceId]!;
    } else {
      _deviceIdToUserId[deviceId] = _remoteUserIdCounter++;
      _userIdToDeviceId[_deviceIdToUserId[deviceId]!] = deviceId;
      return _deviceIdToUserId[deviceId]!;
    }
  }

  void _startIntroTimer() {
    // Increase the interval to 2 minutes after the short burst
    _introTimer ??= Timer.periodic(const Duration(minutes: 2), (timer) {
      _broadcastIntroMessage();
    });
  }

  void _startIntroBurst() {
    if (_burstActive) return;
    _burstActive = true;

    Future.delayed(const Duration(seconds: 5), () {
      _broadcastIntroMessage();
    });
    Future.delayed(const Duration(seconds: 10), () {
      _broadcastIntroMessage();
      _burstActive = false;
    });
  }

  void _sendIntroMessage(NearbyDevice device) async {
    final introText = 'intro:${widget.myName}|${widget.myImage}';
    await _nearbyService.send(
      OutgoingNearbyMessage(
        content: NearbyMessageTextRequest.create(value: introText),
        receiver: device.info,
      ),
    );
  }

  void _broadcastIntroMessage() async {
    if (_connectedDevices.isEmpty) return;
    final introText = 'intro:${widget.myName}|${widget.myImage}';
    for (final device in _connectedDevices) {
      await _nearbyService.send(
        OutgoingNearbyMessage(
          content: NearbyMessageTextRequest.create(value: introText),
          receiver: device.info,
        ),
      );
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final msg = ChatMessage();
    msg.id = DateTime.now().millisecondsSinceEpoch;
    msg.sender = 1; // local user
    msg.type = "text";
    msg.text = text;
    msg.time = DateTime.now().millisecondsSinceEpoch;
    msg.nickname = widget.myName;
    msg.headimg = widget.myImage;
    setState(() {
      list.add(msg);
      _messageController.clear();
    });

    _scrollToBottom(); // scroll after sending message

    for (final device in _connectedDevices) {
      await _nearbyService.send(
        OutgoingNearbyMessage(
          content: NearbyMessageTextRequest.create(value: text),
          receiver: device.info,
        ),
      );
    }
    _broadcastIntroMessage();
  }

  void _showConnectedDevices() {
    if (_connectedDevices.isEmpty) {
      AppSnackBar.show(context, title: 'No devices connected.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Connected Devices'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _connectedDevices.map((d) {
                final devId = d.info.id;
                final display = _deviceChosenNames[devId] ?? (d.info.displayName ?? 'Unknown Device');
                final image = _cachedMemoryImages[devId]; // Use cached MemoryImage
                return ListTile(
                  leading: image != null
                      ? CircleAvatar(backgroundImage: image)
                      : const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(display),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showDiscoveredDevicesAgain() {
    if (_peers.isEmpty) {
      AppSnackBar.show(context, title: 'No devices discovered.');
      return;
    }
    _showDeviceSelectionDialog(_peers);
  }

  Future<void> _downloadBase64Image(ChatMessage chatMessage) async {
    if (chatMessage.image == null || chatMessage.image!.isEmpty) return;
    try {
      final decodedBytes = base64Decode(chatMessage.image!);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/downloaded_image.png');
      await file.writeAsBytes(decodedBytes);
      AppSnackBar.show(context, title: "Image saved at ${file.path}");
    } catch (e) {
      print("$e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  MemoryImage? _getUserImageBySenderId(int senderId) {
    if (senderId == 1) {
      return _localUserImageMemory;
    } else {
      // Find deviceId from userId
      if (!_userIdToDeviceId.containsKey(senderId)) return null;
      final deviceId = _userIdToDeviceId[senderId]!;
      return _cachedMemoryImages[deviceId];
    }
  }

  String _getUserNameBySenderId(int senderId) {
    if (senderId == 1) return widget.myName;
    final user = users.firstWhere((u) => u.id == senderId, orElse: () => User(id: senderId, nickname: 'Unknown'));
    return user.nickname ?? 'Unknown';
  }

  Widget _buildMessageItem(ChatMessage chatMessage) {
    bool isLocal = (chatMessage.sender == 1);

    String time = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(chatMessage.time ?? DateTime.now().millisecondsSinceEpoch)
    );

    int index = list.indexOf(chatMessage);
    ChatMessage? last = index > 0 ? list[index - 1] : null;
    bool showTime = false;
    if (last == null) {
      showTime = true;
    } else {
      if ((chatMessage.time! - last.time!) > 1000 * 10 * 60) {
        showTime = true;
      }
    }

    // Get user name & avatar for this message
    final senderName = _getUserNameBySenderId(chatMessage.sender!);
    final senderImage = _getUserImageBySenderId(chatMessage.sender!);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: isLocal ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showTime)
            Text(time, style: const TextStyle(color: Colors.white)),
          if (showTime)
            const SizedBox(height: 10),
          // Show user avatar and name above the message
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isLocal && senderImage != null)
                CircleAvatar(backgroundImage: senderImage, radius: 15), // smaller avatar
              if (!isLocal && senderImage == null)
                const CircleAvatar(child: Icon(Icons.person), radius: 15),
              if (!isLocal) const SizedBox(width: 5),
              Text(senderName, style: const TextStyle(color: Colors.white, fontSize: 10)), // smaller font
              if (isLocal && senderImage != null) ...[
                const SizedBox(width: 5),
                CircleAvatar(backgroundImage: senderImage, radius: 15),
              ],
              if (isLocal && senderImage == null) ...[
                const SizedBox(width: 5),
                const CircleAvatar(child: Icon(Icons.person), radius: 15),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Container(
            alignment: isLocal ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: isLocal ? const Color(0xff222222) : const Color(0xff383f4b),
                  borderRadius: BorderRadius.circular(20)),
              child: chatMessage.type == "text"
                  ? Text(
                      chatMessage.text!,
                      textAlign: TextAlign.left,
                      style: const TextStyle(color: Colors.white),
                    )
                  : (chatMessage.type == "image"
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: isLocal ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            InkWell(
                                onTap: () {
                                  setState(() {
                                    list.remove(chatMessage);
                                  });
                                },
                                child: Image.asset("images/close.jpg", width: 24, height: 24)),
                            const SizedBox(width: 10),
                            InkWell(
                                onTap: () {
                                  _downloadBase64Image(chatMessage);
                                },
                                child: Image.asset("images/download.jpg", width: 24, height: 24)),
                            const SizedBox(width: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                base64Decode(chatMessage.image!),
                                width: 150,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            )
                          ],
                        )
                      : Container()),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUsersRow() {
    return Row(
      children: users.map((User e) {
        MemoryImage? mem;
        if (e.id == 1 && _localUserImageMemory != null) {
          mem = _localUserImageMemory;
        } else if (e.headimg != null && e.headimg!.isNotEmpty) {
          // Try cached images by headimg string
          if (!_cachedMemoryImages.containsKey(e.headimg!)) {
            final imgBytes = base64Decode(e.headimg!);
            _cachedMemoryImages[e.headimg!] = MemoryImage(imgBytes);
          }
          mem = _cachedMemoryImages[e.headimg!];
        }

        return Container(
          margin: const EdgeInsets.only(right: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: mem != null 
                ? Image(image: mem, width: 40, height: 40, fit: BoxFit.cover)
                : const CircleAvatar(child: Icon(Icons.person)),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _chooseImageAndSend() async {
    if (kIsWeb) {
      return;
    }
    XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery, maxHeight: 600, maxWidth: 600);

    if (pickedFile != null) {
      List<int> fileBytes = await File(pickedFile.path).readAsBytes();
      String base64String = base64Encode(fileBytes);

      final msg = ChatMessage();
      msg.id = DateTime.now().millisecondsSinceEpoch;
      msg.image = base64String;
      msg.sender = 1;
      msg.nickname = widget.myName;
      msg.headimg = widget.myImage;
      msg.type = "image";
      msg.time = DateTime.now().millisecondsSinceEpoch;

      setState(() {
        list.add(msg);
      });

      _scrollToBottom();
      _broadcastIntroMessage();
    }
  }

  @override
  void dispose() {
    _peersSubscription?.cancel();
    _introTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectedDeviceNames = _connectedDevices.map((d) {
      return _deviceChosenNames[d.info.id] ?? (d.info.displayName ?? 'Unknown Device');
    }).join(', ');

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Room - My Name: ${widget.myName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.devices),
            tooltip: 'Show connected devices',
            onPressed: _showConnectedDevices,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Show discovered devices',
            onPressed: _showDiscoveredDevicesAgain,
          ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      // Set chat room background to match main.dart
      backgroundColor: const Color(0xff252d38),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(),
        child: Column(
          children: [
            // Top users row + updated dynamic info
            Row(
              children: [
                Expanded(child: _buildUsersRow()),
                Column(
                  children: [
                    Text("My Name: ${widget.myName}", style: const TextStyle(color: Colors.white, fontSize: 14)),
                    Text("Connected: $connectedDeviceNames", style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  return _buildMessageItem(list[index]);
                },
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                      child: Container(
                    height: 40,
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1c222b),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Expanded(
                            child: TextField(
                          onSubmitted: (v) {},
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(border: InputBorder.none),
                        )),
                        GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _sendMessage,
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: const Color(0xFF383f49),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Image.asset(
                                "images/qipao.jpg",
                                width: 23,
                                height: 23,
                              ),
                            ))
                      ],
                    ),
                  )),
                  const SizedBox(width: 10),
                  GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _chooseImageAndSend,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: const Color(0xFF64a98a),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(
                          Icons.photo_camera,
                          color: Colors.white,
                          size: 19,
                        ),
                      ))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
