import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (kIsWeb) throw Exception('Database not supported on Web');
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'samanyudu_cache.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE news_cache(
            id TEXT PRIMARY KEY,
            title TEXT,
            description TEXT,
            area TEXT,
            type TEXT,
            image_url TEXT,
            video_url TEXT,
            live_link TEXT,
            is_breaking INTEGER,
            timestamp TEXT,
            author TEXT,
            likes INTEGER,
            comments_count INTEGER,
            marriage_details TEXT
          )
        ''');
      },
    );
  }

  Future<void> cacheNews(List<dynamic> newsList) async {
    if (kIsWeb) return;
    final db = await database;
    final batch = db.batch();
    
    // Clear old cache (optional, or you can implement smarter logic)
    batch.delete('news_cache');
    
    for (var news in newsList) {
      batch.insert(
        'news_cache',
        {
          'id': news['id'].toString(),
          'title': news['title'],
          'description': news['description'],
          'area': news['area'],
          'type': news['type'],
          'image_url': news['image_url'],
          'video_url': news['video_url'],
          'live_link': news['live_link'],
          'is_breaking': (news['is_breaking'] == true) ? 1 : 0,
          'timestamp': news['timestamp'],
          'author': news['author'],
          'likes': news['likes'] ?? 0,
          'comments_count': news['comments_count'] ?? 0,
          'marriage_details': news['marriage_details'] != null ? json.encode(news['marriage_details']) : null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<dynamic>> getCachedNews() async {
    if (kIsWeb) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('news_cache', orderBy: 'timestamp DESC');
    
    return maps.map((map) {
      return {
        'id': map['id'],
        'title': map['title'],
        'description': map['description'],
        'area': map['area'],
        'type': map['type'],
        'image_url': map['image_url'],
        'video_url': map['video_url'],
        'live_link': map['live_link'],
        'is_breaking': map['is_breaking'] == 1,
        'timestamp': map['timestamp'],
        'author': map['author'],
        'likes': map['likes'],
        'comments_count': map['comments_count'],
        'marriage_details': map['marriage_details'] != null ? json.decode(map['marriage_details']) : null,
      };
    }).toList();
  }
}
