import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:mysql1/mysql1.dart' as mysql;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_static/shelf_static.dart';

void main() async {
  final settings = mysql.ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: null,
    db: 'movie_app',
  );

  final connection = await mysql.MySqlConnection.connect(settings);

  final router = Router();

  // Get all movies
  router.get('/movies', (Request request) async {
    var results = await connection.query('SELECT * FROM movies');
    var movies = [];
    for (var row in results) {
      movies.add({
        'ID': row['ID']?.toString(),
        'title': row['title']?.toString(),
        'genre': row['genre']?.toString(),
        'rating': row['rating']?.toString(),
        'posterURL': row['posterURL']?.toString(),
        'description': row['description']?.toString(),
      });
    }
    return Response.ok(jsonEncode(movies),
        headers: {'Content-Type': 'application/json'});
  });
  router.post('/movies', (Request request) async {
    try {
      // خواندن بدنه درخواست
      var payload = await request.readAsString();
      var movie = jsonDecode(payload);

      // انجام query برای اضافه کردن فیلم به پایگاه داده
      await connection.query(
        'INSERT INTO Movies (title, genre, rating, posterURL, description) VALUES (?, ?, ?, ?, ?)',
        [
          movie['title'],
          movie['genre'],
          movie['rating'],
          movie['posterURL'],
          movie['description'],
        ],
      );

      // برگرداندن پاسخ موفقیت‌آمیز
      return Response.ok(
        jsonEncode({'message': 'Movie added'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      // در صورت بروز خطا
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });
  final staticHandler = createStaticHandler(
    'public',
    defaultDocument: 'index.html',
  );

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(
        Cascade().add(staticHandler).add(router).handler,
      );

  final server = await io.serve(handler, 'localhost', 8080);
  print('Server listening on http://localhost:${server.port}');
}
