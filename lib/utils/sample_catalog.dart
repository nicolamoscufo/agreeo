import 'package:agreeo/models/app_models.dart';

final List<Movie> demoMovieCatalog = <Movie>[
  Movie(
    id: 'movie-dune-2',
    title: 'Dune: Part Two',
    overview:
        'Paul rallies the Fremen and takes the fight to the forces that destroyed his family.',
    posterUrl: 'https://picsum.photos/seed/dune-part-two/600/900',
    releaseYear: 2024,
    runtimeMinutes: 166,
    genres: <String>['Sci-Fi', 'Adventure', 'Drama'],
    streamingServices: <String>['Max', 'Prime Video'],
    mediaType: MediaType.movie,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Dune+Part+Two+trailer',
    score: 9.4,
  ),
  Movie(
    id: 'movie-innerspace',
    title: 'Inner Space',
    overview:
        'A college friend group tries to stay close while their post-grad plans diverge.',
    posterUrl: 'https://picsum.photos/seed/innerspace/600/900',
    releaseYear: 2023,
    runtimeMinutes: 118,
    genres: <String>['Drama', 'Comedy', 'Romance'],
    streamingServices: <String>['Netflix', 'Prime Video'],
    mediaType: MediaType.movie,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Inner+Space+movie+trailer',
    score: 8.7,
  ),
  Movie(
    id: 'movie-nightshift',
    title: 'Night Shift',
    overview:
        'An exhausted support crew uncovers a larger conspiracy during a single chaotic night.',
    posterUrl: 'https://picsum.photos/seed/nightshift/600/900',
    releaseYear: 2022,
    runtimeMinutes: 101,
    genres: <String>['Thriller', 'Mystery'],
    streamingServices: <String>['Netflix', 'Disney+'],
    mediaType: MediaType.movie,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Night+Shift+trailer',
    score: 8.5,
  ),
  Movie(
    id: 'movie-echoes',
    title: 'Echoes of Us',
    overview:
        'Two old friends reconnect over one weekend and rethink the life they built apart.',
    posterUrl: 'https://picsum.photos/seed/echoes/600/900',
    releaseYear: 2024,
    runtimeMinutes: 109,
    genres: <String>['Drama', 'Romance'],
    streamingServices: <String>['Apple TV+', 'Netflix'],
    mediaType: MediaType.movie,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Echoes+of+Us+trailer',
    score: 8.4,
  ),
  Movie(
    id: 'movie-velocity',
    title: 'Velocity Run',
    overview:
        'A street racer becomes the last hope for a city locked under surveillance.',
    posterUrl: 'https://picsum.photos/seed/velocity-run/600/900',
    releaseYear: 2021,
    runtimeMinutes: 127,
    genres: <String>['Action', 'Thriller'],
    streamingServices: <String>['Prime Video', 'Disney+'],
    mediaType: MediaType.movie,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Velocity+Run+trailer',
    score: 8.1,
  ),
  Movie(
    id: 'series-counterpoint',
    title: 'Counterpoint',
    overview:
        'A music collective fights burnout, ego, and fame while building their first album.',
    posterUrl: 'https://picsum.photos/seed/counterpoint/600/900',
    releaseYear: 2024,
    runtimeMinutes: 48,
    genres: <String>['Drama', 'Music'],
    streamingServices: <String>['Netflix'],
    mediaType: MediaType.series,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Counterpoint+series+trailer',
    score: 8.0,
  ),
  Movie(
    id: 'series-labyrinth',
    title: 'Labyrinth Code',
    overview:
        'A group of students decode a hidden system beneath their university.',
    posterUrl: 'https://picsum.photos/seed/labyrinth-code/600/900',
    releaseYear: 2023,
    runtimeMinutes: 52,
    genres: <String>['Mystery', 'Sci-Fi'],
    streamingServices: <String>['Prime Video', 'Max'],
    mediaType: MediaType.series,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Labyrinth+Code+trailer',
    score: 8.3,
  ),
  Movie(
    id: 'movie-sunlit',
    title: 'Sunlit Saturdays',
    overview:
        'Friends coordinate a summer of low-stakes adventures and impossible decisions.',
    posterUrl: 'https://picsum.photos/seed/sunlit-saturdays/600/900',
    releaseYear: 2020,
    runtimeMinutes: 95,
    genres: <String>['Comedy', 'Slice of Life'],
    streamingServices: <String>['Netflix', 'Apple TV+'],
    mediaType: MediaType.movie,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Sunlit+Saturdays+trailer',
    score: 8.2,
  ),
  Movie(
    id: 'movie-midnight',
    title: 'Midnight Theory',
    overview:
        'An online mystery grows into a real-world chase for a hidden archive.',
    posterUrl: 'https://picsum.photos/seed/midnight-theory/600/900',
    releaseYear: 2022,
    runtimeMinutes: 114,
    genres: <String>['Mystery', 'Thriller'],
    streamingServices: <String>['Disney+', 'Prime Video'],
    mediaType: MediaType.movie,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Midnight+Theory+trailer',
    score: 8.6,
  ),
  Movie(
    id: 'series-bloom',
    title: 'Bloom Room',
    overview:
        'A shared apartment becomes a rotating cast of relationships, plans, and confessions.',
    posterUrl: 'https://picsum.photos/seed/bloom-room/600/900',
    releaseYear: 2024,
    runtimeMinutes: 42,
    genres: <String>['Drama', 'Comedy'],
    streamingServices: <String>['Apple TV+', 'Netflix'],
    mediaType: MediaType.series,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Bloom+Room+series+trailer',
    score: 7.9,
  ),
  Movie(
    id: 'movie-arcade',
    title: 'Arcade Ghosts',
    overview:
        'A group of friends must restore a vanished arcade before the building is demolished.',
    posterUrl: 'https://picsum.photos/seed/arcade-ghosts/600/900',
    releaseYear: 2019,
    runtimeMinutes: 112,
    genres: <String>['Comedy', 'Adventure'],
    streamingServices: <String>['Prime Video', 'Netflix'],
    mediaType: MediaType.movie,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Arcade+Ghosts+trailer',
    score: 7.8,
  ),
  Movie(
    id: 'movie-horizon',
    title: 'Horizon After Dark',
    overview:
        'An engineer and a documentarian chase the truth behind a disappearing shoreline.',
    posterUrl: 'https://picsum.photos/seed/horizon-after-dark/600/900',
    releaseYear: 2023,
    runtimeMinutes: 123,
    genres: <String>['Drama', 'Adventure'],
    streamingServices: <String>['Max', 'Apple TV+'],
    mediaType: MediaType.movie,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Horizon+After+Dark+trailer',
    score: 8.0,
  ),
  Movie(
    id: 'series-noise',
    title: 'Noise Floor',
    overview:
        'A campus podcast team exposes the social dynamics hiding behind every viral clip.',
    posterUrl: 'https://picsum.photos/seed/noise-floor/600/900',
    releaseYear: 2021,
    runtimeMinutes: 44,
    genres: <String>['Drama', 'Mystery'],
    streamingServices: <String>['Netflix', 'Disney+'],
    mediaType: MediaType.series,
    trailerUrl:
        'https://www.youtube.com/results?search_query=Noise+Floor+series+trailer',
    score: 7.7,
  ),
];
