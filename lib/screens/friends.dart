import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:madlocapp/screens/friendslist.dart';

class FriendsScreen extends StatefulWidget {
  final String currentUserEmail;
  final Function updateFriendsList;

  const FriendsScreen({
    Key? key,
    required this.currentUserEmail,
    required this.updateFriendsList,
  }) : super(key: key);

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.people, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FriendsListScreen(
                    currentUserEmail: widget.currentUserEmail,
                    updateFriendsList: widget.updateFriendsList,
                  ),
                ),
              );
            },
          ),
        ],
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Add Friend',
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

          DocumentSnapshot? currentUserDoc;

          try {
            currentUserDoc = allUsers.firstWhere(
              (doc) => doc.get('email') == widget.currentUserEmail,
              orElse: () => throw StateError('Document not found'),
            );
          } catch (e) {
            print('Error finding current user document: $e');
          }

          if (currentUserDoc == null) {
            return Center(child: Text('Current user not found.'));
          }

          List<String> friendsIds =
              List<String>.from(currentUserDoc.get('friends') ?? []);

          List<DocumentSnapshot> suggestedList = allUsers.where((doc) {
            return doc.get('email') != widget.currentUserEmail &&
                !friendsIds.contains(doc.id);
          }).toList();

          if (suggestedList.isEmpty) {
            return Center(child: Text('No suggested friends available.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Suggested Friends:',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 20),
              ...suggestedList.map((doc) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      title: Text(
                        '${doc.get('firstname')} ${doc.get('lastname')}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: GestureDetector(
                        onTap: () => addFriend(doc),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Add Friend',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  void addFriend(DocumentSnapshot user) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('Error: User not authenticated.');
      return;
    }

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
        'friends': FieldValue.arrayUnion([user.id])
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${user.get('firstname')} ${user.get('lastname')} added as a friend.'),
        ),
      );
      widget.updateFriendsList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to add ${user.get('firstname')} ${user.get('lastname')} as a friend: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error adding friend: $e');
    }
  }
}
