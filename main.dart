import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const MusicDownloaderHome(),
    );
  }
}

class MusicDownloaderHome extends StatefulWidget {
  const MusicDownloaderHome({super.key});
  @override
  State<MusicDownloaderHome> createState() => _MusicDownloaderHomeState();
}

class _MusicDownloaderHomeState extends State<MusicDownloaderHome> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final yt = YoutubeExplode();
  
  List<Video> _searchResults = [];
  List<FileSystemEntity> _offlineSongs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOfflineSongs();
  }

  Future<void> _searchSong(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final searchList = await yt.search.search(query);
      setState(() => _searchResults = searchList.toList());
    } catch (e) {
      _showSnackbar("Search failed: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadSong(Video video) async {
    _showSnackbar("Downloading: ${video.title}...");
    try {
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      
      final dir = await getApplicationDocumentsDirectory();
      final cleanTitle = video.title.replaceAll(RegExp(r'[^\w\s]+'), '');
      final file = File('${dir.path}/$cleanTitle.mp3');
      
      final stream = yt.videos.streamsClient.get(audioStream);
      final fileStream = file.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      _showSnackbar("Download Complete!");
      _loadOfflineSongs();
    } catch (e) {
      _showSnackbar("Download failed: $e");
    }
  }

  Future<void> _loadOfflineSongs() async {
    final dir = await getApplicationDocumentsDirectory();
    setState(() {
      _offlineSongs = dir.listSync().where((item) => item.path.endsWith('.mp3')).toList();
    });
  }

  void _playLocalFile(String path) async {
    try {
      await _audioPlayer.setFilePath(path);
      _audioPlayer.play();
      _showSnackbar("Playing offline song");
    } catch (e) {
      _showSnackbar("Playback error: $e");
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    yt.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Offline YouTube Music Player"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.search), text: "Search Online"),
              Tab(icon: Icon(Icons.download_done), text: "My Offline Music"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Enter song name or artist...",
                      prefixIcon: const Icon(Icons.music_note),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _searchSong(_searchController.text),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (value) => _searchSong(value),
                  ),
                ),
                if (_isLoading) const LinearProgressIndicator(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, i) {
                      final video = _searchResults[i];
                      return ListTile(
                        leading: Image.network(video.thumbnails.lowResUrl),
                        title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(video.author),
                        trailing: IconButton(
                          icon: const Icon(Icons.file_download, color: Colors.green),
                          onPressed: () => _downloadSong(video),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
            _offlineSongs.isEmpty
                ? const Center(child: Text("No downloaded songs yet!"))
                : ListView.builder(
                    itemCount: _offlineSongs.length,
                    itemBuilder: (context, i) {
                      final file = _offlineSongs[i];
                      final fileName = file.path.split('/').last.replaceAll('.mp3', '');
                      return ListTile(
                        leading: const Icon(Icons.audiotrack, color: Colors.blue),
                        title: Text(fileName),
                        trailing: const Icon(Icons.play_arrow, color: Colors.blue),
                        onTap: () => _playLocalFile(file.path),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
