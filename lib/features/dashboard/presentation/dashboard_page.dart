import 'package:flutter/material.dart';

import '../../../app/router.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FinMe'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Dashboard financeiro em construção'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.transactions);
              },
              child: const Text('Ver transações de exemplo'),
            ),
          ],
        ),
      ),
    );
  }
}
