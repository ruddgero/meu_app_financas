import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minhas Finanças',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Transaction {
  String id;
  String title;
  String description;
  double amount;
  bool isIncome;

  Transaction({required this.id, required this.title, required this.description, required this.amount, required this.isIncome});

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'description': description, 'amount': amount, 'isIncome': isIncome
  };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
    id: map['id'], title: map['title'], description: map['description'], amount: map['amount'], isIncome: map['isIncome']
  );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  List<Transaction> _transactions = [];
  bool _isGranted = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _checkPermission();
  }

  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('transactions_v1');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _transactions = decoded.map((e) => Transaction.fromMap(e)).toList();
      });
    }
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_transactions.map((e) => e.toMap()).toList());
    await prefs.setString('transactions_v1', data);
  }

  Future<void> _checkPermission() async {
    final bool res = await NotificationListenerService.isPermissionGranted();
    setState(() => _isGranted = res);
    if (res) _startListening();
  }

  Future<void> _requestPermission() async {
    final bool res = await NotificationListenerService.requestPermission();
    if (res) {
      setState(() => _isGranted = true);
      _startListening();
    }
  }

  void _startListening() {
    _subscription = NotificationListenerService.notificationsStream.listen((event) {
      final text = '${event.title} ${event.content}'.toLowerCase();
      
      if (text.contains('compra') || text.contains('pagamento') || text.contains('pix') || text.contains('r\$') || text.contains('transferência') || text.contains('cartão')) {
        double amount = 0.0;
        final regExp = RegExp(r'r\$\s?(\d+[\.,]\d+)');
        final match = regExp.firstMatch(text);
        if (match != null) {
          String valStr = match.group(1)!.replaceAll('.', '').replaceAll(',', '.');
          amount = double.tryParse(valStr) ?? 0.0;
        }

        bool isIncome = text.contains('recebid') || text.contains('transferência de') || text.contains('você recebeu');
        
        final newTx = Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: event.title ?? 'Transação',
          description: event.content ?? '',
          amount: amount,
          isIncome: isIncome,
        );

        setState(() {
          _transactions.insert(0, newTx);
        });
        _saveTransactions();
      }
    });
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((tx) => tx.id == id);
    });
    _saveTransactions();
  }
  void _showEditDialog({Transaction? transaction}) {
    final isNew = transaction == null;
    TextEditingController titleCtrl = TextEditingController(text: isNew ? '' : transaction.title);
    TextEditingController descCtrl = TextEditingController(text: isNew ? '' : transaction.description);
    TextEditingController amountCtrl = TextEditingController(text: isNew ? '' : transaction.amount.toString());
    bool isIncome = isNew ? false : transaction.isIncome;

    showDialog(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(isNew ? 'Nova Transação' : 'Editar Transação'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrição')),
                TextField(
                  controller: amountCtrl, 
                  decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tipo:'),
                    ToggleButtons(
                      isSelected: [isIncome, !isIncome],
                      onPressed: (index) {
                        setDialogState(() {
                          isIncome = index == 0;
                        });
                      },
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Receita', style: TextStyle(color: Colors.green))),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Gasto', style: TextStyle(color: Colors.red))),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
          actions: [
            if (!isNew)
              TextButton(
                onPressed: () {
                  _deleteTransaction(transaction.id);
                  Navigator.pop(context);
                },
                child: const Text('Excluir', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final double? parsedAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                if (titleCtrl.text.isNotEmpty && parsedAmount != null) {
                  if (isNew) {
                    final newTx = Transaction(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleCtrl.text,
                      description: descCtrl.text,
                      amount: parsedAmount,
                      isIncome: isIncome,
                    );
                    setState(() => _transactions.insert(0, newTx));
                  } else {
                    setState(() {
                      transaction.title = titleCtrl.text;
                      transaction.description = descCtrl.text;
                      transaction.amount = parsedAmount;
                      transaction.isIncome = isIncome;
                    });
                  }
                  _saveTransactions();
                  Navigator.pop(context);
                }
              },
              child: const Text('Salvar'),
            )
          ],
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    double totalIncome = _transactions.where((tx) => tx.isIncome).fold(0, (sum, tx) => sum + tx.amount);
    double totalExpense = _transactions.where((tx) => !tx.isIncome).fold(0, (sum, tx) => sum + tx.amount);
    double

  
