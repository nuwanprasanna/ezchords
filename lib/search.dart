import 'package:flutter/material.dart';
import 'main.dart';

class SongSearchDelegate extends SearchDelegate<String> {
  final List<Song> songs;

  SongSearchDelegate(this.songs);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final filteredSongs = songs
        .where((song) =>
            song.title.toLowerCase().contains(query.toLowerCase()) ||
            song.pitch.toLowerCase().contains(query.toLowerCase()) ||
            song.artist.toLowerCase().contains(query.toLowerCase()) ||
            song.lyrics.toLowerCase().contains(query.toLowerCase()) ||
            song.beat.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return SongListWidget(
      songs: filteredSongs,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filteredSongs = songs
        .where((song) =>
            song.title.toLowerCase().contains(query.toLowerCase()) ||
            song.pitch.toLowerCase().contains(query.toLowerCase()) ||
            song.artist.toLowerCase().contains(query.toLowerCase()) ||
            song.beat.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return SongListWidget(
      songs: filteredSongs,
    );
  }
}

class SongListWidget extends StatefulWidget {
  final List<Song> songs;

  SongListWidget({required this.songs});

  @override
  _SongListWidgetState createState() => _SongListWidgetState();
}

class _SongListWidgetState extends State<SongListWidget> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.songs.length,
      itemBuilder: (context, index) {
        final song = widget.songs[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: song.img != null
                ? AssetImage('assets/images/artists/${song.img}' + '.png')
                : AssetImage('assets/images/song.png'),
            radius: 25,
          ),
          title: Text(
            song.title,
            style: TextStyle(
              fontFamily: 'Poppins',
            ),
          ),
          subtitle: Text(
            song.artist,
            style: TextStyle(
              fontFamily: 'Poppins',
            ),
          ),
          trailing: IconButton(
            icon: Icon(
              song.favorite ? Icons.favorite : Icons.favorite_border,
              color: song.favorite ? Colors.red : null,
            ),
            onPressed: () {
              setState(() {
                song.favorite = !song.favorite;
                _updateFavoriteStatus2(song);
              });
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
    );
  }

  void _updateFavoriteStatus2(Song song) async {
    final db = await DatabaseHelper().db;
    await db.update(
      'Songs',
      {'favorite': song.favorite ? 1 : 0}, // Convert boolean to integer
      where: 'title = ?',
      whereArgs: [song.title],
    );
  }
}
