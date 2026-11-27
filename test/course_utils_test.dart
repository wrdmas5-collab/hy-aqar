import 'package:flutter_test/flutter_test.dart';
import 'package:hy_academy/main.dart';

void main() {
  group('YouTube video ID extraction', () {
    test('extracts IDs from watch and short URLs', () {
      expect(extractYoutubeVideoId('https://www.youtube.com/watch?v=abcdefghijk'), 'abcdefghijk');
      expect(extractYoutubeVideoId('https://youtu.be/abcdefghijk'), 'abcdefghijk');
    });

    test('accepts a raw 11-character video ID', () {
      expect(extractYoutubeVideoId('abcdefghijk'), 'abcdefghijk');
    });
  });

  group('PDF URL normalization', () {
    test('converts Google Drive file links to download URLs', () {
      expect(
        normalizePdfUrl('https://drive.google.com/file/d/FILE_ID/view?usp=sharing'),
        'https://drive.google.com/uc?export=download&id=FILE_ID',
      );
    });

    test('leaves non-Google Drive URLs unchanged', () {
      const url = 'https://example.com/file.pdf';
      expect(normalizePdfUrl(url), url);
    });
  });
}
