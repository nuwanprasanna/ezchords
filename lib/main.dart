import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'search.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'artistsPage.dart';
import 'package:url_launcher/url_launcher.dart';

const String _adUnitId = 'ca-app-pub-8658691433182302/4046021133';
final adUnitId2 = 'ca-app-pub-8658691433182302/5533296960';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();

  final documentsDirectory = await getApplicationDocumentsDirectory();
  final path = join(documentsDirectory.path, 'my_database.db');
  await openDatabase(
    path,
    version: 1,
    onCreate: (Database db, int version) async {
      await db.execute(
        'CREATE TABLE Songs (id INTEGER PRIMARY KEY, title TEXT, artist TEXT, pitch TEXT, beat TEXT, img TEXT, lyrics TEXT, favorite INTEGER DEFAULT 0, favorite_artist INTEGER DEFAULT 0)',
      );
    },
  );

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isConnected = true;
  bool _isDarkMode = false;

  String _latestVersion = '';
  String _appVersion = '1.0.5';
  bool _getVersionCalled = false;

  @override
  void initState() {
    super.initState();

    // Check for internet connection when the app is first opened
    Connectivity().checkConnectivity().then((connectivityResult) {
      setState(() {
        _isConnected = (connectivityResult != ConnectivityResult.none);
      });
    });

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (_isConnected) {
        getVersion;
      }
    });
  }

  Future<bool> getVersion(BuildContext context) async {
    if (_getVersionCalled) {
      return false; // Already called, so return false
    }
// Set the flag to true, so it won't be called again

    try {
      final response =
          await http.get(Uri.parse('https://streamy.eu.org/version.php'));
      final jsonData = jsonDecode(response.body);
      setState(() {
        _latestVersion = jsonData['latest_version'];
      });
      if (_appVersion != _latestVersion) {
        print(_latestVersion);
        getVersion;
        _getVersionCalled = true;
        return true;
      }
    } catch (e) {
      print(e.toString());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ez-chords',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.dark().copyWith(
          // Add light theme specific properties here
          ),
      darkTheme: ThemeData.light().copyWith(
          // Add dark theme specific properties here
          ),
      // home: _isConnected ? SongList() : NoInternetConnection(),

      home: FutureBuilder(
        future: getVersion(context),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Update Available'),
                  content: Text(
                    'A new version of the app is available. Please update to the latest version to continue using the app.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('OK'),
                    ),
                  ],
                ),
              );
            });
          }
          return SongList();
        },
      ),
    );
  }
}

class SongList extends StatefulWidget {
  @override
  _SongListState createState() => _SongListState();
}

