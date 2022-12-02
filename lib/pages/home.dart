import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static final Completer<YandexMapController> _completer = Completer();
  late final YandexMapController _controller;
  static final List<MapObject> mapObjects = [];
  late final PlacemarkMapObject startPlaceMarks;
  late final PlacemarkMapObject stopPlaceMarks;
  late final Position myPosition;
  late Future<DrivingSessionResult> result;
  bool progress = false;

  @override
  void initState() {
    super.initState();
    _determinePosition().then((value) {
      final boundingBox = BoundingBox(
        northEast: Point(
            latitude: myPosition.latitude, longitude: myPosition.longitude),
        southWest: Point(
            latitude: myPosition.latitude, longitude: myPosition.longitude),
      );
      _controller.moveCamera(CameraUpdate.newTiltAzimuthBounds(boundingBox));
      _controller.moveCamera(CameraUpdate.zoomTo(11));
      _myLocation(Point(latitude: myPosition.latitude, longitude: myPosition.longitude));
    });
  }

  void _onMapCreated(YandexMapController controller) {
    _completer.complete(controller);
    _controller = controller;
    setState(() {});
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Fluttertoast.showToast(msg: 'Please Keep your location on.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        Fluttertoast.showToast(msg: 'Location Permissio is denied ');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Fluttertoast.showToast(msg: 'Permission is dined forever');
    }
    myPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  void _findLocation() {
    final newBoundingBox = BoundingBox(
      northEast:
          Point(latitude: myPosition.latitude, longitude: myPosition.longitude),
      southWest:
          Point(latitude: myPosition.latitude, longitude: myPosition.longitude),
    );
    _controller.moveCamera(CameraUpdate.newTiltAzimuthBounds(newBoundingBox));
    _controller.moveCamera(CameraUpdate.zoomTo(16),
        animation: const MapAnimation(
          type: MapAnimationType.linear,
          duration: 2,
        ),
    );
  }

  void _myLocation(Point point) {
    startPlaceMarks = PlacemarkMapObject(
      mapId: const MapObjectId("start_point"),
      point: point,
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          scale: 0.5,
          image: BitmapDescriptor.fromAssetImage("assets/images/img_3.png"),
        ),
      ),
    );
    setState(() {
      mapObjects.add(startPlaceMarks);
    });
  }

  void _tappedLocation(Point point) {
    stopPlaceMarks = PlacemarkMapObject(
      mapId: const MapObjectId("stop_point"),
      point: point,
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          scale: 0.1,
          image: BitmapDescriptor.fromAssetImage("assets/images/img_2.png"),
        ),
      ),
    );
    setState(() {});
    mapObjects.add(stopPlaceMarks);
    progress = true;
    setState(() {});
  }

  Future<void> _requestRoutes(Point point) async {
    var resultSession = YandexDriving.requestRoutes(
      points: [
        RequestPoint(
          point: startPlaceMarks.point,
          requestPointType: RequestPointType.wayPoint,
        ),
        RequestPoint(
          point: point,
          requestPointType: RequestPointType.wayPoint,
        ),
      ],
      drivingOptions: const DrivingOptions(initialAzimuth: 0, routesCount: 1, avoidTolls: true),
    );
    result = resultSession.result;
    setState(() {});
  }

  Future<void> _handleResult(DrivingSessionResult result) async {
    setState(() {});
    result.routes!.asMap().forEach((i, route) {
      mapObjects.add(PolylineMapObject(
        mapId: MapObjectId('route_${i}_polyline'),
        polyline: Polyline(points: route.geometry),
        strokeColor: Colors.green,
        strokeWidth: 2,
      ));
    });
    setState(() {});
  }

  Future<void> init() async {
    _handleResult(await result).then((value) {
      progress = false;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          YandexMap(
            onMapCreated: _onMapCreated,
            mode2DEnabled: true,
            nightModeEnabled: true,
            mapObjects: mapObjects,
            onMapTap: (value) {
              print(progress);
              _tappedLocation(value);
              _requestRoutes(value);
              init();
            },
          ),
          progress?const Center(
            child: CircularProgressIndicator(),
          ):const SizedBox.shrink(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _findLocation,
            child: const Icon(Icons.location_on_outlined),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              _controller.moveCamera(CameraUpdate.zoomIn());
              print("zoom in");
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              _controller.moveCamera(CameraUpdate.zoomOut());
              print("zoom out");
            },
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () async {
              // await Geolocator.openAppSettings();
              await Geolocator.openLocationSettings();
              print("settings");
            },
            child: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }
}
