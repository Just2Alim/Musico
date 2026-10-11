import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class GraphQLConfig {
  static String get apiUrl => 'http://localhost:4000/graphql'; // Для Android эмулятора
  // static String get apiUrl => 'http://localhost:4000/graphql'; // Для iOS симулятора
  // static String get apiUrl => 'http://YOUR_SERVER_IP:4000/graphql'; // Для реальных устройств

  static final ValueNotifier<GraphQLClient> clientValueNotifier = ValueNotifier<GraphQLClient>(_createClient());

// В файле graphql_config.dart
  static GraphQLClient _createClient() {
    final HttpLink httpLink = HttpLink(apiUrl);

    final AuthLink authLink = AuthLink(
      getToken: () async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          print('Using token for authentication: Bearer $token');
          return 'Bearer $token';
        }
        print('No authentication token found');
        return null;
      },
    );

    final Link link = authLink.concat(httpLink);

    return GraphQLClient(
      cache: GraphQLCache(store: HiveStore()),
      link: link,
    );
  }

  static GraphQLClient get client => clientValueNotifier.value;

  static GraphQLClient initClient() {
    return client;
  }
}