class _SongListState extends State<SongList> {
  Future<List<Song>> _getSongs() async {
    var connectivityResult = await (Connectivity().checkConnectivity());

    if (connectivityResult == ConnectivityResult.none) {
      // No internet connection
      throw Exception('No internet connection');
    } else {
      final response =
          await http.get(Uri.parse('https://streamy.eu.org/lyrics.php'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> songsJson = json['songs'];

        return songsJson
            .map((songJson) => Song(
                title: songJson['title'],
                artist: songJson['artist'],
                pitch: songJson['pitch'],
                beat: songJson['beat'],
                img: songJson['img'],
                lyrics: songJson['lyrics']))
            .toList();
      } else {
        throw Exception('Failed to load songs from API');
      }
    }
  }

  String _currentPage = 'Songs';
  void _selectPage(String page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _saveSongs(List<Song> songs) async {
    final db = await DatabaseHelper().db;
    await db.transaction((txn) async {
      for (final song in songs) {
        await txn.insert('Songs', song.toMap());
      }
    });
  }

  Future<List<Song>> _loadSongsFromDatabase() async {
    final db = await DatabaseHelper().db;

    final List<Map<String, dynamic>> maps = await db.query('Songs');

    return List.generate(maps.length, (i) {
      return Song(
          title: maps[i]['title'],
          artist: maps[i]['artist'],
          pitch: maps[i]['pitch'],
          beat: maps[i]['beat'],
          img: maps[i]['img'],
          lyrics: maps[i]['lyrics'],
          favorite: maps[i]['favorite'],
          favorite_artist: maps[i]['favorite_artist']);
    });
  }

  Future<List<Song>> _loadSongs() async {
    final db = await DatabaseHelper().db;

    // Check if songs are already stored in the database
    final List<Map<String, dynamic>> maps = await db.query('Songs');
    if (maps.isNotEmpty) {
      return List.generate(maps.length, (i) {
        return Song(
          title: maps[i]['title'],
          artist: maps[i]['artist'],
          pitch: maps[i]['pitch'],
          beat: maps[i]['beat'],
          img: maps[i]['img'],
          lyrics: maps[i]['lyrics'],
          favorite: maps[i]['favorite'] == 1,
          favorite_artist:
              maps[i]['favorite_artist'] == 1, // Convert integer to boolean
        );
      });
    }

    // If songs are not in the database, download them from API and save to database
    try {
      final songsFromApi = await _getSongs();
      _saveSongs(songsFromApi);
      return songsFromApi;
    } catch (e) {
      print('Error loading songs from API: $e');
      return [];
    }
  }

  late Future<List<Song>> _futureSongs;
  late List<Song> _songs;
  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _futureSongs = _loadSongs();
  }

  BannerAd? _bannerAd;

  void _loadBannerAd() {
    // TODO: Replace the testAdUnitId with your AdMob ad unit ID.
    BannerAd bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _bannerAd = ad as BannerAd?;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
        },
      ),
    );

    bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _updateFavoriteStatus(Song song) async {
    final db = await DatabaseHelper().db;
    await db.update(
      'Songs',
      {'favorite': song.favorite ? 1 : 0}, // Convert boolean to integer
      where: 'title = ?',
      whereArgs: [song.title],
    );
  }

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _filter = "All";
  void updateFilter(newFilter) {
    setState(() {
      _filter = newFilter;
    });
  }

  void _launchFacebookMessengerChat() async {
    // Replace "USER_OR_PAGE_ID" with the ID of the user or page you want to chat with
    final userId = '100093030124171';

    // Check if the Messenger app is installed
    if (await canLaunch('fb-messenger://user/$userId')) {
      // Launch Messenger app with the specified user or page ID
      await launch('fb-messenger://user/$userId');
    } else {
      // If Messenger app is not installed, open Messenger in browser
      final url = 'https://m.me/$userId';
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch Facebook Messenger';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'EZ-CHORDS',
          style: TextStyle(
            fontSize: 24,
            fontFamily: 'Poppins',
          ),
        ),
        leading: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          child: GestureDetector(
            onTap: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            child: CircleAvatar(
              radius: 10.0,
              backgroundImage: AssetImage('assets/images/avatar.png'),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              final query = await showSearch(
                context: context,
                delegate: SongSearchDelegate(_songs),
              );
              if (query != null) {
                setState(() {
                  _songs = _filterSongs(query);
                });
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) => AppInfoDialog(),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Row(
                children: [
                  SizedBox(height: 20),
                  Image.asset(
                    'assets/images/logo.png', // Replace with your logo image path
                    width: 80,
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Guitar Chords', // Replace with your app name
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontFamily: 'Poppins', // Replace with your font family
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.music_note,
                color: Colors.white,
              ), // Icon for Songs
              title: Text(
                'Songs',
                style: TextStyle(
                  fontFamily: 'Poppins', // Replace with your font family
                ),
              ),
              selected: _currentPage == 'Songs',
              onTap: () {
                _selectPage('Songs');
                Navigator.pop(context);
                setState(() {
                  _filter = "All";
                });
              },
            ),
            ListTile(
              leading: Icon(
                Icons.person,
                color: Colors.white,
              ), // Icon for Artists
              title: Text(
                'Artists',
                style: TextStyle(
                  fontFamily: 'Poppins', // Replace with your font family
                ),
              ),
              selected: _currentPage == 'Artists',
              onTap: () {
                _selectPage('Artists');
                Navigator.pop(context);

                ArtistsPage(filter: _filter, updateFilter: updateFilter);
                setState(() {
                  _filter = "All";
                });
              },
            ),
            ListTile(
              leading: Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
              ), // Icon for Facebook Messenger
              title: Text(
                'Contact Us',
                style: TextStyle(
                  fontFamily: 'Poppins', // Replace with your font family
                ),
              ),
              onTap: () {
                _launchFacebookMessengerChat();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 10),
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _filter = "All";
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 5),
                    width: 50,
                    decoration: BoxDecoration(
                      color: _filter == "All"
                          ? Color.fromARGB(255, 8, 8, 8)
                          : Color.fromARGB(255, 97, 97, 97),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        "All",
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _filter = "Favorite";
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 5),
                    width: 50,
                    decoration: BoxDecoration(
                      color: _filter == "Favorite"
                          ? Color.fromARGB(255, 8, 8, 8)
                          : Color.fromARGB(255, 97, 97, 97),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.favorite,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                for (var i = 65; i <= 90; i++)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _filter = String.fromCharCode(i);
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 5),
                      width: 50,
                      decoration: BoxDecoration(
                        color: _filter == String.fromCharCode(i)
                            ? Color.fromARGB(255, 8, 8, 8)
                            : Color.fromARGB(255, 97, 97, 97),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(i),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            alignment: Alignment.bottomCenter,
            child: _bannerAd != null
                ? Container(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  )
                : SizedBox.shrink(),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: _currentPage == 'Songs'
                  ? FutureBuilder<List<Song>>(
                      future: _futureSongs,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          _songs = snapshot.data!;
                          if (_songs.isEmpty) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Image.asset(
                                  'assets/images/avatar.png',
                                  width: 250,
                                  height: 250,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Please connect to the internet and try again.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () async {
                                    SystemNavigator.pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    primary: Color.fromARGB(
                                      255,
                                      82,
                                      82,
                                      82,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text(
                                    'Exit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return ListView.builder(
                            itemCount: _songs.length,
                            itemBuilder: (context, index) {
                              final song = _songs[index];
                              if ((_filter == 'All' ||
                                      song.title[0].toUpperCase() ==
                                          _filter[0].toUpperCase()) ||
                                  (_filter == 'Favorite' && song.favorite)) {
                                print('$_filter');
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: song.img != null
                                        ? AssetImage(
                                            'assets/images/artists/${song.img}.png',
                                          )
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
                                      song.favorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: song.favorite ? Colors.red : null,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        song.favorite = !song.favorite;
                                        _updateFavoriteStatus(song);
                                      });
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            SongDetail(song: song),
                                      ),
                                    );
                                  },
                                );
                              } else {
                                return SizedBox.shrink();
                              }
                            },
                          );
                        } else if (snapshot.hasError) {
                          return Text('Error loading songs');
                        } else {
                          return Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                      },
                    )
                  : ArtistsPage(filter: _filter, updateFilter: updateFilter),
            ),
          ),
        ],
      ),
    );
  }

  List<Song> _filterSongs(String query) {
    return _songs.where((song) {
      final isFavorite = song.favorite;
      final matchesQuery =
          song.title.toLowerCase().contains(query.toLowerCase());

      if (_filter == 'All') {
        return matchesQuery;
      } else if (_filter == 'Favorite') {
        return isFavorite && matchesQuery;
      } else if (_filter == song.title[0].toUpperCase()) {
        return matchesQuery;
      }

      return false;
    }).toList();
  }
}

