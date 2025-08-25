import 'connectivity_service_mobile.dart'
    if (dart.library.html) 'connectivity_service_web.dart';

enum ConnectivityStatus { none, wifi, mobile, ethernet }

abstract class ConnectivityService {
  Stream<ConnectivityStatus> get onConnectivityChanged;
  Future<ConnectivityStatus> checkConnectivity();
  void dispose();
}

ConnectivityService createConnectivityService() => ConnectivityServiceImpl();
