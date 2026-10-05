import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/services/api_result.dart';

void main() {
  test('galat server dikenali dari statusCode >= 400', () {
    expect(apiFailed({'statusCode': 409, 'message': 'Pelayanan ini sudah diterima oleh Romo lain.'}), isTrue);
    expect(apiFailed({'statusCode': 403}), isTrue);
    expect(apiFailed({'statusCode': 500}), isTrue);
  });

  test('keberhasilan tidak dianggap galat', () {
    expect(apiFailed({'message': 'Order ID 5 status diperbarui menjadi CONFIRMED', 'status': 'CONFIRMED'}), isFalse);
    expect(apiFailed({'statusCode': 200, 'message': 'ok'}), isFalse);
    expect(apiFailed({}), isFalse);
  });

  test('pesan: teks, daftar, atau cadangan', () {
    expect(apiMessage({'message': 'Gagal'}, 'x'), 'Gagal');
    expect(apiMessage({'message': ['a', 'b']}, 'x'), 'a\nb');
    expect(apiMessage({}, 'cadangan'), 'cadangan');
    expect(apiMessage({'message': '  '}, 'cadangan'), 'cadangan');
  });
}
