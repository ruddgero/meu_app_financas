import 'dart:async';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finanças Notificações',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  final List<ServiceNotificationEvent> _events = [];
  bool _isGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final bool res = await NotificationListenerService.isPermissionGranted();
    setState(() {
      _isGranted = res;
    });
    if (res) {
      _startListening();
    }
  }

  Future<void> _requestPermission() async {
    final bool res = await NotificationListenerService.requestPermission();
    if (res) {
      setState(() {
        _isGranted = true;
      });
      _startListening();
    }
  }

  void _startListening() {
    _subscription = NotificationListenerService.notificationsStream.listen((event) {
      if (event.content != null && (event.content!.toLowerCase().contains('r\$') || event.content!.toLowerCase().contains('pix'))) {
        setState(() {
          _events.insert(0, event);
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitor de Pix e Compras', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
      ),
      body: _isGranted ? _buildList() : _buildPermissionRequest(),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_active, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Para capturar Pix e compras automaticamente, precisamos da permissão para ler notificações.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _requestPermission,
            child: const Text('Conceder Permissão'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_events.isEmpty) {
      return const Center(child: Text('Nenhuma transação capturada ainda.\nFaça um Pix para testar!', textAlign: TextAlign.center,));
    }
    return ListView.builder(
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        return ListTile(
          leading: const Icon(Icons.attach_money, color: Colors.green),
          title: Text(event.title ?? 'Transação'),
          subtitle: Text('${event.content ?? ''}'),
        );
      },
    );
  }
}
