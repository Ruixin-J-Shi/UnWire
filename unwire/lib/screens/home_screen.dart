import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'dart:async';
import 'dart:io';
import 'package:filesystem_picker/filesystem_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterP2pConnection _p2pConnection = FlutterP2pConnection();
  final TextEditingController _messageController = TextEditingController();
  List<DiscoveredPeers> _peers = [];
  WifiP2PInfo? _wifiInfo;
  StreamSubscription<List<DiscoveredPeers>>? _peerStream;
  StreamSubscription<WifiP2PInfo>? _wifiInfoStream;

  @override
  void initState() {
    super.initState();
    _initializeP2P();
  }

  @override
  void dispose() {
    _peerStream?.cancel();
    _wifiInfoStream?.cancel();
    _p2pConnection.unregister();
    super.dispose();
  }

  Future<void> _initializeP2P() async {
    await _p2pConnection.initialize();
    await _p2pConnection.register();

    _peerStream = _p2pConnection.streamPeers().listen((peers) {
      setState(() {
        _peers = peers;
      });
    });

    _wifiInfoStream = _p2pConnection.streamWifiP2PInfo().listen((info) {
      setState(() {
        _wifiInfo = info;
      });
    });
  }

  void _discoverPeers() async {
    await _p2pConnection.discover();
  }

  void _connectToPeer(DiscoveredPeers peer) async {
    await _p2pConnection.connect(peer.deviceAddress);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connected to ${peer.deviceName}')),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _p2pConnection.sendStringToSocket(_messageController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent: ${_messageController.text}')),
      );
      _messageController.clear();
    }
  }

  Future<void> _sendFile() async {
    String? filePath = await FilesystemPicker.open(
      context: context,
      rootDirectory: Directory('/storage/emulated/0/'),
      fsType: FilesystemType.file,
      fileTileSelectMode: FileTileSelectMode.wholeTile,
    );

    if (filePath != null) {
      await _p2pConnection.sendFiletoSocket([filePath]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File sent: $filePath')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('P2P Chat')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _discoverPeers,
            child: const Text('Discover Peers'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _peers.length,
              itemBuilder: (context, index) {
                final peer = _peers[index];
                return ListTile(
                  title: Text(peer.deviceName ?? 'Unknown'),
                  trailing: ElevatedButton(
                    onPressed: () => _connectToPeer(peer),
                    child: const Text('Connect'),
                  ),
                );
              },
            ),
          ),
          if (_wifiInfo != null)
            Text(
                'Connected to: ${_wifiInfo?.groupOwnerAddress ?? "None"}'),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(hintText: 'Enter message'),
          ),
          ElevatedButton(
            onPressed: _sendMessage,
            child: const Text('Send Message'),
          ),
          ElevatedButton(
            onPressed: _sendFile,
            child: const Text('Send File'),
          ),
        ],
      ),
    );
  }
}
