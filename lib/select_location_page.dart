import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as g;

class SelectLocationPage extends StatefulWidget {
  const SelectLocationPage({super.key});

  @override
  State<SelectLocationPage> createState() => _SelectLocationPageState();
}

class _SelectLocationPageState extends State<SelectLocationPage> {
  GoogleMapController? _controller;
  LatLng? _picked;
  String? _address;
  double _currentZoom = 14;

  final TextEditingController _searchController = TextEditingController();

  static const _default = LatLng(13.7563, 100.5018);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    final here = LatLng(pos.latitude, pos.longitude);

    setState(() => _picked = here);

    _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(here, 16),
    );

    _reverseGeocode(here);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    final list =
        await g.placemarkFromCoordinates(pos.latitude, pos.longitude);

    if (list.isNotEmpty) {
      final p = list.first;
      setState(() {
        _address =
            '${p.street ?? ''} ${p.locality ?? ''} ${p.administrativeArea ?? ''}';
      });
    }
  }

  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;

    final locations = await g.locationFromAddress(query);
    if (locations.isNotEmpty) {
      final loc = locations.first;
      final newPos = LatLng(loc.latitude, loc.longitude);

      setState(() => _picked = newPos);

      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(newPos, 16),
      );

      _reverseGeocode(newPos);
    }
  }

  void _zoomIn() {
    _currentZoom++;
    _controller?.animateCamera(
      CameraUpdate.zoomTo(_currentZoom),
    );
  }

  void _zoomOut() {
    _currentZoom--;
    _controller?.animateCamera(
      CameraUpdate.zoomTo(_currentZoom),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เลือกตำแหน่งจัดส่ง')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                const CameraPosition(target: _default, zoom: 14),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (c) => _controller = c,
            onCameraMove: (position) {
              _currentZoom = position.zoom;
            },
            markers: _picked == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _picked!,
                      draggable: true,
                      onDragEnd: (p) {
                        setState(() => _picked = p);
                        _reverseGeocode(p);
                      },
                    ),
                  },
            onTap: (p) {
              setState(() => _picked = p);
              _reverseGeocode(p);
            },
          ),

          // 🔍 SEARCH BOX
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ค้นหาสถานที่...',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () =>
                        _searchPlace(_searchController.text),
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: _searchPlace,
              ),
            ),
          ),

          // 🔎 ZOOM BUTTONS (ขวาล่าง)
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // ✅ ปุ่มยืนยัน
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: ElevatedButton(
              onPressed: _picked == null
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'lat': _picked!.latitude,
                        'lng': _picked!.longitude,
                        'address': _address,
                      });
                    },
              child: const Text('ใช้ตำแหน่งนี้'),
            ),
          ),
        ],
      ),
    );
  }
}
