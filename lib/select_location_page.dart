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

  static const _default = LatLng(13.7563, 100.5018);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await Geolocator.getCurrentPosition();
    final here = LatLng(pos.latitude, pos.longitude);
    setState(() => _picked = here);
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
            onMapCreated: (c) => _controller = c,
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
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: ElevatedButton(
              child: const Text('ใช้ตำแหน่งนี้'),
              onPressed: () {
                Navigator.pop(context, {
                  'lat': _picked!.latitude,
                  'lng': _picked!.longitude,
                  'address': _address,
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