class ChordTransposer {
  static final List<String> chords = [
    'A',
    'A#',
    'B',
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'Bb',
    'B',
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab'
  ];

  static String transposeChord(String chord, int halfSteps) {
    if (chord.isEmpty) {
      return "";
    }

    if (halfSteps == 0) {
      return chord; // return original chord if no transposition required
    }

    String mainChord = chord;
    String m = '';
    String maj = '';
    String min = '';
    String aug = '';
    String sus = '';
    String dim = '';
    String add = '';
    String extension = '';
    String saccidental = '';
    String faccidental = '';

    if (chord.endsWith('sus4') || chord.endsWith('sus2')) {
      mainChord = chord.substring(0, chord.length - 4);
      sus = chord.substring(chord.length - 4);
    } else if (chord.endsWith('5') ||
        chord.endsWith('6') ||
        chord.endsWith('7') ||
        chord.endsWith('9')) {
      mainChord = chord.substring(0, chord.length - 1);
      extension = chord.substring(chord.length - 1);
    } else if (chord.endsWith('11') || chord.endsWith('13')) {
      mainChord = chord.substring(0, chord.length - 2);
      extension = chord.substring(chord.length - 2);
    }

    if (mainChord.endsWith('m')) {
      m = 'm';
      mainChord = mainChord.substring(0, mainChord.length - 1);
    } else if (mainChord.endsWith('maj')) {
      maj = 'maj';
      mainChord = mainChord.substring(0, mainChord.length - 3);
    } else if (mainChord.endsWith('min')) {
      min = 'min';
      mainChord = mainChord.substring(0, mainChord.length - 3);
    } else if (mainChord.endsWith('aug')) {
      aug = 'aug';
      mainChord = mainChord.substring(0, mainChord.length - 3);
    } else if (chord.endsWith('sus')) {
      mainChord = chord.substring(0, chord.length - 3);
      sus = 'sus';
    } else if (chord.endsWith('dim')) {
      mainChord = chord.substring(0, chord.length - 3);
      dim = 'dim';
    } else if (chord.endsWith('add')) {
      mainChord = chord.substring(0, chord.length - 3);
      add = 'add';
    }

    if (mainChord.endsWith('#') || mainChord.endsWith('b')) {
      saccidental = mainChord.substring(mainChord.length - 0);
      mainChord = mainChord.substring(0, mainChord.length - 0);
    }

    int index = chords.indexOf(mainChord) + halfSteps;
    if (index < 0) {
      index += 24;
    }
    if (index > 23) {
      index -= 24;
    }
    // print(chords[index % chords.length]);
    String transposedChord = chords[index % chords.length] +
        faccidental +
        saccidental +
        m +
        dim +
        add +
        sus +
        maj +
        min +
        aug +
        extension;

    return transposedChord;
  }

