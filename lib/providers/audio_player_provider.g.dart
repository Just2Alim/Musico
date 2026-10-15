// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_player_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Track _$TrackFromJson(Map<String, dynamic> json) => Track(
  id: json['id'] == null ? 0 : _trackInt(json['id']),
  name: json['name'] as String? ?? 'Unknown Track',
  artist: json['artist'] as String? ?? 'Unknown Artist',
  genre: json['genre'] as String?,
  coverImageUrl: _readTrackCover(json, 'cover_image_url') as String?,
  audioFileUrl: _readTrackAudio(json, 'audio_file_url') as String? ?? '',
  duration: json['duration'] == null ? 0 : _trackInt(json['duration']),
  isLiked: json['isLiked'] as bool? ?? false,
);

Map<String, dynamic> _$TrackToJson(Track instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'artist': instance.artist,
  'genre': instance.genre,
  'cover_image_url': instance.coverImageUrl,
  'audio_file_url': instance.audioFileUrl,
  'duration': instance.duration,
  'isLiked': instance.isLiked,
};
