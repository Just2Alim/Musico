import '../entities/venue.dart';

abstract interface class VenueRepository {
  Future<List<Venue>> fetchVenues();
}
