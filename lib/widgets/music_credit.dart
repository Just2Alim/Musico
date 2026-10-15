import 'package:flutter/material.dart';

import '../providers/audio_player_provider.dart';

/// Attribution applies only to the verified original recordings in our seed.
class MusicCredit extends StatelessWidget {
  const MusicCredit({super.key, required this.track});

  final Track track;

  static const _recordings = <String, ({String filename, String isrc})>{
    'Moonlight Beach': (
      filename: 'Moonlight%20Beach.mp3',
      isrc: 'USUAN2000005',
    ),
    'Summer Day': (filename: 'Summer%20Day.mp3', isrc: 'USUAN1200083'),
    'All This': (filename: 'All%20This.mp3', isrc: 'USUAN1300001'),
    'Tiki Bar Mixer': (
      filename: 'Tiki%20Bar%20Mixer.mp3',
      isrc: 'USUAN2000006',
    ),
    'Acid Trumpet': (filename: 'AcidJazz.mp3', isrc: 'USUAN1100339'),
    'Easy Lemon': (filename: 'Easy%20Lemon.mp3', isrc: 'USUAN1200076'),
  };

  static bool supports(Track track) {
    if (track.source == 'jamendo') {
      return _secureUrl(track.sourceUrl) && _secureUrl(track.licenseUrl);
    }
    final recording = _recordings[track.name];
    return track.artist == 'Kevin MacLeod' &&
        recording != null &&
        track.audioFileUrl ==
            'https://incompetech.com/music/royalty-free/mp3-royaltyfree/${recording.filename}';
  }

  @override
  Widget build(BuildContext context) {
    if (!supports(track)) return const SizedBox.shrink();
    if (track.source == 'jamendo') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${track.name} — ${track.artist} (Jamendo)'),
          const SizedBox(height: 12),
          Text('Авторство: ${track.artist}'),
          const SizedBox(height: 8),
          const Text('Лицензия и условия использования получены из каталога.'),
          const SizedBox(height: 8),
          const Text('Источник:'),
          SelectableText(track.sourceUrl!),
          const SizedBox(height: 8),
          const Text('Лицензия:'),
          SelectableText(track.licenseUrl!),
        ],
      );
    }
    final recording = _recordings[track.name]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${track.name} — ${track.artist} (incompetech.com)'),
        const SizedBox(height: 12),
        const Text('Creative Commons Attribution 4.0 (CC BY 4.0)'),
        const Text('Оригинальная запись используется без изменений.'),
        const SizedBox(height: 12),
        const Text('Источник (ссылку можно скопировать):'),
        SelectableText(
          'https://incompetech.com/music/royalty-free/index.html?isrc=${recording.isrc}',
        ),
        const SizedBox(height: 12),
        const Text('Лицензия:'),
        const SelectableText('https://creativecommons.org/licenses/by/4.0/'),
      ],
    );
  }

  static bool _secureUrl(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
