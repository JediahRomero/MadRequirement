import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:madlocapp/screens/friendslist.dart';
import 'package:madlocapp/screens/location.dart';
import 'package:madlocapp/screens/login_page.dart';

class HomepageScreen extends StatefulWidget {
  final String userEmail;

  const HomepageScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> {
  static final initialPosition = LatLng(15.9074, 120.7466);
  late GoogleMapController mapController;
  Position? _currentLocation;
  String? userFirstName;
  String? userLastName;
  String? userProfilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _getCurrentLocation();
  }

  Future<void> _loadUserDetails() async {
    try {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(widget.userEmail)
          .get();

      if (userSnapshot.exists) {
        setState(() {
          userFirstName = userSnapshot.get('firstname');
          userLastName = userSnapshot.get('lastname');
        });
      }
    } catch (e) {
      setState(() {
        userFirstName = 'Unknown';
        userLastName = '';
      });
    }
  }

  void _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = position;
      });
    } catch (e) {
      print("Error getting current location: $e");
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPageScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          userFirstName != null && userLastName != null
              ? '$userFirstName $userLastName'
              : widget.userEmail,
          style: GoogleFonts.openSans(
            textStyle: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: Colors.white,
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/logo1.png',
              fit: BoxFit.cover,
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Your Location",
                          style: GoogleFonts.openSans(
                            textStyle: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: GoogleMap(
                            myLocationEnabled: true,
                            initialCameraPosition: CameraPosition(
                              target: initialPosition,
                              zoom: 15,
                            ),
                            onMapCreated: (controller) {
                              mapController = controller;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(Icons.people, "Friends", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FriendsListScreen(
                            currentUserEmail: widget.userEmail,
                            updateFriendsList: () {},
                          ),
                        ),
                      );
                    }),
                    _buildActionButton(Icons.location_on, "My Location", () {
                      if (_currentLocation != null) {
                        mapController.animateCamera(CameraUpdate.newLatLng(
                          LatLng(
                            _currentLocation!.latitude,
                            _currentLocation!.longitude,
                          ),
                        ));
                      }
                    }),
                    _buildActionButton(
                        Icons.share_location_rounded, "Locations", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationsScreen(),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: Colors.blue.shade900,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: GoogleFonts.openSans(
            textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
