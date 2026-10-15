import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/music_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final MusicRepository _repository;
  late Future<List<Map<String, dynamic>>> _notifications;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _repository = context.read<MusicRepository>();
    _notifications = _repository.notifications();
    _channel = _repository.subscribeToNotifications(() {
      if (mounted) setState(() => _notifications = _repository.notifications());
    });
  }

  Future<void> _refresh() async {
    final next = _repository.notifications();
    setState(() => _notifications = next);
    await next;
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      unawaited(_repository.client.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _markRead(Map<String, dynamic> row) async {
    if (row['read_at'] != null) return;
    try {
      await context.read<MusicRepository>().markNotificationRead(
        row['id'] as int,
      );
      if (!mounted) return;
      setState(() {
        row['read_at'] = DateTime.now().toUtc().toIso8601String();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отметить уведомление: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Уведомления')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _notifications,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _NotificationMessage(
            message: 'Не удалось загрузить уведомления. Проверьте подключение.',
            onRetry: _refresh,
          );
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return _NotificationMessage(
            message: 'Пока нет уведомлений.',
            onRetry: _refresh,
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              final isRead = row['read_at'] != null;
              return ListTile(
                leading: Icon(
                  isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                ),
                title: Text(row['title'] as String? ?? 'Уведомление'),
                subtitle: Text(row['body'] as String? ?? ''),
                trailing: isRead ? null : const Icon(Icons.circle, size: 10),
                onTap: () => _markRead(row),
              );
            },
          ),
        );
      },
    ),
  );
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Обновить')),
        ],
      ),
    ),
  );
}
