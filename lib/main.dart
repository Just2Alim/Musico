import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_size/window_size.dart';

import 'data/local_music_cache.dart';
import 'data/music_repository.dart';
import 'data/crash_report_service.dart';
import 'domain/use_cases/load_venues.dart';
import 'data/supabase_config.dart';
import 'data/theme_provider.dart';
import 'di/service_locator.dart';
import 'features/player/playback_cubit.dart';
import 'features/player/music_audio_handler.dart';
import 'features/navigation/main_navigation_shell.dart';
import 'features/venues/venues_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'coursework/state_management_examples_screen.dart';
import 'providers/audio_player_provider.dart';
import 'providers/music_data_provider.dart';
import 'screens/account_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/detailed_playlist_screen.dart';
import 'services/library_screen.dart';
import 'services/player_screen.dart';
import 'services/search_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.validate();
  final needsSystemAudioService =
      kIsWeb ||
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform);
  final MusicAudioHandler? audioHandler = needsSystemAudioService
      ? await AudioService.init<MusicAudioHandler>(
          builder: () => MusicAudioHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'app.musico.audio',
            androidNotificationChannelName: 'Musico playback',
            androidNotificationOngoing: true,
          ),
        )
      : null;
  if (!kIsWeb &&
      const {
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform)) {
    setWindowTitle('Musico');
  }
  await Hive.initFlutter();
  await Hive.openBox<String>('music_cache');
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    final reporter = CrashReportService();
    final previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutterErrorHandler?.call(details);
      unawaited(reporter.report(details.exception));
    };
    PlatformDispatcher.instance.onError = (error, _) {
      unawaited(reporter.report(error));
      return false;
    };
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  final client = SupabaseConfig.isConfigured ? Supabase.instance.client : null;
  configureDependencies(
    client: client,
    supabaseUrl: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
    backendEnabled: SupabaseConfig.isConfigured,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        Provider<MusicRepository>.value(value: appLocator<MusicRepository>()),
        Provider<LoadVenues>.value(value: appLocator<LoadVenues>()),
        Provider<LocalMusicCache>.value(value: appLocator<LocalMusicCache>()),
        ChangeNotifierProvider(create: (_) => appLocator<MusicDataProvider>()),
        ChangeNotifierProvider(
          create: (context) {
            final provider = AudioPlayerAlternativeProvider(
              context.read<MusicRepository>(),
              audioHandler: audioHandler,
            );
            unawaited(provider.loadShakeToSkipSetting());
            return provider;
          },
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                PlaybackCubit(context.read<AudioPlayerAlternativeProvider>()),
          ),
        ],
        child: const MusicoApp(),
      ),
    ),
  );
}

class MusicoApp extends StatelessWidget {
  const MusicoApp({super.key});

  static final _authRefresh = _AuthRefreshNotifier();
  static final _router = GoRouter(
    refreshListenable: _authRefresh,
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/home'),
      GoRoute(path: '/login', name: 'login', builder: (_, __) => LoginScreen()),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (_, __) => RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainNavigationShell(
          navigationShell: navigationShell,
          onBranchSelected: (index) {
            if (index != 2) return;
            final music = context.read<MusicDataProvider>();
            // Indexed branches stay mounted; refresh data changed elsewhere.
            // Each provider operation reports failures in its observable state.
            unawaited(
              Future.wait([
                music.loadUserPlaylists(),
                music.loadFavoriteTracks(),
                music.loadRecentlyPlayed(),
              ]),
            );
          },
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                builder: (_, __) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                name: 'library',
                builder: (_, __) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                name: 'account',
                builder: (_, __) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/venues',
        name: 'venues',
        builder: (_, __) => const VenuesScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/coursework/state-management',
        name: 'state-management-examples',
        builder: (_, __) => const StateManagementExamplesScreen(),
      ),
      GoRoute(
        path: '/playlist/:playlistId',
        name: 'playlist',
        builder: (_, state) => DetailedPlaylistScreen(
          arguments: {
            'playlistId':
                int.tryParse(state.pathParameters['playlistId'] ?? '') ?? 0,
          },
        ),
      ),
      GoRoute(
        path: '/player/:trackId',
        name: 'player',
        builder: (_, state) => PlayerScreen(
          arguments: {
            'trackId': int.tryParse(state.pathParameters['trackId'] ?? '') ?? 0,
          },
        ),
      ),
    ],
    redirect: (context, state) {
      final needsAuth =
          state.matchedLocation == '/library' ||
          state.matchedLocation == '/account' ||
          state.matchedLocation == '/notifications' ||
          state.matchedLocation.startsWith('/playlist/');
      if (!SupabaseConfig.isConfigured && needsAuth) return '/login';
      if (!SupabaseConfig.isConfigured) return null;
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      if (needsAuth && !loggedIn) return '/login';
      if (loggedIn && state.matchedLocation == '/login') return '/home';
      return null;
    },
  );

  ThemeData _theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1DB954),
      brightness: brightness,
      surface: brightness == Brightness.dark
          ? const Color(0xFF121212)
          : Colors.white,
    ),
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF080B0A)
        : const Color(0xFFF6F8F6),
    fontFamily: 'Roboto',
  );

  @override
  Widget build(BuildContext context) => Consumer<ThemeProvider>(
    builder: (context, theme, _) => MaterialApp.router(
      title: 'Musico',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: theme.themeMode,
      locale: theme.locale,
      supportedLocales: const [Locale('ru'), Locale('en'), Locale('kk')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
    ),
  );
}

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    if (SupabaseConfig.isConfigured) {
      _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
        _,
      ) {
        notifyListeners();
      });
    }
  }

  StreamSubscription<AuthState>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
