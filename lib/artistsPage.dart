import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'artistSongs.dart';

class ArtistsPage extends StatefulWidget {
  final String filter;
  final Function(String) updateFilter;

  ArtistsPage({required this.filter, required this.updateFilter});

  @override
  _ArtistsPageState createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  List<Artist> artists = [];

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  @override
  void didUpdateWidget(covariant ArtistsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter != oldWidget.filter) {
      _loadArtists();
    }
  }

  void _loadArtists() async {
    final List<Artist> loadedArtists =
        await getArtistsFromDatabase(widget.filter);
    setState(() {
      artists = loadedArtists;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final Artist artist = artists[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: artist.img != null
                  ? AssetImage('assets/images/artists/${artist.img}.png')
                  : AssetImage('assets/images/song.png'),
              radius: 25,
            ),
            title: Text(
              artist.artist,
              style: TextStyle(
                fontFamily: 'monospace',
              ),
            ),
            subtitle: Text(
              '',
              style: TextStyle(
                fontFamily: 'monospace',
              ),
            ),
            trailing: GestureDetector(
              onTap: () {
                final bool isFavorite = !artist.favorite_artist;
                _updateFavoriteStatus(artist, isFavorite);
              },
              child: Icon(
                artist.favorite_artist ? Icons.favorite : Icons.favorite_border,
                color: artist.favorite_artist ? Colors.red : null,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtistsSongsPage(artist: artist.artist),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _updateFavoriteStatus(Artist artist, bool isFavorite) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'my_database.db');

    final db = await openDatabase(
      path,
      version: 1,
    );

    final int favoriteValue = isFavorite ? 1 : 0;

    await db.update(
      'Songs',
      {'favorite_artist': favoriteValue},
      where: 'artist = ?',
      whereArgs: [artist.artist],
    );

    await db.close();

    setState(() {
      artist.favorite_artist = isFavorite;
    });
  }
}

Future<List<Artist>> getArtistsFromDatabase(String filter) async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final path = join(documentsDirectory.path, 'my_database.db');

  final db = await openDatabase(
    path,
    version: 1,
  );

  String query;
  if (filter == 'All') {
    query = 'SELECT DISTINCT artist, img, favorite_artist FROM Songs';
  } else if (filter == 'Favorite') {
    query =
        'SELECT DISTINCT artist, img, favorite_artist FROM Songs WHERE favorite_artist = 1';
  } else {
    query =
        'SELECT DISTINCT artist, img, favorite_artist FROM Songs WHERE artist LIKE "$filter%"';
  }

  final List<Map<String, dynamic>> maps = await db.rawQuery(query);
  final List<Artist> artists = maps.map((map) => Artist.fromMap(map)).toList();

  await db.close();
  return artists;
}

// Future<List<Artist>> getArtistsFromDatabase() async {
//   final documentsDirectory = await getApplicationDocumentsDirectory();
//   final path = join(documentsDirectory.path, 'my_database.db');

//   final db = await openDatabase(
//     path,
//     version: 1,
//   );

//   final List<Map<String, dynamic>> maps = await db
//       .rawQuery('SELECT DISTINCT artist, img, favorite_artist FROM Songs');
//   final List<Artist> artists = maps.map((map) => Artist.fromMap(map)).toList();

//   await db.close();
//   return artists;
// }

class Artist {
  String artist;
  String img;
  bool favorite_artist;

  Artist({
    required this.artist,
    required this.img,
    required this.favorite_artist,
  });

  factory Artist.fromMap(Map<String, dynamic> map) {
    return Artist(
      artist: map['artist'],
      img: map['img'],
      favorite_artist: map['favorite_artist'] == 1,
    );
  }
}
