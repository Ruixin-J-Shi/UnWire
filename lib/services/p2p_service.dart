import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

class P2PService {
  final FlutterP2pConnection _p2pConnection = FlutterP2pConnection();
  List<DiscoveredPeers> _discoveredPeers = [];

  /// Initialize and register for Wi-Fi P2P events
  Future<void> initialize() async {
    await _p2pConnection.initialize();
    await _p2pConnection.register();

    // Update the list of discovered peers whenever the stream emits new data
    _p2pConnection.streamPeers().listen((peers) {
      _discoveredPeers = peers;
    });
  }

  /// Enable necessary services
  Future<void> enableServices() async {
    await _p2pConnection.enableWifiServices();
    await _p2pConnection.enableLocationServices();
  }

  /// Discover peers
  Future<void> discoverPeers() async {
    await _p2pConnection.discover();
  }

  /// Stop discovery
  Future<void> stopDiscovery() async {
    await _p2pConnection.stopDiscovery();
  }

  /// Get the current list of discovered peers
  List<DiscoveredPeers> getDiscoveredPeers() {
    return _discoveredPeers;
  }

  /// Connect to a peer by index
  Future<void> connectToPeer(int peerIndex) async {
    if (peerIndex >= 0 && peerIndex < _discoveredPeers.length) {
      await _p2pConnection.connect(_discoveredPeers[peerIndex].deviceAddress);
    } else {
      throw Exception("Invalid peer index");
    }
  }

  /// Stream connection info
  Stream<WifiP2PInfo?> streamWifiP2PInfo() {
    return _p2pConnection.streamWifiP2PInfo();
  }

  /// Send a message
  Future<void> sendMessage(String message) async {
    await _p2pConnection.sendStringToSocket(message);
  }
}
