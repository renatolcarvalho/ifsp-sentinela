// Copyright 2020 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:place_tracker/location.dart';
import 'place.dart';

class FireBaseData {
  static Future<List<Place>> getData() async {
    await Firebase.initializeApp();

    CollectionReference _collectionRef =
        FirebaseFirestore.instance.collection('locations');

    // Get docs from collection reference
    QuerySnapshot querySnapshot = await _collectionRef.get();

    // Get data from docs and convert map to List
    final locations = querySnapshot.docs
        .map((doc) => Location(
            (doc.data() as dynamic)['id'],
            (doc.data() as dynamic)['latLng'].latitude,
            (doc.data() as dynamic)['latLng'].longitude,
            (doc.data() as dynamic)['category'],
            (doc.data() as dynamic)['address']))
        .toList();

    return locations
        .map((e) => new Place(
            id: e.id,
            latLng: new LatLng(e.lat, e.lng),
            category: PlaceCategory.values[e.category],
            address: e.address))
        .toList();
  }

  static Future<void> savaNewPlace(
      LatLng location, int category, String address) async {
    var query = await FirebaseFirestore.instance
        .collection('locations')
        .orderBy("id", descending: true)
        .limit(1)
        .snapshots()
        .first;

    var maxId = query.docs.length > 0 ? query.docs.first.data()["id"] : 0;

    FirebaseFirestore.instance.collection('locations').add({
      "id": ++maxId,
      "category": category,
      "latLng": GeoPoint(location.latitude, location.longitude),
      "address": address
    });
  }
}
