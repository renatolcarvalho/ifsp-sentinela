// Copyright 2020 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:google_maps_flutter/google_maps_flutter.dart';

class Place {
  final int id;
  final LatLng latLng;
  final PlaceCategory category;
  final String address;

  const Place(
      {required this.id,
      required this.latLng,
      required this.category,
      required this.address});

  double get latitude => latLng.latitude;
  double get longitude => latLng.longitude;

  Place copyWith({
    String? id,
    LatLng? latLng,
    String? name,
    PlaceCategory? category,
    String? description,
    String? address,
    int? starRating,
  }) {
    return Place(
        id: this.id,
        latLng: latLng ?? this.latLng,
        category: category ?? this.category,
        address: address ?? this.address);
  }
}

enum PlaceCategory { thief, death, kidnapping, all }
