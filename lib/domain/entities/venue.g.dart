// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'venue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Venue _$VenueFromJson(Map<String, dynamic> json) => Venue(
  id: json['id'] == null ? 0 : _venueInt(json['id']),
  name: json['name'] as String? ?? 'Площадка',
  address: json['address'] as String? ?? '',
  description: json['description'] as String? ?? '',
  latitude: json['latitude'] == null ? 0 : _venueDouble(json['latitude']),
  longitude: json['longitude'] == null ? 0 : _venueDouble(json['longitude']),
  websiteUrl: json['website_url'] as String?,
);

Map<String, dynamic> _$VenueToJson(Venue instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'address': instance.address,
  'description': instance.description,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'website_url': instance.websiteUrl,
};
