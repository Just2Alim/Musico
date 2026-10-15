import '../entities/venue.dart';
import '../repositories/venue_repository.dart';

class LoadVenues {
  const LoadVenues(this._repository);

  final VenueRepository _repository;

  Future<List<Venue>> call() => _repository.fetchVenues();
}
