import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../graphql/graphql_config.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _loginUser() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    const String loginMutation = '''
      mutation Login(\$email: String!, \$password: String!) {
        login(email: \$email, password: \$password) {
          token
          user {
            id
            name
            email
          }
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(loginMutation),
      variables: {
        'email': email,
        'password': password,
      },
    );

    final GraphQLClient client = GraphQLConfig.initClient();
    final QueryResult result = await client.mutate(options);

    setState(() => _isLoading = false);

    if (result.hasException) {
      _showError(result.exception.toString());
    } else {
      final authData = result.data?['login'];
      if (authData != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', authData['token']);
        await prefs.setInt('userId', authData['user']['id']);
        await prefs.setString('name', authData['user']['name']);
        await prefs.setString('email', authData['user']['email']);

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError('Login failed. Please try again.');
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome Back',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.green)
                : ElevatedButton(
                    onPressed: _loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/register');
              },
              child: const Text(
                "Don't have an account? Sign up",
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}