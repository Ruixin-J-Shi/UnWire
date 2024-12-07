import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nearby_service/nearby_service.dart';
import 'utils/app_snack_bar.dart';

class ChatRoom extends StatefulWidget {
  final String myName;

  const ChatRoom({
    super.key,
    required this.myName,
  });

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> {
  final _nearbyService = NearbyService.getInstance(logLevel: NearbyServiceLogLevel.debug);

  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];

  List<NearbyDevice> _connectedDevices = [];
  List<NearbyDevice> _peers = [];

  // Maps deviceId to the chosen name introduced by that device
  final Map<String, String> _deviceChosenNames = {};

  StreamSubscription<List<NearbyDevice>>? _peersSubscription;
  bool _initialized = false;
  bool _popupShown = false; // Prevent multiple automatic popups
  Timer? _introTimer; // Timer to resend intro messages regularly
  bool _burstActive = false; // To prevent overlapping bursts

  @override
  void initState() {
    super.initState();
    _initService();
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
        // Show the device selection popup only once automatically
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

      // After connecting, send an immediate intro message
      _sendIntroMessage(peer);

      // Start a burst of intro messages shortly after connecting to ensure it is received
      _startIntroBurst();

      // If not already running, start a timer to periodically resend intro messages
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

            if (text == null) {
              return; // No text
            }

            if (text.startsWith('intro:')) {
              // Intro message: do not display. Just set the chosen name.
              final introducedName = text.substring('intro:'.length).trim();
              _deviceChosenNames[device.info.id] = introducedName;
            } else {
              // Normal message
              final senderName = _deviceChosenNames[device.info.id] ?? 
                                  (device.info.displayName ?? 'Unknown Device');
              setState(() {
                _messages.add('$senderName: $text');
              });
            }
          },
        ),
      ),
    );
  }

  void _startIntroTimer() {
    _introTimer ??= Timer.periodic(const Duration(seconds: 30), (timer) {
      _broadcastIntroMessage();
    });
  }

  /// Send multiple intro messages over a short period after connecting to ensure delivery.
  void _startIntroBurst() {
    if (_burstActive) return; // Prevent overlapping bursts
    _burstActive = true;

    // Send intro messages at 0s, 5s, 10s after connecting
    // Already sent one at connect time (0s), let's do at 5s and 10s
    Future.delayed(const Duration(seconds: 5), () {
      _broadcastIntroMessage();
    });
    Future.delayed(const Duration(seconds: 10), () {
      _broadcastIntroMessage();
      _burstActive = false; // Burst completed
    });
  }

  void _sendIntroMessage(NearbyDevice device) async {
    final introText = 'intro:${widget.myName}';
    await _nearbyService.send(
      OutgoingNearbyMessage(
        content: NearbyMessageTextRequest.create(value: introText),
        receiver: device.info,
      ),
    );
  }

  void _broadcastIntroMessage() async {
    if (_connectedDevices.isEmpty) return;
    final introText = 'intro:${widget.myName}';
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

    for (final device in _connectedDevices) {
      await _nearbyService.send(
        OutgoingNearbyMessage(
          content: NearbyMessageTextRequest.create(value: text),
          receiver: device.info,
        ),
      );
    }

    setState(() {
      _messages.add('${widget.myName}: $text');
      _messageController.clear();
    });

    // After sending a message, also send an intro message to ensure the other side sees our chosen name
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
                final display = _deviceChosenNames[d.info.id] ??
                    (d.info.displayName ?? 'Unknown Device');
                return ListTile(
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
      ),
      body: Column(
        children: [
          if (connectedDeviceNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Connected: $connectedDeviceNames'),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) => ListTile(title: Text(_messages[index])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Enter your message'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
