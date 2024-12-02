import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:madlocapp/screens/friends.dart';
import 'package:madlocapp/screens/location.dart';

class FriendsListScreen extends StatefulWidget {
  final String currentUserEmail;
  final Function updateFriendsList;

  const FriendsListScreen({
    Key? key,
    required this.currentUserEmail,
    required this.updateFriendsList,
  }) : super(key: key);

  @override
  _FriendsListScreenState createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  List<Map<String, String>> friendsList = [];

  @override
  void initState() {
    super.initState();
    checkCurrentUserDoc();
    loadFriendsFirestore();
  }

  void loadFriendsFirestore() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .where('email', isEqualTo: widget.currentUserEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot userDocument = querySnapshot.docs.first;
        List<String> friendsIds =
            List<String>.from(userDocument.get('friends') ?? []);

        List<Map<String, String>> tempFriends = [];

        await Future.forEach(friendsIds, (friendID) async {
          DocumentSnapshot friendSnapshot = await FirebaseFirestore.instance
              .collection('accounts')
              .doc(friendID)
              .get();

          if (friendSnapshot.exists) {
            String firstname = friendSnapshot.get('firstname') ?? '';
            String lastname = friendSnapshot.get('lastname') ?? '';

            tempFriends.add({
              'name': '$firstname $lastname',
              'userID': friendID,
            });
          }
        });

        setState(() {
          friendsList = tempFriends;
        });
      } else {
        print('User document not found for email: ${widget.currentUserEmail}');
      }
    } catch (e) {
      print('Failed to load friend list: $e');
    }
  }

  void checkCurrentUserDoc() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('Current user not authenticated.');
      return;
    }

    DocumentSnapshot currentUserSnapshot = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(currentUser.uid)
        .get();

    if (!currentUserSnapshot.exists) {
      print('Current user document not found.');
    } else {
      print('Current user document exists.');
    }
  }

  void shareLocationWithFriend(String userID) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Current user not authenticated.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Current user not authenticated.')),
        );
        return;
      }

      DocumentSnapshot currentUserSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(currentUser.uid)
          .get();

      if (!currentUserSnapshot.exists) {
        print('Current user document not found.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Current user document not found.')),
        );
        return;
      }

      String sharedByName =
          (currentUserSnapshot.get('firstname') as String? ?? 'Unknown') +
              ' ' +
              (currentUserSnapshot.get('lastname') as String? ?? '');

      DocumentSnapshot friendSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(userID)
          .get();

      if (!friendSnapshot.exists) {
        print('Friend details not found for userID: $userID');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend details not found.')),
        );
        return;
      }

      String? firstname = friendSnapshot.get('firstname') as String?;
      String? lastname = friendSnapshot.get('lastname') as String?;

      if (firstname == null || lastname == null) {
        print(
            'Friend document does not contain required fields: firstname or lastname');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend details are incomplete.')),
        );
        return;
      }

      Position position = await _determinePosition();
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      List<Placemark> placemarks = await placemarkFromCoordinates(
          currentLatLng.latitude, currentLatLng.longitude);
      String address = placemarks.isNotEmpty
          ? placemarks.first.name ?? 'Unknown address'
          : 'Unknown address';

      CollectionReference sharedLocations =
          FirebaseFirestore.instance.collection('locations');

      sharedLocations.add({
        'address': address,
        'isSharing': true,
        'latitude': currentLatLng.latitude.toString(),
        'longitude': currentLatLng.longitude.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'userID': userID,
        'firstname': firstname,
        'lastname': lastname,
        'sharedBy': sharedByName,
      }).then((value) {
        print('Location shared with $firstname $lastname');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location shared to $firstname $lastname')),
        );
      }).catchError((error) {
        print('Failed to share location: $error');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to share location')));
      });
    } catch (e) {
      print('Error sharing location with friend: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share location')),
      );
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }

  void removeFriend(DocumentSnapshot user) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .where('userID', isEqualTo: currentUser.uid)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('Error: User document not found for UID: ${currentUser.uid}');
        return;
      }

      DocumentReference currentUserDocRef = querySnapshot.docs.first.reference;

      await currentUserDocRef.update({
        'friends': FieldValue.arrayRemove([user.id])
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${user.get('firstname')} ${user.get('lastname')} removed from friends.'),
        ),
      );
      widget.updateFriendsList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to remove ${user.get('firstname')} ${user.get('lastname')} from friends.'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error removing friend: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: Icon(Icons.location_on),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LocationsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person_add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FriendsScreen(
                    currentUserEmail: widget.currentUserEmail,
                    updateFriendsList: widget.updateFriendsList,
                  ),
                ),
              );
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withOpacity(0.7),
              ),
            ),
          ),
        ),
        title: Text(
          'Friends List',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('accounts').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No data available.'));
          }

          List<DocumentSnapshot> allUsers = snapshot.data!.docs;

          DocumentSnapshot? currentUserDoc = allUsers.firstWhere(
            (userDoc) => userDoc['email'] == widget.currentUserEmail,
          );

          if (currentUserDoc == null) {
            return Center(child: Text('Current user not found.'));
          }

          List<String> friendIds =
              List<String>.from(currentUserDoc['friends'] ?? []);

          List<DocumentSnapshot> friendDocs = allUsers
              .where((userDoc) => friendIds.contains(userDoc['userID']))
              .toList();

          return ListView.builder(
            itemCount: friendDocs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot friend = friendDocs[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade900,
                    child: Text(
                      '${friend['firstname'][0]}${friend['lastname'][0]}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                      '${friend.get('firstname')} ${friend.get('lastname')}'),
                  subtitle: Text(friend.get('email')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.share_location,
                          color: Colors.blue.shade900,
                        ),
                        onPressed: () {
                          shareLocationWithFriend(friend.id);
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          removeFriend(friend);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
