import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/data/services/connectivity_service.dart';

class FakeConnectivityService implements ConnectivityService {
  final _controller = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _status = ConnectivityStatus.none;

  @override
  Stream<ConnectivityStatus> get onConnectivityChanged => _controller.stream;

  @override
  Future<ConnectivityStatus> checkConnectivity() async => _status;

  void setStatus(ConnectivityStatus status) {
    _status = status;
    _controller.add(status);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  group('ConnectivityService transitions', () {
    test('mobile transition from none to wifi', () async {
      final service = FakeConnectivityService();
      final events = <ConnectivityStatus>[];
      service.onConnectivityChanged.listen(events.add);

      service.setStatus(ConnectivityStatus.none);
      service.setStatus(ConnectivityStatus.wifi);

      expect(events, [ConnectivityStatus.none, ConnectivityStatus.wifi]);
      service.dispose();
    });

    test('web transition offline to online', () async {
      final service = FakeConnectivityService();
      final events = <ConnectivityStatus>[];
      service.onConnectivityChanged.listen(events.add);

      service.setStatus(ConnectivityStatus.none);
      service.setStatus(ConnectivityStatus.wifi);
      service.setStatus(ConnectivityStatus.none);

      expect(events, [
        ConnectivityStatus.none,
        ConnectivityStatus.wifi,
        ConnectivityStatus.none,
      ]);
      service.dispose();
    });
  });
}
