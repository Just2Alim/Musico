import 'package:flutter/material.dart';

import 'state_management_examples.dart';

class StateManagementExamplesScreen extends StatelessWidget {
  const StateManagementExamplesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Состояние избранного')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text(
          'Одна функция — три способа управления состоянием. В приложении '
          'для общего состояния каталога используется Provider, а для '
          'воспроизведения — Cubit.',
        ),
        SizedBox(height: 12),
        SetStateFavoriteExample(),
        InheritedFavoriteExample(),
        ProviderFavoriteExample(),
      ],
    ),
  );
}
