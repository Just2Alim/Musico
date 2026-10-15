import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/domain/entities/venue.dart';
import 'package:musico_app/domain/repositories/venue_repository.dart';
import 'package:musico_app/domain/use_cases/load_venues.dart';

class _FakeVenueRepository implements VenueRepository {
  @override
  Future<List<Venue>> fetchVenues() async => const [
    Venue(
      id: 1,
      name: 'Room',
      address: 'City',
      description: '',
      latitude: 43.2,
      longitude: 76.9,
    ),
  ];
}

void main() {
  test('parses numeric coordinates and optional venue details', () {
    final venue = Venue.fromJson({
      'id': 9,
      'name': 'Almaty Arena',
      'address': 'Almaty',
      'latitude': 43.2,
      'longitude': 76.9,
      'website_url': 'https://example.test',
    });

    expect(venue.id, 9);
    expect(venue.latitude, 43.2);
    expect(venue.longitude, 76.9);
    expect(venue.websiteUrl, 'https://example.test');
    expect(venue.description, isEmpty);
  });

  test('uses safe defaults for incomplete rows', () {
    final venue = Venue.fromJson({});
    expect(venue.name, 'Площадка');
    expect(venue.address, isEmpty);
    expect(venue.latitude, 0);
  });

  test('loads venues through the domain repository contract', () async {
    final venues = await LoadVenues(_FakeVenueRepository())();
    expect(venues.single.name, 'Room');
  });
}