  static String transposeLyrics(String lyrics, int halfSteps) {
    RegExp chordRegExp = RegExp(
        r'([A-G][#b]?(sus|sus4|sus2|maj|min|aug|add|m)?(2|4|6|7|9|11|13)?)(?![a-zA-Z])');
    String transposedLyrics = lyrics.replaceAllMapped(
      chordRegExp,
      (match) => transposeChord(match.group(0)!, halfSteps),
    );
    // print(transposedLyrics);
    return transposedLyrics;
  }

  static String transposeKey(String chord, int halfSteps) {
    if (chord.isEmpty) {
      return "";
    }

    String rootNote =
        chord.endsWith("m") ? chord.substring(0, chord.length - 1) : chord;

    int index2 = chords.indexOf(rootNote) + halfSteps;
    int index = chords.indexOf(rootNote.toUpperCase()) + halfSteps;
    if (index < 0) {
      index += 24;
    }
    if (index > 23) {
      index -= 24;
    }
    // print(index2);
    return chords[index2 % chords.length];
  }
}

class SongDetail extends StatefulWidget {
  final Song song;

  SongDetail({required this.song});

  @override
  _SongDetailState createState() => _SongDetailState();
}

class _SongDetailState extends State<SongDetail> {
  ScrollController _scrollController = ScrollController();
  int _transposeValue = 0;
  bool _showAppBar = true;

  void _incrementTranspose() {
    setState(() {
      _transposeValue++;
    });
  }

