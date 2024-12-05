import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nearby_service/nearby_service.dart';
import 'chat_room.dart';
import 'utils/app_snack_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nearby Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ChatHome(),
    );
  }
}

class ChatHome extends StatefulWidget {
  const ChatHome({super.key});

  @override
  State<ChatHome> createState() => _ChatHomeState();
}

class _ChatHomeState extends State<ChatHome> {
  final _nearbyService = NearbyService.getInstance(logLevel: NearbyServiceLogLevel.debug);
  AppState _state = AppState.idle;
  String? _deviceName;
  List<NearbyDevice> _peers = [];
  StreamSubscription? _peersSubscription;
  NearbyDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _initializeNearbyService();
  }

  @override
  void dispose() {
    _peersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeNearbyService() async {
    await _nearbyService.initialize();
  }

  Future<void> _startDiscovery() async {
    final isReady = await _checkPermissions();
    if (isReady) {
      setState(() => _state = AppState.discovering);

      final discoverySuccess = await _nearbyService.discover();
      if (discoverySuccess) {
        _peersSubscription = _nearbyService.getPeersStream().listen((peers) {
          setState(() {
            _peers = peers;
          });
        });
      } else {
        AppSnackBar.show(context, title: 'Failed to start discovery.');
        setState(() => _state = AppState.idle);
      }
    }
  }

  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      final permissionsGranted = await _nearbyService.android?.requestPermissions() ?? false;
      final wifiEnabled = await _nearbyService.android?.checkWifiService() ?? false;
      return permissionsGranted && wifiEnabled;
    }
    return true;
  }

  void _connectToPeer(NearbyDevice peer) async {
    final result = await _nearbyService.connectById(peer.info.id);
    if (result) {
      setState(() {
        _connectedDevice = peer;
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoom(
            deviceName: peer.info.displayName ?? 'Unknown Device',
            nearbyService: _nearbyService,
            receiverDeviceInfo: peer.info,
          ),
        ),
      );
    } else {
      AppSnackBar.show(
        context,
        title: 'Failed to connect to ${peer.info.displayName ?? 'Unknown Device'}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Chat App')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_state == AppState.idle) ...[
              TextField(
                decoration: const InputDecoration(hintText: 'Enter device name'),
                onChanged: (value) => _deviceName = value,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_deviceName?.isEmpty ?? true) {
                    AppSnackBar.show(context, title: 'Please enter a device name.');
                    return;
                  }
                  await _startDiscovery();
                },
                child: const Text('Start Discovery'),
              ),
            ] else if (_state == AppState.discovering) ...[
              const Text('Discovering devices...'),
              if (_peers.isEmpty)
                const Text('No devices found.')
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _peers.length,
                    itemBuilder: (context, index) {
                      final peer = _peers[index];
                      return Card(
                        child: ListTile(
                          title: Text(peer.info.displayName ?? 'Unknown Device'),
                          trailing: IconButton(
                            icon: const Icon(Icons.chat),
                            onPressed: () => _connectToPeer(peer),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }
}

enum AppState { idle, discovering }
