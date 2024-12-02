import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  _LocationsScreenState createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> mySharedLocations = [];
  List<Map<String, dynamic>> friendsSharedLocations = [];
  LatLng? _currentUserLatLng;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLocations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(currentUser.uid)
          .get();

      if (!userSnapshot.exists) return;

      String firstname = userSnapshot['firstname'];
      String lastname = userSnapshot['lastname'];
      String fullName = '$firstname $lastname';

      QuerySnapshot myQuerySnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('sharedBy', isEqualTo: fullName)
          .get();

      List<Map<String, dynamic>> myLocations = myQuerySnapshot.docs.map((doc) {
        GeoPoint geoPoint = GeoPoint(
          double.tryParse(doc['latitude']) ?? 0.0,
          double.tryParse(doc['longitude']) ?? 0.0,
        );

        return {
          'id': doc.id,
          'address': doc['address'] ?? 'Unknown address',
          'timestamp': doc['timestamp'],
          'firstname': doc['firstname'],
          'lastname': doc['lastname'],
          'geoPoint': geoPoint,
        };
      }).toList();

      QuerySnapshot friendsQuerySnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('userID', isEqualTo: currentUser.uid)
          .get();

      List<Map<String, dynamic>> friendsLocations = friendsQuerySnapshot.docs
          .map((doc) => {
                'address': doc['address'] ?? 'Unknown address',
                'timestamp': doc['timestamp'],
                'sharedBy': doc['sharedBy'] ?? 'Unknown User',
                'geoPoint': GeoPoint(
                  double.tryParse(doc['latitude']) ?? 0.0,
                  double.tryParse(doc['longitude']) ?? 0.0,
                ),
              })
          .toList();

      Position currentPosition = await Geolocator.getCurrentPosition();
      _currentUserLatLng = LatLng(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      setState(() {
        mySharedLocations = myLocations;
        friendsSharedLocations = friendsLocations;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load locations: $e')),
      );
    }
  }

  void _stopSharingLocation(String documentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(documentId)
          .delete();

      setState(() {
        mySharedLocations
            .removeWhere((location) => location['id'] == documentId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stopped sharing location.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to stop sharing location.')),
      );
    }
  }

  Widget _buildLocationSection(
      String title, List<Map<String, dynamic>> locations,
      {bool isMyLocation = true}) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: locations.map((location) {
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          elevation: 5.0,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            title: Text(
              location['address'],
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              isMyLocation
                  ? 'Shared with: ${location['firstname']} ${location['lastname']}'
                  : 'Shared by: ${location['sharedBy']}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: isMyLocation
                ? TextButton.icon(
                    onPressed: () => _stopSharingLocation(location['id']),
                    icon: const Icon(Icons.stop_rounded, color: Colors.red),
                    label:
                        const Text('Stop', style: TextStyle(color: Colors.red)),
                  )
                : TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => MapViewScreen(
                            initialPosition: LatLng(
                              location['geoPoint'].latitude,
                              location['geoPoint'].longitude,
                            ),
                            userLatLng: _currentUserLatLng,
                            friendName: location['sharedBy'],
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.location_pin, color: Colors.blue.shade900),
                    label: Text('View',
                        style: TextStyle(color: Colors.blue.shade900)),
                  ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Locations'),
        backgroundColor: Colors.blue.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Your Locations"),
            Tab(text: "Friends' Locations"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLocationSection("Your Shared Locations", mySharedLocations),
          _buildLocationSection(
              "Friends' Shared Locations", friendsSharedLocations,
              isMyLocation: false),
        ],
      ),
    );
  }
}

class MapViewScreen extends StatelessWidget {
  final LatLng initialPosition;
  final LatLng? userLatLng;
  final String friendName;

  const MapViewScreen({
    super.key,
    required this.initialPosition,
    this.userLatLng,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location on Map'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue.shade900,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialPosition,
          zoom: 15.0,
        ),
        markers: {
          Marker(
            markerId: const MarkerId("friendLocation"),
            position: initialPosition,
            infoWindow: InfoWindow(title: friendName),
          ),
          if (userLatLng != null)
            Marker(
              markerId: const MarkerId("yourLocation"),
              position: userLatLng!,
              infoWindow: const InfoWindow(title: 'Your location'),
            ),
        },
      ),
    );
  }
}
