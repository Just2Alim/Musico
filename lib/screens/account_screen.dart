import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../graphql/graphql_config.dart';
import '../providers/AudioPlayerAlternativeProvider.dart';
import '../widgets/mini_player.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEditing = false;
  String? _userName;
  String? _userEmail;
  String? _profileImageUrl;
  
  // Контроллеры для текстовых полей
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // Данные для статистики
  Map<String, dynamic> _userStats = {
    'totalListened': 0,
    'favoriteGenres': <String, int>{},
    'topArtists': <String, int>{},
    'listeningByDay': <String, int>{},
    'playlistsCount': 0,
    'favoritesCount': 0,
    'recentlyPlayedCount': 0,
  };
  
  // Настройки пользователя
  Map<String, dynamic> _userSettings = {
    'language': 'Русский',
    'darkMode': true,
    'audioQuality': 'Высокое качество',
    'downloadOverMobile': false,
    'showExplicitContent': true,
    'autoPlayNext': true,
  };
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
    _fetchUserStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _imageUrlController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<int?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  void _loadUserData() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.query(
        QueryOptions(
          document: gql('''
            query Me {
              me {
                id
                name
                email
                settings {
                  language
                  darkMode
                  audioQuality
                }
              }
            }
          '''),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      
      if (result.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных профиля: ${result.exception.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final userData = result.data?['me'];
      if (userData != null) {
        setState(() {
          _userName = userData['name'];
          _userEmail = userData['email'];
          
          // Предположим, что у нас есть аватар из gravatar или подобного сервиса
          // В реальном приложении здесь будет реальный URL из базы данных
          _profileImageUrl = 'https://www.gravatar.com/avatar/${userData['email'].hashCode}?d=identicon&s=200';
          
          // Заполняем контроллеры текущими значениями
          _nameController.text = _userName ?? '';
          _emailController.text = _userEmail ?? '';
          _imageUrlController.text = _profileImageUrl ?? '';
          
          // Если есть настройки, заполняем их
          if (userData['settings'] != null) {
            _userSettings['language'] = _mapLanguage(userData['settings']['language']);
            _userSettings['darkMode'] = userData['settings']['darkMode'] ?? true;
            _userSettings['audioQuality'] = _mapAudioQuality(userData['settings']['audioQuality']);
          }
          
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка загрузки данных профиля: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Произошла ошибка: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Преобразование языкового кода в читаемое название
  String _mapLanguage(String? langCode) {
    switch (langCode) {
      case 'ru': return 'Русский';
      case 'en': return 'English';
      case 'kk': return 'Қазақша';
      default: return 'Русский';
    }
  }
  
  // Преобразование кода качества аудио в читаемое название
  String _mapAudioQuality(String? quality) {
    switch (quality) {
      case 'low': return 'Низкое качество';
      case 'normal': return 'Стандартное качество';
      case 'high': return 'Высокое качество';
      default: return 'Высокое качество';
    }
  }

  // Получение статистики пользователя
  void _fetchUserStatistics() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return;
      
      // Генерируем демо-данные для статистики (в реальном приложении они будут из API)
      setState(() {
        // Общее время прослушивания (в часах)
        _userStats['totalListened'] = Random().nextInt(300) + 50;
        
        // Любимые жанры
        _userStats['favoriteGenres'] = {
          'Поп': Random().nextInt(80) + 20,
          'Рок': Random().nextInt(60) + 10,
          'Хип-хоп': Random().nextInt(50) + 5,
          'Электроника': Random().nextInt(40) + 15,
          'Джаз': Random().nextInt(30),
        };
        
        // Топ исполнителей
        _userStats['topArtists'] = {
          'Ed Sheeran': Random().nextInt(30) + 10,
          'Imagine Dragons': Random().nextInt(25) + 5,
          'The Weeknd': Random().nextInt(20) + 15,
          'Billie Eilish': Random().nextInt(15) + 10,
          'Queen': Random().nextInt(10) + 5,
        };
        
        // Прослушивания по дням недели
        _userStats['listeningByDay'] = {
          'Пн': Random().nextInt(10) + 2,
          'Вт': Random().nextInt(10) + 2,
          'Ср': Random().nextInt(10) + 2,
          'Чт': Random().nextInt(10) + 2,
          'Пт': Random().nextInt(10) + 2,
          'Сб': Random().nextInt(10) + 2,
          'Вс': Random().nextInt(10) + 2,
        };
        
        // Количество плейлистов, избранного и недавно прослушанного
        _userStats['playlistsCount'] = Random().nextInt(20) + 1;
        _userStats['favoritesCount'] = Random().nextInt(100) + 10;
        _userStats['recentlyPlayedCount'] = Random().nextInt(500) + 50;
      });
      
    } catch (e) {
      print('Ошибка загрузки статистики: $e');
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      
      // Если выходим из режима редактирования, сбрасываем значения контроллеров
      if (!_isEditing) {
        _nameController.text = _userName ?? '';
        _emailController.text = _userEmail ?? '';
        _imageUrlController.text = _profileImageUrl ?? '';
        
        // Очистить поля пароля
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    });
  }

  Future<void> _saveProfile() async {
    // Проверяем, что поля не пустые
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Имя и email не могут быть пустыми')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Обновляем профиль
      final GraphQLClient client = GraphQLConfig.initClient();
      final QueryResult result = await client.mutate(
        MutationOptions(
          document: gql('''
            mutation UpdateProfile(\$name: String, \$email: String) {
              updateProfile(name: \$name, email: \$email) {
                id
                name
                email
              }
            }
          '''),
          variables: {
            'name': _nameController.text,
            'email': _emailController.text,
          },
        ),
      );
      
      if (result.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления профиля: ${result.exception.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Если нужно обновить пароль
      if (_currentPasswordController.text.isNotEmpty && 
          _newPasswordController.text.isNotEmpty && 
          _confirmPasswordController.text.isNotEmpty) {
        
        // Проверяем, что новые пароли совпадают
        if (_newPasswordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Новые пароли не совпадают')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        // Обновляем пароль
        final passwordResult = await client.mutate(
          MutationOptions(
            document: gql('''
              mutation UpdatePassword(\$oldPassword: String!, \$newPassword: String!) {
                updatePassword(oldPassword: \$oldPassword, newPassword: \$newPassword)
              }
            '''),
            variables: {
              'oldPassword': _currentPasswordController.text,
              'newPassword': _newPasswordController.text,
            },
          ),
        );
        
        if (passwordResult.hasException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка обновления пароля: ${passwordResult.exception.toString()}')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      
      // Обновляем настройки пользователя
      final settingsResult = await client.mutate(
        MutationOptions(
          document: gql('''
            mutation UpdateUserSettings(\$language: String, \$darkMode: Boolean, \$audioQuality: String) {
              updateUserSettings(language: \$language, darkMode: \$darkMode, audioQuality: \$audioQuality) {
                language
                darkMode
                audioQuality
              }
            }
          '''),
          variables: {
            'language': _getLanguageCode(_userSettings['language']),
            'darkMode': _userSettings['darkMode'],
            'audioQuality': _getAudioQualityCode(_userSettings['audioQuality']),
          },
        ),
      );
      
      if (settingsResult.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления настроек: ${settingsResult.exception.toString()}')),
        );
      }
      
      // Обновляем данные в UI
      setState(() {
        _userName = _nameController.text;
        _userEmail = _emailController.text;
        if (_imageUrlController.text.isNotEmpty) {
          _profileImageUrl = _imageUrlController.text;
        }
        _isEditing = false;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Профиль успешно обновлен')),
      );
      
      // Очистить поля пароля
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      
    } catch (e) {
      print('Ошибка сохранения профиля: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Произошла ошибка: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Получение кода языка из читаемого названия
  String _getLanguageCode(String language) {
    switch (language) {
      case 'Русский': return 'ru';
      case 'English': return 'en';
      case 'Қазақша': return 'kk';
      default: return 'ru';
    }
  }
  
  // Получение кода качества аудио из читаемого названия
  String _getAudioQualityCode(String quality) {
    switch (quality) {
      case 'Низкое качество': return 'low';
      case 'Стандартное качество': return 'normal';
      case 'Высокое качество': return 'high';
      default: return 'high';
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Ошибка при выходе: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выходе: $e')),
      );
    }
  }
  
  // Визуализация жанров
  Widget _buildGenresVisualization() {
    final Map<String, int> genres = _userStats['favoriteGenres'] as Map<String, int>;
    final List<Color> colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.amber,
      Colors.purple,
    ];
    
    return Column(
      children: [
        for (int i = 0; i < genres.entries.length; i++)
          _buildGenreBar(
            genres.keys.elementAt(i),
            genres.values.elementAt(i),
            colors[i % colors.length],
          ),
      ],
    );
  }
  
  // Полоса для визуализации жанра
  Widget _buildGenreBar(String genre, int count, Color color) {
    // Находим максимальное значение для масштабирования
    final int maxValue = (_userStats['favoriteGenres'] as Map<String, int>).values.reduce(max);
    final double percentage = count / maxValue;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                genre,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[800],
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Визуализация прослушиваний по дням недели
  Widget _buildWeeklyListeningVisualization() {
    final Map<String, int> data = _userStats['listeningByDay'] as Map<String, int>;
    final List<Color> colors = [
      Colors.green.shade200,
      Colors.green.shade300,
      Colors.green.shade400,
      Colors.green.shade500,
      Colors.green.shade600,
      Colors.green.shade700,
      Colors.green.shade800,
    ];
    final int maxValue = data.values.reduce(max);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: data.entries.map((entry) {
        final int index = data.keys.toList().indexOf(entry.key);
        final double percentage = entry.value / maxValue;
        
        return Column(
          children: [
            Container(
              width: 30,
              height: 100,
              margin: EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[800],
              ),
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: colors[index % colors.length],
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              entry.key,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            SizedBox(height: 4),
            Text(
              entry.value.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioPlayerAlternativeProvider>(context);
    final currentTrack = audioProvider.currentTrack;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Градиентный фон
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.green.withOpacity(0.6),
                  Colors.black,
                ],
              ),
            ),
          ),
          
          // Основной контент
          _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.green))
              : SafeArea(
                  child: Column(
                    children: [
                      // Шапка с аватаром и именем
                      _buildProfileHeader(),
                      
                      // Табы
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: Colors.green,
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey,
                          tabs: [
                            Tab(text: 'Профиль'),
                            Tab(text: 'Статистика'),
                            Tab(text: 'Настройки'),
                          ],
                        ),
                      ),
                      
                      // Контент табов
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Таб профиля
                            _buildProfileTab(),
                            
                            // Таб статистики
                            _buildStatsTab(),
                            
                            // Таб настроек
                            _buildSettingsTab(),
                          ],
                        ),
                      ),
                      
                      // Пространство для мини-плеера
                      SizedBox(height: currentTrack != null ? 80 : 0),
                    ],
                  ),
                ),
          
          // Мини-плеер
          if (currentTrack != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(
                trackName: currentTrack.name,
                artistName: currentTrack.artist,
                coverImageUrl: currentTrack.coverImageUrl,
                isPlaying: audioProvider.isPlaying,
                isLoading: audioProvider.isLoading,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/player',
                    arguments: {'trackId': currentTrack.id},
                  );
                },
                onPlayPause: () {
                  audioProvider.togglePlayPause();
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 3, // Account tab
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Поиск'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Библиотека'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Аккаунт'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/search');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/library');
              break;
            case 3:
              // Уже на экране аккаунта
              break;
          }
        },
      ),
    );
  }
  
  // Шапка профиля
  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        children: [
          // Кнопка "назад"
          GestureDetector(
            onTap: () {
              if (_isEditing) {
                _toggleEditMode();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isEditing ? Icons.close : Icons.arrow_back,
                color: Colors.white,
              ),
            ),
          ),
          
          Expanded(
            child: Center(
              child: Text(
                _isEditing ? 'Редактировать профиль' : 'Профиль',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Кнопка редактирования
          GestureDetector(
            onTap: _isEditing ? _saveProfile : _toggleEditMode,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isEditing ? Colors.green : Colors.grey[900]!.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isEditing ? Icons.check : Icons.edit,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Таб профиля
  Widget _buildProfileTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Аватар пользователя
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[800],
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null
                    ? Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
              if (_isEditing)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 20),
        
        // Имя пользователя
        if (_isEditing)
          TextField(
            controller: _nameController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Имя',
              labelStyle: TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.person, color: Colors.grey),
            ),
          )
        else
          Center(
            child: Text(
              _userName ?? 'Пользователь',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        SizedBox(height: 10),
        
        // Email пользователя
        if (_isEditing)
          TextField(
            controller: _emailController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.email, color: Colors.grey),
            ),
          )
        else
          Center(
            child: Text(
              _userEmail ?? 'email@example.com',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        SizedBox(height: 20),
        
        // URL изображения (только в режиме редактирования)
        if (_isEditing)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'URL аватара',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _imageUrlController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'URL изображения',
                  labelStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.image, color: Colors.grey),
                ),
              ),
              SizedBox(height: 30),
              
              // Секция изменения пароля
              Text(
                'Изменить пароль',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _currentPasswordController,
                style: TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Текущий пароль',
                  labelStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.lock, color: Colors.grey),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _newPasswordController,
                style: TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Новый пароль',
                  labelStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.lock_open, color: Colors.grey),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _confirmPasswordController,
                style: TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Подтвердите новый пароль',
                  labelStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.lock_open, color: Colors.grey),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              // Плитки с информацией о профиле
              _buildInfoTile(
                icon: Icons.playlist_play,
                title: 'Плейлистов',
                value: _userStats['playlistsCount'].toString(),
                color: Colors.blue,
              ),
              SizedBox(height: 10),
              _buildInfoTile(
                icon: Icons.favorite,
                title: 'Избранных треков',
                value: _userStats['favoritesCount'].toString(),
                color: Colors.red,
              ),
              SizedBox(height: 10),
              _buildInfoTile(
                icon: Icons.history,
                title: 'Прослушано треков',
                value: _userStats['recentlyPlayedCount'].toString(),
                color: Colors.amber,
              ),
              SizedBox(height: 10),
              _buildInfoTile(
                icon: Icons.access_time,
                title: 'Часов музыки прослушано',
                value: _userStats['totalListened'].toString(),
                color: Colors.green,
              ),
              
              // Карточка Premium подписки
              SizedBox(height: 30),
              _buildPremiumCard(),
            ],
          ),
        
        // Кнопка выхода
        SizedBox(height: 40),
        if (!_isEditing)
          ElevatedButton.icon(
            onPressed: _logout,
            icon: Icon(Icons.logout),
            label: Text('Выйти'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
      ],
    );
  }
  
  // Таб статистики
  Widget _buildStatsTab() {
    final genres = _userStats['favoriteGenres'] as Map<String, int>;
    final artists = _userStats['topArtists'] as Map<String, int>;
    
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Общая статистика прослушиваний
        Text(
          'Статистика прослушиваний',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Часов',
                value: _userStats['totalListened'].toString(),
                icon: Icons.access_time,
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Треков',
                value: _userStats['recentlyPlayedCount'].toString(),
                icon: Icons.music_note,
                color: Colors.green,
              ),
            ),
          ],
        ),
        
        // График прослушиваний по дням недели
        SizedBox(height: 30),
        Text(
          'Активность по дням недели',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
          ),
          child: _buildWeeklyListeningVisualization(),
        ),
        
        // Диаграмма жанров
        SizedBox(height: 30),
        Text(
          'Любимые жанры',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
          ),
          child: _buildGenresVisualization(),
        ),
        
        // Топ исполнителей
        SizedBox(height: 30),
        Text(
          'Топ исполнителей',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Column(
          children: artists.entries.map((entry) {
            return _buildArtistListItem(
              name: entry.key,
              count: entry.value,
            );
          }).toList(),
        ),
        
        // Рекомендации на основе статистики
        SizedBox(height: 30),
        Text(
          'Рекомендации для вас',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        _buildRecommendationCard(),
        SizedBox(height: 16),
        _buildDiscoverWeeklyCard(),
        
        // Кнопка экспорта статистики
        SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Экспорт статистики будет доступен в ближайшем обновлении')),
            );
          },
          icon: Icon(Icons.download),
          label: Text('Экспортировать статистику'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[900],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
  
  // Таб настроек
  Widget _buildSettingsTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Настройки аккаунта
        Text(
          'Настройки аккаунта',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        _buildSettingsTile(
          icon: Icons.language,
          title: 'Язык',
          value: _userSettings['language'],
          onTap: () {
            _showLanguageDialog();
          },
        ),
        SizedBox(height: 10),
        _buildSwitchTile(
          icon: Icons.dark_mode,
          title: 'Темная тема',
          value: _userSettings['darkMode'],
          onChanged: (bool value) {
            setState(() {
              _userSettings['darkMode'] = value;
            });
          },
        ),
        
        // Настройки воспроизведения
        SizedBox(height: 30),
        Text(
          'Настройки воспроизведения',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        _buildSettingsTile(
          icon: Icons.high_quality,
          title: 'Качество аудио',
          value: _userSettings['audioQuality'],
          onTap: () {
            _showAudioQualityDialog();
          },
        ),
        SizedBox(height: 10),
        _buildSwitchTile(
          icon: Icons.network_cell,
          title: 'Загружать через мобильную сеть',
          value: _userSettings['downloadOverMobile'],
          onChanged: (bool value) {
            setState(() {
              _userSettings['downloadOverMobile'] = value;
            });
          },
        ),
        SizedBox(height: 10),
        _buildSwitchTile(
          icon: Icons.explicit,
          title: 'Показывать эксплицитный контент',
          value: _userSettings['showExplicitContent'],
          onChanged: (bool value) {
            setState(() {
              _userSettings['showExplicitContent'] = value;
            });
          },
        ),
        SizedBox(height: 10),
        _buildSwitchTile(
          icon: Icons.fast_forward,
          title: 'Автоматически воспроизводить следующий трек',
          value: _userSettings['autoPlayNext'],
          onChanged: (bool value) {
            setState(() {
              _userSettings['autoPlayNext'] = value;
            });
          },
        ),
        
        // Дополнительные настройки
        SizedBox(height: 30),
        Text(
          'Дополнительно',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        _buildActionTile(
          icon: Icons.delete,
          title: 'Очистить кэш',
          subtitle: 'Освободите место на устройстве',
          onTap: () {
            _showClearCacheDialog();
          },
        ),
        SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.backup,
          title: 'Резервное копирование данных',
          subtitle: 'Сохраните плейлисты и настройки',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Резервное копирование будет доступно в ближайшем обновлении')),
            );
          },
        ),
        SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.info_outline,
          title: 'О приложении',
          subtitle: 'Версия 1.0.0',
          onTap: () {
            _showAboutDialog();
          },
        ),
        
        SizedBox(height: 30),
      ],
    );
  }
  
  // Карточка с информацией о пользователе
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Карточка Premium подписки
  Widget _buildPremiumCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[900]!, Colors.purple[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.stars,
                color: Colors.amber,
                size: 26,
              ),
              SizedBox(width: 8),
              Text(
                'Premium',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Получите доступ к эксклюзивным функциям',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• Офлайн-режим\n• Высокое качество звука\n• Без рекламы\n• Неограниченное количество плейлистов',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Premium подписка будет доступна в ближайшем обновлении')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
            child: Text(
              'Попробовать Premium',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Карточка с рекомендацией
  Widget _buildRecommendationCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        image: DecorationImage(
          image: NetworkImage('https://i.scdn.co/image/ab67706f00000003e8e28219724c2423afa4d320'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.darken,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: NetworkImage('https://i.scdn.co/image/ab67706f00000003e8e28219724c2423afa4d320'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'На основе ваших предпочтений',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Микс из любимых треков',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Плейлист будет доступен в ближайшем обновлении')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(100, 30),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text('Слушать'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Карточка с еженедельным дайджестом
  Widget _buildDiscoverWeeklyCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        image: DecorationImage(
          image: NetworkImage('https://i.scdn.co/image/ab67706f00000003c414e7daf34690c9f983f76e'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.darken,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: NetworkImage('https://i.scdn.co/image/ab67706f00000003c414e7daf34690c9f983f76e'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Обновляется каждый понедельник',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Открытие недели',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Плейлист будет доступен в ближайшем обновлении')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(100, 30),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text('Слушать'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Карточка статистики
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  // Элемент списка артистов
  Widget _buildArtistListItem({
    required String name,
    required int count,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[800],
            backgroundImage: NetworkImage(
              'https://api.dicebear.com/7.x/initials/png?seed=$name&radius=50'
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$count прослушиваний',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.play_circle_filled,
            color: Colors.green,
            size: 36,
          ),
        ],
      ),
    );
  }
  
  // Элемент настроек
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
  
  // Элемент настроек с переключателем
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }
  
  // Элемент настроек с действием
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
  
  // Диалог выбора языка
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Выберите язык',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption('Русский'),
              _buildLanguageOption('English'),
              _buildLanguageOption('Қазақша'),
            ],
          ),
        );
      },
    );
  }
  
  // Опция выбора языка
  Widget _buildLanguageOption(String language) {
    return ListTile(
      title: Text(
        language,
        style: TextStyle(color: Colors.white),
      ),
      trailing: _userSettings['language'] == language
          ? Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () {
        setState(() {
          _userSettings['language'] = language;
        });
        Navigator.pop(context);
      },
    );
  }
  
  // Диалог выбора качества аудио
  void _showAudioQualityDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Качество аудио',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAudioQualityOption(
                'Низкое качество',
                'Экономит трафик (96 кбит/с)',
              ),
              _buildAudioQualityOption(
                'Стандартное качество',
                'Баланс качества и трафика (160 кбит/с)',
              ),
              _buildAudioQualityOption(
                'Высокое качество',
                'Лучшее качество звука (320 кбит/с)',
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Опция выбора качества аудио
  Widget _buildAudioQualityOption(String quality, String description) {
    return ListTile(
      title: Text(
        quality,
        style: TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        description,
        style: TextStyle(color: Colors.grey),
      ),
      trailing: _userSettings['audioQuality'] == quality
          ? Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () {
        setState(() {
          _userSettings['audioQuality'] = quality;
        });
        Navigator.pop(context);
      },
    );
  }
  
  // Диалог очистки кэша
  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Очистить кэш?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Это действие удалит все временные файлы, но сохранит ваши плейлисты и настройки.',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Отмена',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Кэш успешно очищен')),
                );
              },
              child: Text(
                'Очистить',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );
  }
  // Диалог "О приложении"
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'О приложении',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Justify Music',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Версия 1.0.0',
                style: TextStyle(color: Colors.grey[400]),
              ),
              SizedBox(height: 16),
              Text(
                'Музыкальное приложение для воспроизведения, организации и обмена музыкой. Создавайте плейлисты, открывайте новую музыку и наслаждайтесь высоким качеством звучания.',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                '© 2025 Justify Team',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Закрыть',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );
  }
}