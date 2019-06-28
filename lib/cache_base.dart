library flutter_image_cache;

import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'dart:core';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImageCache extends CacheBase {
  ImageCache._(Duration cacheDuration, int retryCount)
      : super('ImageCache', cacheDuration, retryCount);

  static ImageCache instance = ImageCache._(Duration(days: 1), 1);

  @override
  bool isFileOutOfDate(FileStat fileStat, DateTime expirationTimestamp) {
    //print('Check if file last accessed is older than cache duration');
    return fileStat.accessed.compareTo(expirationTimestamp) <= 0;
  }
}

abstract class CacheBase {
  CacheBase(this.cacheName, this.cacheDuration, this.retryCount) {
    initialise();
  }

  String _baseDirectory;
  String _cacheDirectory;

  final Duration cacheDuration;
  final int retryCount;
  final String cacheName;

  final _concurrentFutures = HashMap<String, _ConcurrentRequest>();
  final _httpClient = http.Client();

  DownloadService _downloadService;

  Future<void> initialise() async {
    final appTempDir = await getTemporaryDirectory();

    _baseDirectory = appTempDir.path;
    _cacheDirectory = '$_baseDirectory/$cacheName';

    _downloadService = await DownloadService.create();

    await this._clearExpired();
  }

  // Future clear() async {
  //   final fileEntries = _cacheDirectory.list();

  //   fileEntries.listen((fileEntry) async {
  //     await fileEntry.delete();
  //   });
  // }

  Future _clearExpired() async {
    final fileEntries = Directory(_cacheDirectory).list();
    final expirationTimestamp = DateTime.now().subtract(cacheDuration);

    fileEntries.listen((fileEntry) async {
      final fileStat = await fileEntry.stat();
      if (isFileOutOfDate(fileStat, expirationTimestamp)) {
        await fileEntry.delete();
      }
    });
  }

  bool isFileOutOfDate(FileStat fileStat, DateTime expirationTimestamp) {
    return fileStat.modified.compareTo(expirationTimestamp) <= 0;
  }

  String _getFileName(String url) {
    return _createHash(url).toString();
  }

  Digest _createHash(String str) {
    final bytes = utf8.encode(str); // data being hashed

    return sha1.convert(bytes);
  }

  Future preCache(String url) async {
    try {
      await _getItem(url);
    } catch (Exception) {}
  }

  Future<File> getFromCache(String url) {
    return _getItem(url);
  }

  Future<File> _getItem(String url) async {
    final fileName = _getFileName(url);

    _ConcurrentRequest request = _concurrentFutures[fileName];

    if (request == null) {
      request = _ConcurrentRequest(_getFromCacheOrDownload(url, fileName));
      _concurrentFutures[fileName] = request;
    }

    final file = await request.future;

    _concurrentFutures.remove(fileName);

    return file;
  }

  Future<File> _getFromCacheOrDownload(String url, String fileName) async {
    final filePath = '$_cacheDirectory/$fileName';
    final file = File(filePath);
    final expirationTimestamp = DateTime.now().subtract(cacheDuration);

    bool cachedCopyExists = await file.exists();

    if (cachedCopyExists) {
      final fileStat = await file.stat();

      if (isFileOutOfDate(fileStat, expirationTimestamp)) {
        await file.delete();

        cachedCopyExists = false;
      } else {
        print('Cached copy exists for $url $filePath');
        return file;
      }
    }

    if (!cachedCopyExists) {
      _downloadService.sendRequest(DownloadRequest(url, filePath));
    }

    return file;
  }
}

class DownloadService {
  DownloadService._(this._isolate, this._sendPort);

  static Future<DownloadService> create() async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _run,
      receivePort.sendPort,
      debugName: 'ImageDownloader',
    );
    return DownloadService._(isolate, await receivePort.first);
  }

  final Isolate _isolate;
  final SendPort _sendPort;
  bool _disposed = false;

  static void _run(SendPort callerSendPort) {
    final receivePort = ReceivePort();
    callerSendPort.send(receivePort.sendPort);
    receivePort.listen((message) {
      DownloaderRemote.downloadImage(message.url, message.filePath);
    });
  }

  void sendRequest(DownloadRequest message) {
    if (_disposed) {
      return;
    }
    _sendPort.send(message);
  }

  void dispose() {
    if (!_disposed) {
      _isolate.kill(priority: Isolate.immediate);
      _disposed = true;
    }
  }
}

class DownloadRequest {
  final String url;
  final String filePath;

  DownloadRequest(this.url, this.filePath);
}

class DownloaderRemote {
  static final _httpClient = http.Client();
  static Future<void> downloadImage(String url, String fileName) async {
    final response = await _httpClient.get(url);
    if (response.statusCode == 200) {
      File file = File(fileName);
      await file.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
    }

    print('Downloaded $url $fileName');
  }
}

class _ConcurrentRequest {
  _ConcurrentRequest(this.future);
  Future<File> future;
}
