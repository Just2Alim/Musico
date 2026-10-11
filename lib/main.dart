import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'screens/account_screen.dart';
import 'services/detailed_playlist_screen.dart';
import 'screens/home_screen.dart';
import 'services/library_screen.dart';
import 'screens/login_screen.dart';
import 'services/player_screen.dart';
import 'screens/register_screen.dart';
import 'services/search_screen.dart';
import 'graphql/graphql_config.dart';
import 'providers/AudioPlayerAlternativeProvider.dart';
import 'providers/MusicDataProvider.dart';
import 'package:window_size/window_size.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      setWindowTitle('Justify');
      // setWindowMinSize(const Size(1280, 720));
      // setWindowMaxSize(const Size(1280, 720));
    }
  
  await initHiveForFlutter();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioPlayerAlternativeProvider()),
        ChangeNotifierProvider(create: (_) => MusicDataProvider()),
      ],
      child: JustifyApp(),
    ),
  );
}

class JustifyApp extends StatefulWidget {
  @override
  _JustifyAppState createState() => _JustifyAppState();
}

class _JustifyAppState extends State<JustifyApp> {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    
    setState(() {
      _isLoggedIn = userId != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Justify',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                CircularProgressIndicator(color: Colors.green),
              ],
            ),
          ),
        ),
      );
    }

    return GraphQLProvider(
      client: GraphQLConfig.clientValueNotifier,
      child: MaterialApp(
        title: 'Justify Music',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: Colors.green,
          scaffoldBackgroundColor: Colors.black,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSwatch().copyWith(
            secondary: Colors.green,
            brightness: Brightness.dark,
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
          ),
          sliderTheme: SliderThemeData(
            activeTrackColor: Colors.green,
            inactiveTrackColor: Colors.grey[800],
            thumbColor: Colors.white,
            overlayColor: Colors.green.withOpacity(0.2),
            trackHeight: 2.0,
          ),
        ),
        initialRoute: _isLoggedIn ? '/home' : '/login',
        routes: {
          '/login': (context) => LoginScreen(),
          '/register': (context) => RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/account': (context) => const AccountScreen(),
          '/search': (context) => const SearchScreen(),
          '/library': (context) => const LibraryScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/playlist') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => DetailedPlaylistScreen(arguments: args),
            );
          } else if (settings.name == '/player') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => PlayerScreen(arguments: args),
            );
          }
          return null;
        },
        builder: (context, child) {
          return child ?? Container();
        },
      ),
    );
  }
}