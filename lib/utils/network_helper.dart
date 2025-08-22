import 'dart:io';

class NetworkHelper {
  /// Get the best available network interface for P2P communication
  static Future<NetworkInterface?> getBestNetworkInterface() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Priority order: Wi-Fi, Ethernet, others
      final priorities = ['wi-fi', 'wifi', 'ethernet', 'eth'];
      
      for (final priority in priorities) {
        for (final interface in interfaces) {
          if (interface.name.toLowerCase().contains(priority)) {
            return interface;
          }
        }
      }
      
      // Return first available if no preferred found
      return interfaces.isNotEmpty ? interfaces.first : null;
    } catch (e) {
      print('⚠️ Error getting network interfaces: $e');
      return null;
    }
  }

  /// Get local IP address from the best available interface
  static Future<String?> getLocalIpAddress() async {
    final interface = await getBestNetworkInterface();
    if (interface != null && interface.addresses.isNotEmpty) {
      return interface.addresses.first.address;
    }
    return null;
  }

  /// Get all available network interfaces with their IP addresses
  static Future<Map<String, List<String>>> getAllNetworkInterfaces() async {
    final result = <String, List<String>>{};
    
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        final addresses = interface.addresses.map((addr) => addr.address).toList();
        result[interface.name] = addresses;
      }
    } catch (e) {
      print('⚠️ Error listing network interfaces: $e');
    }

    return result;
  }

  /// Check if a given IP address is reachable
  static Future<bool> isHostReachable(String host, int port, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get device name for network identification
  static String getDeviceName() {
    try {
      return Platform.localHostname;
    } catch (e) {
      return 'Unknown-Device';
    }
  }

  /// Check if mDNS is likely supported on this network
  static Future<bool> isMulticastSupported() async {
    try {
      // Try to bind to multicast address
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}
