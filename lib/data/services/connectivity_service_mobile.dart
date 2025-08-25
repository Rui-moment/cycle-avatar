import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'connectivity_service.dart';

class ConnectivityServiceImpl implements ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();
  late final StreamSubscription<ConnectivityResult> _subscription;

  ConnectivityServiceImpl() {
    _subscription =
        _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _controller.add(_mapResult(result));
    });
  }

  @override
  Stream<ConnectivityStatus> get onConnectivityChanged => _controller.stream;

  @override
  Future<ConnectivityStatus> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return _mapResult(result);
  }

  ConnectivityStatus _mapResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return ConnectivityStatus.wifi;
      case ConnectivityResult.mobile:
        return ConnectivityStatus.mobile;
      case ConnectivityResult.ethernet:
        return ConnectivityStatus.ethernet;
      default:
        return ConnectivityStatus.none;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _controller.close();
  }
}
