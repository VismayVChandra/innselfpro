import 'package:flutter/material.dart';

import '../../../models/payment.dart';
import '../payments_repository.dart';

class TechnicianWalletScreen extends StatefulWidget {
  const TechnicianWalletScreen({super.key});

  @override
  State<TechnicianWalletScreen> createState() => _TechnicianWalletScreenState();
}

class _TechnicianWalletScreenState extends State<TechnicianWalletScreen> {
  late final Future<List<Payment>> _earningsFuture;

  @override
  void initState() {
    super.initState();
    _earningsFuture = PaymentsRepository().fetchMyEarnings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: FutureBuilder<List<Payment>>(
        future: _earningsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load earnings: ${snapshot.error}'));
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final payments = snapshot.data!;
          final total = payments.fold<double>(0, (sum, p) => sum + p.amount);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text('Total earnings', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: payments.isEmpty
                    ? const Center(child: Text('No paid jobs yet.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final payment = payments[index];
                          return Card(
                            child: ListTile(
                              title: Text('₹${payment.amount.toStringAsFixed(0)}'),
                              subtitle: Text(payment.jobCategoryName ?? ''),
                              trailing: Text(
                                payment.paidAt != null
                                    ? payment.paidAt!.toLocal().toString().split(' ').first
                                    : '',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
