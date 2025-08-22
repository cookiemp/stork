class Peer {
  final String name;
  final String host;
  final int port;

  const Peer({required this.name, required this.host, required this.port});

  @override
  String toString() => 'Peer(name: $name, host: $host, port: $port)';
}