  void _decrementTranspose() {
    setState(() {
      _transposeValue--;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    loadAd();
  }

  InterstitialAd? _interstitialAd;

  // TODO: replace this test ad unit with your own ad unit.

  /// Loads an interstitial ad.
  void loadAd() {
    InterstitialAd.load(
        adUnitId: adUnitId2,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          // Called when an ad is successfully received.
          onAdLoaded: (ad) {
            debugPrint('$ad loaded.');
            // Keep a reference to the ad so you can show it later.
            _interstitialAd = ad;
            _interstitialAd!.show();
          },
          // Called when an ad request failed.
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('InterstitialAd failed to load: $error');
          },
        ));
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  BannerAd? _bannerAd;

  void _loadBannerAd() {
    // TODO: Replace the testAdUnitId with your AdMob ad unit ID.
    BannerAd bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _bannerAd = ad as BannerAd?;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
        },
      ),
    );

    bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String originalLyrics = widget.song.lyrics;
    String transposedLyrics =
        ChordTransposer.transposeLyrics(originalLyrics, _transposeValue);

    // List<String> chords = [
    //   'A',
    //   'A#',
    //   'B',
    //   'C',
    //   'C#',
    //   'D',
    //   'D#',
    //   'E',
    //   'F',
    //   'F#',
    //   'G',
    //   'G#',
    //   'A',
    //   'Bb',
    //   'B',
    //   'C',
    //   'Db',
    //   'D',
    //   'Eb',
    //   'E',
    //   'F',
    //   'Gb',
    //   'G',
    //   'Ab',
    // ];

    RegExp chordRegex = RegExp(
        r'([A-G][#b]?(sus|sus4|sus2|maj|min|aug|add|m)?(2|4|6|7|9|11|13)?)(?![a-zA-Z])');

    List<RegExpMatch> matches =
        chordRegex.allMatches(transposedLyrics).toList();

    List<TextSpan> spans = [];

    int prevIndex = 0;
    for (RegExpMatch match in matches) {
      spans.add(TextSpan(
          text: transposedLyrics.substring(prevIndex, match.start),
          style: TextStyle(fontSize: 14, fontFamily: 'monospace')));
      spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              color: Color.fromARGB(255, 0, 247, 255))));
      prevIndex = match.end;
    }

    spans.add(TextSpan(
        text: transposedLyrics.substring(prevIndex),
        style: TextStyle(fontSize: 14, fontFamily: 'monospace')));
    return Scaffold(
      appBar: _showAppBar
          ? AppBar(
              title: Text(
                widget.song.title,
                style: TextStyle(fontSize: 20, fontFamily: 'Poppins'),
              ),
            )
          : null,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollUpdateNotification) {
            setState(() {
              _showAppBar = scrollNotification.metrics.pixels <= 0;
            });
          }
          return true;
        },
        child: Padding(
          padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 0.0),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.0),
                Text(
                  'Artist: ${widget.song.artist}',
                  style: TextStyle(fontSize: 14, fontFamily: 'monospace'),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Pitch: ${widget.song.pitch} ',
                  style: TextStyle(fontSize: 14, fontFamily: 'monospace'),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Beat: ${widget.song.beat}',
                  style: TextStyle(fontSize: 14, fontFamily: 'monospace'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: _decrementTranspose,
                    ),
                    Text(
                      '${ChordTransposer.transposeKey(widget.song.pitch, _transposeValue)}',
                      style: TextStyle(fontSize: 15, fontFamily: 'monospace'),
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: _incrementTranspose,
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_downward),
                      onPressed: () {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: Duration(milliseconds: 500000),
                          curve: Curves.bounceIn,
                        );
                      },
                    ),
                  ],
                ),
                Container(
                  alignment: Alignment.bottomCenter,
                  child: _bannerAd != null
                      ? Container(
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        )
                      : SizedBox.shrink(),
                ),
                SizedBox(height: 5.0),
                RichText(
                  text: TextSpan(children: spans),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppInfoDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('App Information',
          style: TextStyle(fontSize: 20, fontFamily: 'Poppins')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/avatar.png',
            width: 100,
            height: 100,
          ),
          Text(
            'App Name: Ez-Chords',
            style: TextStyle(fontSize: 13, fontFamily: 'Poppins'),
          ),
          Text('Version: 1.0.5',
              style: TextStyle(fontSize: 13, fontFamily: 'Poppins')),
          Text('Email: unifaceplus@gmail.com',
              style: TextStyle(fontSize: 13, fontFamily: 'Poppins')),
          Text('Website: https://ezchords.tech',
              style: TextStyle(fontSize: 13, fontFamily: 'Poppins')),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Close'),
        ),
      ],
    );
  }
}

class MyImageWidget extends StatelessWidget {
  final String base64Image;

  const MyImageWidget({Key? key, required this.base64Image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      base64Decode(base64Image),
      fit: BoxFit.cover,
    );
  }
}

class Song {
  final String title;
  final String artist;
  final String pitch;
  final String beat;
  final String img;
  final String lyrics;
  bool favorite;
  bool favorite_artist; // New property

  Song({
    required this.title,
    required this.artist,
    required this.pitch,
    required this.beat,
    required this.img,
    required this.lyrics,
    this.favorite = false,
    this.favorite_artist = false, // Initialize as false by default
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'pitch': pitch,
      'beat': beat,
      'img': img,
      'lyrics': lyrics,
      'favorite': favorite,
      'favorite_artist': favorite_artist,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
        title: map['title'],
        artist: map['artist'],
        pitch: map['pitch'],
        beat: map['beat'],
        img: map['img'],
        lyrics: map['lyrics'],
        favorite: map['favorite'] == 1,
        favorite_artist: map['favorite_artist'] == 1);
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal() {
    _db = null;
  }

  late Database? _db;

  Future<Database> get db async {
    if (_db == null || !_db!.isOpen) {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'my_database.db');
      _db = await openDatabase(path);
    }
    return _db!;
  }
}
