-- Original artist streams. Attribution and source records: docs/MUSIC_SOURCES.md.
-- Kevin MacLeod (incompetech.com), Creative Commons Attribution 4.0.
-- https://creativecommons.org/licenses/by/4.0/
-- Run as the project database administrator, never from a public Flutter client.
-- Re-running does not duplicate tracks or replace existing track IDs / favorites.
begin;
lock table public.tracks in share row exclusive mode;

with seed(name, artist, genre, duration, audio_file_url) as (
  values
    ('Moonlight Beach', 'Kevin MacLeod', 'World', 339,
     'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Moonlight%20Beach.mp3'),
    ('Summer Day', 'Kevin MacLeod', 'Contemporary', 198,
     'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Summer%20Day.mp3'),
    ('All This', 'Kevin MacLeod', 'Soundtrack', 229,
     'https://incompetech.com/music/royalty-free/mp3-royaltyfree/All%20This.mp3'),
    ('Tiki Bar Mixer', 'Kevin MacLeod', 'World', 212,
     'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Tiki%20Bar%20Mixer.mp3'),
    ('Acid Trumpet', 'Kevin MacLeod', 'Jazz', 208,
     'https://incompetech.com/music/royalty-free/mp3-royaltyfree/AcidJazz.mp3'),
    ('Easy Lemon', 'Kevin MacLeod', 'Contemporary', 126,
     'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Easy%20Lemon.mp3')
)
insert into public.tracks
  (name, artist, genre, duration, cover_image_url, audio_file_url)
select s.name, s.artist, s.genre, s.duration, null, s.audio_file_url
from seed s
where not exists (
  select 1 from public.tracks t
  where t.audio_file_url = s.audio_file_url
     or (t.name = s.name and t.artist = s.artist)
);
commit;
