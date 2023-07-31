import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

import 'main.dart';

class ArtistsSongsPage extends StatefulWidget {
  final String artist;

  ArtistsSongsPage({required this.artist});

  @override
  _ArtistsSongsPageState createState() => _ArtistsSongsPageState();
}

class _ArtistsSongsPageState extends State<ArtistsSongsPage> {
  List<Song> songs = [];

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  void _loadSongs() async {
    final List<Song> loadedSongs = await getArtistsFromDatabase(widget.artist);
    setState(() {
      songs = loadedSongs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.artist)),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: song.img != null
                  ? AssetImage('assets/images/artists/${song.img}.png')
                  : AssetImage('assets/images/song.png'),
              radius: 25,
            ),
            title: Text(
              song.title,
              style: TextStyle(
                fontFamily: 'monospace',
              ),
            ),
            subtitle: Text(
              song.artist,
              style: TextStyle(
                fontFamily: 'monospace',
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                song.favorite ? Icons.favorite : Icons.favorite_border,
                color: song.favorite ? Colors.red : null,
              ),
              onPressed: () {
                final bool isFavorite = !song.favorite;
                _updateFavoriteStatus(song, isFavorite);
              },
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SongDetail(song: song),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _updateFavoriteStatus(Song song, bool isFavorite) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'my_database.db');

    final db = await openDatabase(
      path,
      version: 1,
    );

    final int favoriteValue = isFavorite ? 1 : 0;

    await db.update(
      'Songs',
      {'favorite': favoriteValue},
      where: 'title = ?',
      whereArgs: [song.title],
    );

    await db.close();

    setState(() {
      song.favorite = !song.favorite;
    });
  }
}

Future<List<Song>> getArtistsFromDatabase(String artist) async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final path = join(documentsDirectory.path, 'my_database.db');

  final db = await openDatabase(
    path,
    version: 1,
  );

  String query2;
  query2 = 'SELECT * FROM Songs WHERE artist LIKE "$artist%"';

  final List<Map<String, dynamic>> maps = await db.rawQuery(query2);
  final List<Song> artists = maps.map((map) => Song.fromMap(map)).toList();

  await db.close();
  return artists;
}
