# Источники музыки Musico

В онлайн-каталог подготовлены шесть настоящих композиций Kevin MacLeod.
Аудио воспроизводится по HTTPS с официального сайта автора incompetech.com.
Копии файлов не загружаются в Supabase, обложки чужих альбомов не используются.
Supabase хранит только метаданные и адреса потоков.

## Авторство и лицензия

Автор всех шести произведений: **Kevin MacLeod (incompetech.com)**.
Лицензия: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
Записи используются без изменений; интерфейс плеера должен сохранять название,
имя автора, ссылку на источник и ссылку на лицензию в доступных пользователю сведениях о треке.

[Официальные условия автора](https://incompetech.com/music/royalty-free/licenses/)
предлагают бесплатное использование с указанием авторства.
[Шаблон страницы композиции](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN2000005)
содержит блок атрибуции Creative Commons By Attribution 4.0.

Для каждого трека применяется атрибуция:

> «Название трека» — Kevin MacLeod (incompetech.com). CC BY 4.0.
> https://creativecommons.org/licenses/by/4.0/. Используется без изменений.

| Композиция и источник | ISRC | Жанр автора | Длительность |
|---|---|---|---|
| [Moonlight Beach](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN2000005) | USUAN2000005 | World | 5:39 |
| [Summer Day](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1200083) | USUAN1200083 | Contemporary | 3:18 |
| [All This](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1300001) | USUAN1300001 | Soundtrack | 3:49 |
| [Tiki Bar Mixer](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN2000006) | USUAN2000006 | World | 3:32 |
| [Acid Trumpet](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100339) | USUAN1100339 | Jazz | 3:28 |
| [Easy Lemon](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1200076) | USUAN1200076 | Contemporary | 2:06 |

Длительности, имена MP3 и ISRC взяты из актуального
[каталога автора pieces.json](https://incompetech.com/music/royalty-free/pieces.json).
Названия жанров сопоставлены по официальной
[странице каталога](https://incompetech.com/music/royalty-free/music.html).
Длительность, определённая декодером при воспроизведении, может немного отличаться.

## Наполнение базы

Идемпотентный SQL: `supabase/seeds/real_tracks.sql`.
Он добавляет только отсутствующие записи и сохраняет ID существующих треков.
Запускать через SQL Editor проекта Supabase от администратора базы.
Скрипт не создаёт публичных прав на запись в каталог и не содержит ключей.

Этот файл фиксирует происхождение музыки; факт применения seed к облачной базе
и результаты запуска приложения записываются отдельно в `DEVELOPMENT_STATUS.md`.

## Проверка источников 15 октября 2026

Все шесть HTTPS MP3-адресов из seed вернули HTTP 200 на HEAD-запрос.
Сервер поддерживает `Accept-Ranges: bytes`; Content-Type — `application/octet-stream`.
Заголовок `Access-Control-Allow-Origin` отсутствует. Это не подтверждает и не исключает
работу конкретного web-плеера: проверять нужно его реальное воспроизведение.
Нативному Android-плееру браузерный CORS не требуется.

Прямые URL зависят от доступности сервера автора. При сетевой ошибке приложение
должно показывать ошибку загрузки и позволять повторить воспроизведение.
