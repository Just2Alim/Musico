// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'music_data_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Playlist _$PlaylistFromJson(Map<String, dynamic> json) => Playlist(
  id: json['id'] == null ? 0 : _playlistInt(json['id']),
  name: json['name'] as String? ?? 'Untitled Playlist',
  subtitle: json['subtitle'] as String?,
  imageUrl: _readPlaylistImage(json, 'image_url') as String?,
  trackCount: _readPlaylistTrackCount(json, 'track_count') == null
      ? 0
      : _playlistInt(_readPlaylistTrackCount(json, 'track_count')),
  userId: _readPlaylistUserId(json, 'user_id') as String? ?? '',
);

Map<String, dynamic> _$PlaylistToJson(Playlist instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'subtitle': instance.subtitle,
  'image_url': instance.imageUrl,
  'track_count': instance.trackCount,
  'user_id': instance.userId,
};
