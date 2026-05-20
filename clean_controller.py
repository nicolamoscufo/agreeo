import re

with open('lib/features/friends/state/friends_movie_night_controller.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the import for mock movies and uuid
content = re.sub(r"import 'package:agreeo/shared/mock_data/mock_movies\.dart';\n", '', content)

# Remove _seedLocalSocialLayer definition and its helpers
start_seed = content.find('  List<Movie> _catalogMovies() {')
end_class = content.find('}\n\nfinal friendsMovieNightControllerProvider')
if start_seed != -1 and end_class != -1:
    content = content[:start_seed] + content[end_class:]

with open('lib/features/friends/state/friends_movie_night_controller.dart', 'w', encoding='utf-8') as f:
    f.write(content)
