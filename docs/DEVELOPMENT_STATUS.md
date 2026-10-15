# Musico: состояние выполнения требований

Эта запись разделяет готовую реализацию и пункты, для которых требуется облачная авторизация, реальные ключи, устройство или аккаунт магазина. 12 октября 2026 миграция была применена в Supabase Dashboard; данные и другие внешние интеграции проверены отдельно ниже.

## Проверено 15 октября 2026

- Flutter 3.41.6 / Dart 3.11.4; установленный Pixel 9 Pro XL API 37.2 (arm64, 16 KB pages) запущен и отображается в Android Studio → Running Devices.
- Supabase REST `tracks`: HTTP 200, 7 записей. Добавлены Moonlight Beach, Summer Day, All This, Tiki Bar Mixer, Acid Trumpet, Easy Lemon — Kevin MacLeod, CC BY 4.0. Ссылки и права: `MUSIC_SOURCES.md`; seed не изменяет RLS.
- Android `integration_test/app_flow_test.dart` завершился `All tests passed`: реальный MP3, движение позиции, пауза, seek на 30 секунд, повторное открытие без сброса/автозапуска, следующий MP3 и поиск Easy Lemon. Запуск: `./tool/test_android.sh`.
- Исправлены загрузка трека по ID вне первой страницы, гонки загрузки/избранного, сброс позиции, поиск при сетевой ошибке и устаревшие ответы debounce, состояние избранного в поиске и очереди. При смене аккаунта личные данные очищаются; медиатека обновляется при выборе вкладки.
- Добавлены создание плейлистов из медиатеки и авторство/лицензия в меню плеера. Убрана ссылка на отсутствующий `default_cover.jpg`; пустая обложка безопасно отображается в portrait/landscape.
- Владелец вошёл через email/password на эмуляторе. Через UI созданы личный плейлист `Musico Online`, запись Moonlight Beach в нём и избранное; повторное открытие медиатеки подтвердило записи. Во вкладке истории появилась прослушанная композиция. Google OAuth, push, карта, iOS, публикация и физические датчики этим прогоном не подтверждались.
- Скриншоты: `evidence/android-catalog-20261015.png`, `evidence/android-playlist-20261015.png`, `evidence/android-final-20261015.jpg`, `evidence/supabase-catalog-20261015.png`.
- Финальный локальный прогон: 148 unit/widget tests прошли; line coverage 88.9% (порог ≥80%). Android Studio hot reload применил исправление высоты карточек; приложение осталось открыто на главной с авторизованной сессией, личным плейлистом и мини-плеером.
- После исправления последнего предупреждения повторный `flutter analyze --no-pub --no-fatal-infos` завершился без ошибок и предупреждений; остались 342 информационных lint suggestions. `dart format --output=none --set-exit-if-changed lib test integration_test` и `git diff --check` проходят.

## Реализовано в коде

- Dart 3 с null safety, Material 3, светлая/тёмная темы, адаптивные списки и именованные GoRouter маршруты с авторизационными redirect.
- Слои presentation/domain/data, `MusicRepository`, get_it для DI, Provider для состояния каталога и `PlaybackCubit` для управления воспроизведением.
- Supabase Auth/PostgREST REST-каталог через `http`, `json_serializable` модели, SQL-схема с RLS, Hive offline cache, SharedPreferences для темы и языка, поиск, пагинация и кэширование обложек.
- Системное управление аудио через `audio_service`: уведомление воспроизведения, метаданные и команды lock screen/следующий/предыдущий трек. В коде также есть настройка акселерометра «встряхнуть для следующего трека» и Android MethodChannel для батареи.
- Экран площадок с Google Maps/геолокацией и inbox Supabase с Realtime подпиской для уведомлений во время работы приложения.
- Supabase Edge Function `report-crash`: проверка JWT, ограничение частоты и только безопасные поля через service-role на сервере.
- GitHub Actions workflow и Android release signing gate: release-сборка отклоняется без приватного `android/key.properties`.
- Учебные примеры Dart и тесты Week 1 находятся в `lib/coursework/dart_practice.dart` и `test/coursework/dart_practice_test.dart`; сценарий защиты — в `docs/PRESENTATION_SCRIPT_RU.md`.
- Недели 3–7: сравнение `setState`/`InheritedWidget`/Provider доступно из настроек; responsive grid/navigation проверяются на телефоне и планшете в портретной/альбомной ориентации. JSON-модели Track/Playlist/Venue сгенерированы `json_serializable`.

## Проверено локально 12 октября 2026 (исторический снимок; актуальные результаты — выше)

