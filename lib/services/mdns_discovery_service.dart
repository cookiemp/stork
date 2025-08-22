import 'dart:async';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/peer.dart';

class MdnsDiscoveryService {
  static const String serviceType = '_localsendapp._tcp';

  MDnsClient? _client;
  StreamSubscription<PtrResourceRecord>? _ptrSub;
  final _peersController = StreamController<List<Peer>>.broadcast();
  final Map<String, Peer> _peers = {};
  
  // Broadcasting state
  bool _isBroadcasting = false;
  String? _deviceName;
  int? _port;

  Stream<List<Peer>> get peersStream => _peersController.stream;
  bool get isBroadcasting => _isBroadcasting;

  Future<void> start() async {
    if (_client != null) return;
    try {
      final client = MDnsClient(rawDatagramSocketFactory: (dynamic host, int port,
          {bool reuseAddress = true, bool reusePort = false, int ttl = 255, bool? v6Only}) {
        return RawDatagramSocket.bind(InternetAddress.anyIPv4, port,
            reuseAddress: true, ttl: ttl);
      });
      _client = client;

      // On some Windows setups multicast may not be supported; catch and bail out gracefully
      await client.start();

      _ptrSub = client.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(serviceType)).listen((ptr) {
        // Resolve SRV for target
        client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName)).listen((srv) {
          // Resolve A (IPv4) for host
          client.lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target)).listen((ip) {
            final name = ptr.domainName.split('.').first;
            final peer = Peer(name: name, host: ip.address.address, port: srv.port);
            _peers['${peer.host}:${peer.port}'] = peer;
            _emit();
          });
        });
      });
    } catch (e) {
      // Disable discovery gracefully on platforms/interfaces where multicast fails
      if (_client != null) {
        try { _client!.stop(); } catch (_) {}
      }
      _client = null;
      _peers.clear();
      _emit();
    }
  }

  void _emit() {
    _peersController.add(_peers.values.toList(growable: false));
  }

  /// Start broadcasting this device as available for P2P transfers
  /// Note: This is a placeholder for now as the multicast_dns package
  /// is primarily for discovery. Full broadcasting requires additional setup.
  Future<void> startBroadcasting({required String deviceName, required int port}) async {
    if (_isBroadcasting) {
      await stopBroadcasting(); // Stop current broadcasting first
    }
    
    _deviceName = deviceName;
    _port = port;
    
    try {
      if (_client == null) {
        await start(); // Ensure mDNS client is running
      }
      
      if (_client == null) {
      print('⚠️ mDNS client failed to start, cannot broadcast');
        return;
      }
      
      _isBroadcasting = true;
      print('📡 Broadcasting mode enabled for device: $deviceName on port $port');
      print('ℹ️ Note: Actual mDNS service advertising requires additional platform setup');
      
    } catch (e) {
      print('❌ Failed to start broadcasting: $e');
      _isBroadcasting = false;
    }
  }
  
  /// Stop broadcasting this device
  Future<void> stopBroadcasting() async {
    if (!_isBroadcasting) return;
    
    try {
      _isBroadcasting = false;
      _deviceName = null;
      _port = null;
      print('📡 Stopped broadcasting');
    } catch (e) {
      print('❌ Error stopping broadcast: $e');
    }
  }

  Future<void> stop() async {
    await stopBroadcasting();
    await _ptrSub?.cancel();
    _ptrSub = null;
    if (_client != null) {
      _client!.stop();
    }
    _client = null;
    _peers.clear();
    _emit();
  }

  void dispose() {
    // Fire and forget - don't block dispose
    stop().catchError((e) => print('Error during mDNS dispose: $e')); 
    _peersController.close();
  }
}

