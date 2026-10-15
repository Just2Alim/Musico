import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/venue.dart';
import '../../domain/use_cases/load_venues.dart';

class VenuesScreen extends StatefulWidget {
  const VenuesScreen({super.key});

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> {
  late Future<List<Venue>> _venuesFuture;
  GoogleMapController? _mapController;
  Position? _position;
  String? _locationError;

  static const _mapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const _defaultPosition = LatLng(43.2383, 76.9455);

  @override
  void initState() {
    super.initState();
    _venuesFuture = _loadVenues();
  }

  Future<List<Venue>> _loadVenues() async {
    return context.read<LoadVenues>()();
  }

  Future<void> _locateMe() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Доступ к геопозиции не разрешён.');
        return;
      }
      final current = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _position = current;
        _locationError = null;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(current.latitude, current.longitude),
          13,
        ),
      );
    } on LocationServiceDisabledException {
      if (mounted)
        setState(() => _locationError = 'Включите службы геолокации.');
    } catch (_) {
      if (mounted)
        setState(() => _locationError = 'Не удалось определить место.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Концертные площадки')),
    body: FutureBuilder<List<Venue>>(
      future: _venuesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _MessageState(
            message:
                'Не удалось загрузить площадки. Проверьте Supabase и сеть.',
            onRetry: () => setState(() => _venuesFuture = _loadVenues()),
          );
        }
        final venues = snapshot.data ?? const <Venue>[];
        if (venues.isEmpty) {
          return _MessageState(
            message: 'Площадки пока не добавлены в каталог Supabase.',
            onRetry: () => setState(() => _venuesFuture = _loadVenues()),
          );
        }
        final markers = venues
            .map(
              (venue) => Marker(
                markerId: MarkerId('venue-${venue.id}'),
                position: LatLng(venue.latitude, venue.longitude),
                infoWindow: InfoWindow(
                  title: venue.name,
                  snippet: venue.address,
                ),
              ),
            )
            .toSet();
        return Column(
          children: [
            Expanded(
              flex: 3,
              child: _mapsKey.isEmpty || kIsWeb
                  ? _MapSetupNotice(hasKey: _mapsKey.isNotEmpty)
                  : GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _defaultPosition,
                        zoom: 11,
                      ),
                      markers: markers,
                      myLocationEnabled: _position != null,
                      onMapCreated: (controller) => _mapController = controller,
                    ),
            ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _locationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${venues.length} площадок',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'Моё местоположение',
                    onPressed: _locateMe,
                    icon: const Icon(Icons.my_location),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: venues.length,
                itemBuilder: (context, index) {
                  final venue = venues[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.music_note)),
                    title: Text(venue.name),
                    subtitle: Text(venue.address),
                    onTap: _mapController == null
                        ? null
                        : () => _mapController!.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(venue.latitude, venue.longitude),
                              15,
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _MapSetupNotice extends StatelessWidget {
  const _MapSetupNotice({required this.hasKey});
  final bool hasKey;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          hasKey
              ? 'Карта доступна в нативной Android/iOS сборке. В Web отображается список площадок.'
              : 'Добавьте ограниченный Google Maps API key для включения карты. Список площадок доступен ниже.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    ),
  );
}