- `dart format --output=none --set-exit-if-changed lib test integration_test` завершился без изменений.
- `flutter analyze --no-pub --no-fatal-infos` завершился с кодом 0: ошибок и предупреждений нет; остаются 343 информационных lint suggestions. Обычный `flutter analyze` завершается кодом 1 из-за этих info-level lint suggestions.
- `flutter test --coverage --no-pub`: 42 теста прошли; line coverage 59.0% (`596/1010`). Пороговый скрипт `tool/check_coverage.sh` прошёл.
- До последних DI/навигационных изменений Android integration test `app_flow_test.dart` проходил на эмуляторе Android 15/API 35; debug APK был установлен и запущен в сценарии. После последних изменений повторный Android прогон не выполнен.
- `flutter build apk --debug --no-pub` создал `build/app/outputs/flutter-apk/app-debug.apk` после установки полного Android NDK 28.2; APK пересобран после изменений для РК1.
- `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols` создал подписанный `build/app/outputs/bundle/release/app-release.aab` (43.8 MB); `jarsigner -verify` подтвердил подпись. Для подписи локально создан upload keystore; оба файла с паролями/ключом исключены из Git.
- `flutter build web --no-pub` завершился успешно после изменений для РК1.
- Для недель 3–7 добавлены исполняемое сравнение `setState`/`InheritedWidget`/Provider, контейнер `get_it`, REST/JSON путь каталога через `http`, `json_serializable` модели, сохранение языка, NavigationRail и проверки телефона/планшета в portrait/landscape.
- `flutter run -d web-server` запустил приложение на `http://127.0.0.1:8765`; главная страница, поиск и пустые состояния каталога отрисовались. Ошибок приложения в браузерной консоли не найдено; Chrome сообщил только о программном WebGL-рендеринге.
- Supabase Dashboard показывает здоровый проект `Musico`. SQL миграция `202610110001_initial_schema.sql` применена через SQL Editor: созданы 9 таблиц, на всех включён RLS, найдены 15 политик, созданы публичные `track-audio` и `track-covers`.
- Edge Function `report-crash` развернута в Dashboard. Для её кода используются серверные переменные Supabase; secret/service-role key не добавлялся в клиент или чат.
- По разрешению пользователя загружен один оригинальный синтетический WAV длительностью 9 секунд в публичный `track-audio` и добавлена одна запись `Neon Tide (Demo)`. REST вернул её с HTTP 200; публичный WAV отвечает HTTP 200 (`audio/wav`, 396944 байта). Коммерческие аудиофайлы не загружались. Реальные лицензированные треки и venues не загружены.
- В этой сессии повторное открытие локального Flutter web-server после наполнения каталога показало пустую белую вкладку: 1121 DDC-скрипт загрузился, ошибок в консоли не появилось, но canvas приложения не отрисовался. Штатный `flutter run -d chrome` сообщил об успешном старте `main`, Hive, Supabase и аудиоплеера, однако окно этого запуска не удалось визуально проверить; `flutter test integration_test/app_flow_test.dart -d chrome` инструмент Flutter завершил сообщением, что web integration tests не поддерживаются. Поэтому playback именно через UI с demo-треком не подтверждён.
- SQL применён через Dashboard, CLI migration history отдельно не синхронизирована. Локальный SQL-файл остаётся источником миграции; перед дальнейшим использованием CLI сначала проверьте состояние migration history.
- Текущий `flutter doctor -v` сообщает о непринятых лицензиях Android SDK и неполной установке Xcode. Для первого нужно принять юридические лицензии на устройстве владельца; второй требует полной установки Xcode.
- Подписанный AAB был собран до последних изменений недель 1–7; перед использованием релиза его нужно пересобрать.
- Android/iOS bundle ID и OAuth callback scheme приведены к `com.just2alim.musico`; владелец должен проверить уникальность ID в Play Console перед первой загрузкой.
- `plutil -lint ios/Runner/Info.plist` и `git diff --check` прошли.
- В этой проверке Flutter обнаружил Chrome и macOS; доступный AVD не был запущен, поэтому свежий Android integration test не повторялся. Веб-версия запущена и проверена визуально.

## Остаётся сделать владельцу проекта или подтвердить на устройстве

### Supabase, каталог и Google OAuth

- Реальные лицензированные аудиозаписи добавлены 15 октября. Обложки и записи `venues` ещё требуют наполнения. Не загружать в публичный бакет коммерческие MP3 без права распространения.
- Включить Google provider в Supabase Auth и задать OAuth client IDs/callbacks для фактических Android/iOS package IDs. Email/password вход подтверждён на Android 15 октября; Google OAuth отдельно не проверен.
- Секретный Supabase API key, присланный в чат, необходимо отозвать/заменить в Dashboard. Новый secret/service-role key не помещать в Flutter, `.env.local` или Git. Если старый ключ попадал в историю remote Git, его также следует отозвать.

### Каталог, карта и уведомления

- Добавить ограниченный Google Maps API key в локальный `.env.local`; без него список площадок остаётся доступен, но Google tiles не загружаются.
- Уведомления сейчас работают как Supabase inbox и foreground Realtime. Это не системная доставка push при закрытом приложении. Для неё нужны Android/iOS push credentials и выбранный transport. Firebase SDK намеренно не возвращён по запросу пользователя.

### Устройства, DevTools, CI и публикация

- Проверить на физическом Android: запуск APK, фоновое воспроизведение и lock-screen controls, датчик встряхивания, батарейный MethodChannel, разрешение геолокации.
- Установить полный Xcode и проверить iOS сборку, audio background mode, карту и OAuth. Сейчас `xcodebuild` недоступен, так как активны только Command Line Tools; iOS MethodChannel батареи нет.
- Снять реальные DevTools Performance/Memory показатели «до/после» и скриншоты на телефоне/планшете; не заменять их вымышленными числами.
- Удалённый GitHub Actions run/artifact не подтверждён и появится только после push в GitHub.
- Перед магазином проверить доступность bundle ID в Play Console, сохранить отдельную резервную копию `android/app/upload-keystore.jks` и `android/key.properties`, заполнить юридические поля privacy policy/store listing, сделать скриншоты и пройти Play Console internal testing. Аккаунта магазина в текущей сессии нет.
- Финальная презентация и устная защита должны быть выполнены студентом; сценарий подготовки предоставлен в `docs/PRESENTATION_SCRIPT_RU.md`.
