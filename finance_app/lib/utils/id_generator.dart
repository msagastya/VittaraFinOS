import 'dart:math';

class IdGenerator {
  IdGenerator._();

  static final Random _random = Random();
  // Start from a random offset so sequences from different app sessions don't collide.
  static int _sequence = Random().nextInt(1000000);

  static String next({
    String prefix = 'id',
  }) {
    _sequence = (_sequence + 1) % 1000000;
    final micros = DateTime.now().microsecondsSinceEpoch;
    final entropy = _random.nextInt(1 << 20).toRadixString(16).padLeft(5, '0');
    return '${prefix}_${micros}_$_sequence$entropy';
  }
}
