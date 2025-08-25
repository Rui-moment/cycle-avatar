import 'dart:async';
import 'dart:html' as html;
import 'connectivity_service.dart';

class ConnectivityServiceImpl implements ConnectivityService {
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  ConnectivityServiceImpl() {
    html.window.onOnline.listen((event) {
      _controller.add(ConnectivityStatus.wifi);
    });
    html.window.onOffline.listen((event) {
      _controller.add(ConnectivityStatus.none);
    });
  }

  @override
  Stream<ConnectivityStatus> get onConnectivityChanged => _controller.stream;

  @override
  Future<ConnectivityStatus> checkConnectivity() async {
    return html.window.navigator.onLine
        ? ConnectivityStatus.wifi
        : ConnectivityStatus.none;
  }

  @override
  void dispose() {
    _controller.close();
  }
}
