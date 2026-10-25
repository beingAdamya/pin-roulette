import 'package:flutter_test/flutter_test.dart';
import 'package:pin_roulette/importer.dart';

void main() {
  test('reads every stop from a directions link', () {
    expect(
      namesFromMapsUrl('https://www.google.com/maps/dir/Flurys,+Park+Street/'
          'Victoria+Memorial/@22.55,88.35,14z/data=!4m2'),
      ['Flurys, Park Street', 'Victoria Memorial'],
    );
  });

  test('reads a single place link', () {
    expect(
      namesFromMapsUrl(
          'https://www.google.com/maps/place/Prinsep+Ghat/@22.56,88.33,17z'),
      ['Prinsep Ghat'],
    );
  });

  test('finds the id of a shared list', () {
    expect(
      listIdFrom('https://www.google.com/maps/@22.5,88.3,12z/data=!4m3!11m2!2sAbC_12-xyz!3e3'),
      'AbC_12-xyz',
    );
  });

  test('reads a Google Takeout list file', () {
    const csv = '﻿Title,Note,URL,Comment\r\n'
        '"Flurys, Park Street",,https://www.google.com/maps/place/Flurys/data=x,\r\n'
        ',,https://www.google.com/maps/place/Victoria+Memorial/data=y,\r\n';
    expect(namesFromFile(csv, 'Want to go.csv'),
        ['Flurys, Park Street', 'Victoria Memorial']);
  });

  test('plain names, one per line', () async {
    final r = await importText('Kumartuli\nEco Park');
    expect(r.names, ['Kumartuli', 'Eco Park']);
  });
}
