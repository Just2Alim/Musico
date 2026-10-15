import 'package:json_annotation/json_annotation.dart';

part 'venue.g.dart';

@JsonSerializable()
class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.address,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.websiteUrl,
  });

  @JsonKey(fromJson: _venueInt, defaultValue: 0)
  final int id;
  @JsonKey(defaultValue: 'Площадка')
  final String name;
  @JsonKey(defaultValue: '')
  final String address;
  @JsonKey(defaultValue: '')
  final String description;
  @JsonKey(fromJson: _venueDouble, defaultValue: 0)
  final double latitude;
  @JsonKey(fromJson: _venueDouble, defaultValue: 0)
  final double longitude;
  @JsonKey(name: 'website_url')
  final String? websiteUrl;

  factory Venue.fromJson(Map<String, dynamic> json) => _$VenueFromJson(json);

  Map<String, dynamic> toJson() => _$VenueToJson(this);
}

int _venueInt(Object? value) => value is num ? value.toInt() : 0;

double _venueDouble(Object? value) => value is num ? value.toDouble() : 0;
