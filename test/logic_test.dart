import 'package:flutter_test/flutter_test.dart';
import 'package:kaffee/format.dart';
import 'package:kaffee/models.dart';

void main() {
  test('Zahlen mit Komma', () {
    expect(parseNum('18,5'), 18.5);
    expect(fmtSmart(25), '25');
    expect(fmtNum(2.5), '2,5');
  });

  test('Ampel', () {
    final t = Targets();
    expect(t.timeLevel(26), Level.ok);
    expect(t.timeLevel(30), Level.near);
    expect(t.timeLevel(15), Level.off);
    expect(t.ratioLevel(45 / 18), Level.ok);
  });

  test('Tipps', () {
    final t = Targets();
    expect(dialInTip(18, 0, 0, t), contains('feiner'));
    expect(dialInTip(35, 0, 0, t), contains('gröber'));
    expect(dialInTip(26, 0, 0, t), isNull);
  });
}
