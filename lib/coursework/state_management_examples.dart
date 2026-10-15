import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SetStateFavoriteExample extends StatefulWidget {
  const SetStateFavoriteExample({super.key});

  @override
  State<SetStateFavoriteExample> createState() =>
      _SetStateFavoriteExampleState();
}

class _SetStateFavoriteExampleState extends State<SetStateFavoriteExample> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) => _FavoriteCard(
    isFavorite: _isFavorite,
    toggleKey: const ValueKey('set-state-favorite-toggle'),
    onToggle: () => setState(() => _isFavorite = !_isFavorite),
    approach: 'Локальное состояние: setState',
  );
}

class FavoriteInheritedScope extends InheritedWidget {
  const FavoriteInheritedScope({
    required this.isFavorite,
    required this.onToggle,
    required super.child,
    super.key,
  });

  final bool isFavorite;
  final VoidCallback onToggle;

  static FavoriteInheritedScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<FavoriteInheritedScope>();
    assert(
      scope != null,
      'FavoriteInheritedScope not found in the widget tree.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(FavoriteInheritedScope oldWidget) =>
      isFavorite != oldWidget.isFavorite;
}

class InheritedFavoriteExample extends StatefulWidget {
  const InheritedFavoriteExample({super.key});

  @override
  State<InheritedFavoriteExample> createState() =>
      _InheritedFavoriteExampleState();
}

class _InheritedFavoriteExampleState extends State<InheritedFavoriteExample> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) => FavoriteInheritedScope(
    isFavorite: _isFavorite,
    onToggle: () => setState(() => _isFavorite = !_isFavorite),
    child: const _InheritedFavoriteCard(),
  );
}

class _InheritedFavoriteCard extends StatelessWidget {
  const _InheritedFavoriteCard();

  @override
  Widget build(BuildContext context) {
    final scope = FavoriteInheritedScope.of(context);
    return _FavoriteCard(
      isFavorite: scope.isFavorite,
      toggleKey: const ValueKey('inherited-favorite-toggle'),
      onToggle: scope.onToggle,
      approach: 'Передача состояния: InheritedWidget',
    );
  }
}

class _FavoriteModel extends ChangeNotifier {
  bool _isFavorite = false;

  bool get isFavorite => _isFavorite;

  void toggle() {
    _isFavorite = !_isFavorite;
    notifyListeners();
  }
}

class ProviderFavoriteExample extends StatelessWidget {
  const ProviderFavoriteExample({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => _FavoriteModel(),
    child: Consumer<_FavoriteModel>(
      builder: (context, model, _) => _FavoriteCard(
        isFavorite: model.isFavorite,
        toggleKey: const ValueKey('provider-favorite-toggle'),
        onToggle: model.toggle,
        approach: 'Общее состояние: Provider',
      ),
    ),
  );
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.isFavorite,
    required this.toggleKey,
    required this.onToggle,
    required this.approach,
  });

  final bool isFavorite;
  final Key toggleKey;
  final VoidCallback onToggle;
  final String approach;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(approach, style: Theme.of(context).textTheme.titleSmall),
      ),
      Card(
        child: ListTile(
          title: const Text('Night Drive'),
          subtitle: Text(
            isFavorite ? 'Трек в избранном' : 'Трек не в избранном',
          ),
          leading: const Icon(Icons.music_note),
          trailing: IconButton(
            key: toggleKey,
            tooltip: approach,
            onPressed: onToggle,
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
        ),
      ),
    ],
  );
}
