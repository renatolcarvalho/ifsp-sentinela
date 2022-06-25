// Copyright 2020 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
// import 'package:uuid/uuid.dart';

import 'place.dart';
import 'place_tracker_app.dart';

import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:google_maps_webservice/places.dart';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'firebase_data.dart';

class MapConfiguration {
  final List<Place> places;

  final PlaceCategory selectedCategory;

  const MapConfiguration({
    required this.places,
    required this.selectedCategory,
  });

  @override
  int get hashCode => places.hashCode ^ selectedCategory.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is MapConfiguration &&
        other.places == places &&
        other.selectedCategory == selectedCategory;
  }

  static MapConfiguration of(AppState appState) {
    return MapConfiguration(
      places: appState.places,
      selectedCategory: appState.selectedCategory,
    );
  }
}

class PlaceMap extends StatefulWidget {
  final LatLng? center;

  const PlaceMap({
    Key? key,
    this.center,
  }) : super(key: key);

  @override
  PlaceMapState createState() => PlaceMapState();
}

class PlaceMapState extends State<PlaceMap> {
  Completer<GoogleMapController> mapController = Completer();

  MapType _currentMapType = MapType.normal;

  LatLng? _lastMapPosition;

  final Map<Marker, Place> _markedPlaces = <Marker, Place>{};

  final Set<Marker> _markers = {};

  Marker? _pendingMarker;

  MapConfiguration? _configuration;

  @override
  Widget build(BuildContext context) {
    _maybeUpdateMapConfiguration();
    var state = Provider.of<AppState>(context);
    String location = "Procurar Localização";
    String googleApikey = "your-token-here";

    return Builder(builder: (context) {
      // We need this additional builder here so that we can pass its context to
      // _AddPlaceButtonBar's onSavePressed callback. This callback shows a
      // SnackBar and to do this, we need a build context that has Scaffold as
      // an ancestor.
      return Center(
        child: Stack(
          children: [
            Container(
                child: GoogleMap(
              onMapCreated: onMapCreated,
              initialCameraPosition: CameraPosition(
                target: widget.center!,
                zoom: 0,
              ),
              mapType: _currentMapType,
              markers: _markers,
              onCameraMove: (position) => _lastMapPosition = position.target,
            )),
            Positioned(
                //search input bar
                top: 10,
                child: InkWell(
                    onTap: () async {
                      var place = await PlacesAutocomplete.show(
                          context: context,
                          apiKey: googleApikey,
                          mode: Mode.fullscreen,
                          types: [],
                          strictbounds: false,
                          // components: [Component(Component.country, 'np')],
                          onError: (err) {
                            print(err);
                          });

                      if (place != null) {
                        setState(() {
                          location = place.description.toString();
                        });

                        //form google_maps_webservice package
                        final plist = GoogleMapsPlaces(
                          apiKey: googleApikey,
                          apiHeaders: await GoogleApiHeaders().getHeaders(),
                          //from google_api_headers package
                        );

                        String placeid = place.placeId ?? "0";
                        final detail = await plist.getDetailsByPlaceId(placeid);

                        final geometry = detail.result.geometry!;
                        final lat = geometry.location.lat;
                        final lang = geometry.location.lng;
                        var newlatlang = LatLng(lat, lang);

                        //move map camera to selected place with animation
                        var controller = await mapController.future;
                        controller.animateCamera(CameraUpdate.newCameraPosition(
                            CameraPosition(target: newlatlang, zoom: 17)));
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.all(15),
                      child: Card(
                        child: Container(
                            padding: EdgeInsets.all(0),
                            width: MediaQuery.of(context).size.width - 100,
                            child: ListTile(
                              title: Text(
                                location,
                                style: TextStyle(fontSize: 18),
                              ),
                              trailing: Icon(Icons.search),
                              dense: true,
                            )),
                      ),
                    ))),
            _CategoryButtonBar(
              selectedPlaceCategory: state.selectedCategory,
              visible: _pendingMarker == null,
              onChanged: _switchSelectedCategory,
            ),
            _AddPlaceButtonBar(
              visible: _pendingMarker != null,
              onSavePressed: () => _confirmAddPlace(context),
              onCancelPressed: _cancelAddPlace,
            ),
            _MapFabs(
              visible: _pendingMarker == null,
              onAddPlacePressed: _onAddPlacePressed,
              onToggleMapTypePressed: _onToggleMapTypePressed,
            ),
          ],
        ),
      );
    });
  }

  //https://www.fluttercampus.com/guide/254/google-map-autocomplete-place-search-flutter/

  Future<void> onMapCreated(GoogleMapController controller) async {
    mapController.complete(controller);

    // var position = await _determinePosition();
    // _lastMapPosition = LatLng(position.latitude, position.longitude);

    Provider.of<AppState>(context, listen: false).places =
        await FireBaseData.getData();

    // Draw initial place markers on creation so that we have something
    // interesting to look at.
    var markers = <Marker>{};
    for (var place in Provider.of<AppState>(context, listen: false).places) {
      markers.add(await _createPlaceMarker(context, place));
    }
    setState(() {
      _markers.addAll(markers);
    });

    // Zoom to fit the initially selected category.
    //_zoomToFitSelectedCategory();
    _zoomToCurrentPosition();
  }

  void _zoomToCurrentPosition() async {
    var position = await _determinePosition();
    var controller = await mapController.future;

    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude), 20),
    );
  }

  @override
  void didUpdateWidget(PlaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Zoom to fit the selected category.
    // if (mounted) {
    //   _zoomToFitSelectedCategory();
    // }
  }

  /// Applies zoom to fit the places of the selected category
  // void _zoomToFitSelectedCategory() {
  //   _zoomToFitPlaces(
  //     _getPlacesForCategory(
  //       Provider.of<AppState>(context, listen: false).selectedCategory,
  //       _markedPlaces.values.toList(),
  //     ),
  //   );
  // }

  void _cancelAddPlace() {
    if (_pendingMarker != null) {
      setState(() {
        _markers.remove(_pendingMarker);
        _pendingMarker = null;
      });
    }
  }

  Future<String> GetAddressFromLatLong(LatLng location) async {
    List<Placemark> placemarks =
        await placemarkFromCoordinates(location.latitude, location.longitude);

    if (placemarks.length == 0) return "";

    var country = placemarks[0].country ?? "-";
    var city = placemarks[0].subAdministrativeArea ?? "-";
    var state = placemarks[0].administrativeArea ?? "-";
    var address = placemarks[0].street ?? "-";

    return "${address}, ${city}, ${state}, ${country}";
  }

  Future<void> _confirmAddPlace(BuildContext context) async {
    if (_pendingMarker != null) {
      // Create a new Place and map it to the marker we just added.
      final newPlace = Place(
          id: 0,
          latLng: _pendingMarker!.position,
          category:
              Provider.of<AppState>(context, listen: false).selectedCategory,
          address: await GetAddressFromLatLong(_pendingMarker!.position));

      var placeMarker = await _getPlaceMarkerIcon(context,
          Provider.of<AppState>(context, listen: false).selectedCategory);

      setState(() {
        final updatedMarker = _pendingMarker!.copyWith(
          iconParam: placeMarker,
          infoWindowParam: InfoWindow(
            title: 'Novo lugar',
            snippet: null,
            // onTap: () => _pushPlaceDetailsScreen(newPlace),
          ),
          draggableParam: false,
        );

        _updateMarker(
          marker: _pendingMarker,
          updatedMarker: updatedMarker,
          place: newPlace,
        );

        _pendingMarker = null;
      });

      // Show a confirmation snackbar that has an action to edit the new place.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            duration: const Duration(seconds: 3),
            content: const Text('Obrigado pela sua ajuda! :).',
                style: TextStyle(fontSize: 16.0))
            // action: SnackBarAction(
            //   label: 'Edit',
            //   onPressed: () async {
            //     // _pushPlaceDetailsScreen(newPlace);
            //   },
            // ),
            ),
      );

      // Add the new place to the places stored in appState.
      final newPlaces =
          List<Place>.from(Provider.of<AppState>(context, listen: false).places)
            ..add(newPlace);

      await FireBaseData.savaNewPlace(
          newPlace.latLng, newPlace.category.index, newPlace.address);

      Provider.of<AppState>(context, listen: false).places = newPlaces;

      // Manually update our map configuration here since our map is already
      // updated with the new marker. Otherwise, the map would be reconfigured
      // in the main build method due to a modified AppState.
      _configuration = MapConfiguration(
        places: newPlaces,
        selectedCategory:
            Provider.of<AppState>(context, listen: false).selectedCategory,
      );

      Provider.of<AppState>(context, listen: false).setPlaces(newPlaces);
    }
  }

  Future<Marker> _createPlaceMarker(BuildContext context, Place place) async {
    final marker = Marker(
      markerId: MarkerId(place.latLng.toString()),
      position: place.latLng,
      // infoWindow: InfoWindow(
      //   title: place.name,
      //   snippet: '${place.starRating} Star Rating',
      //   onTap: () => _pushPlaceDetailsScreen(place),
      // ),
      icon: await _getPlaceMarkerIcon(context, place.category),
      visible: place.category ==
          Provider.of<AppState>(context, listen: false).selectedCategory,
    );
    _markedPlaces[marker] = place;
    return marker;
  }

  Future<void> _maybeUpdateMapConfiguration() async {
    _configuration ??=
        MapConfiguration.of(Provider.of<AppState>(context, listen: false));
    final newConfiguration =
        MapConfiguration.of(Provider.of<AppState>(context, listen: false));

    // Since we manually update [_configuration] when place or selectedCategory
    // changes come from the [place_map], we should only enter this if statement
    // when returning to the [place_map] after changes have been made from
    // [place_list].
    if (_configuration != newConfiguration) {
      if (_configuration!.places == newConfiguration.places &&
          _configuration!.selectedCategory !=
              newConfiguration.selectedCategory) {
        // If the configuration change is only a category change, just update
        // the marker visibilities.
        await _showPlacesForSelectedCategory(newConfiguration.selectedCategory);
      } else {
        // At this point, we know the places have been updated from the list
        // view. We need to reconfigure the map to respect the updates.
        newConfiguration.places
            .where((p) => !_configuration!.places.contains(p))
            .map((value) => _updateExistingPlaceMarker(place: value));

        // await _zoomToFitPlaces(
        //   _getPlacesForCategory(
        //     newConfiguration.selectedCategory,
        //     newConfiguration.places,
        //   ),
        // );
      }
      _configuration = newConfiguration;
    }
  }

  Future<void> _onAddPlacePressed() async {
    setState(() {
      final newMarker = Marker(
          markerId: MarkerId(_lastMapPosition.toString()),
          position: _lastMapPosition!,
          // infoWindow: const InfoWindow(title: 'New Place'),
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onDragEnd: _onMarkerDragEnd);
      _markers.add(newMarker);
      _pendingMarker = newMarker;
    });
  }

  void _onMarkerDragEnd(LatLng newMarkPosition) {
    _pendingMarker = _pendingMarker!.copyWith(positionParam: newMarkPosition);
  }

  // void _onPlaceChanged(Place value) {
  //   // Replace the place with the modified version.
  //   final newPlaces =
  //       List<Place>.from(Provider.of<AppState>(context, listen: false).places);
  //   final index = newPlaces.indexWhere((place) => place.id == value.id);
  //   newPlaces[index] = value;

  //   _updateExistingPlaceMarker(place: value);

  //   // Manually update our map configuration here since our map is already
  //   // updated with the new marker. Otherwise, the map would be reconfigured
  //   // in the main build method due to a modified AppState.
  //   _configuration = MapConfiguration(
  //     places: newPlaces,
  //     selectedCategory:
  //         Provider.of<AppState>(context, listen: false).selectedCategory,
  //   );

  //   Provider.of<AppState>(context, listen: false).setPlaces(newPlaces);
  // }

  void _onToggleMapTypePressed() {
    final nextType =
        MapType.values[(_currentMapType.index + 1) % MapType.values.length];

    setState(() {
      _currentMapType = nextType;
    });
  }

  // void _pushPlaceDetailsScreen(Place place) {
  //   Navigator.push<void>(
  //     context,
  //     MaterialPageRoute(builder: (context) {
  //       return PlaceDetails(
  //         place: place,
  //         onChanged: (value) => _onPlaceChanged(value),
  //       );
  //     }),
  //   );
  // }

  Future<void> _showPlacesForSelectedCategory(PlaceCategory category) async {
    setState(() {
      for (var marker in List.of(_markedPlaces.keys)) {
        final place = _markedPlaces[marker]!;
        final updatedMarker = marker.copyWith(
          visibleParam:
              category == PlaceCategory.all ? true : place.category == category,
        );

        _updateMarker(
          marker: marker,
          updatedMarker: updatedMarker,
          place: place,
        );
      }
    });

    // await _zoomToFitPlaces(_getPlacesForCategory(
    //   category,
    //   _markedPlaces.values.toList(),
    // ));
  }

  Future<void> _switchSelectedCategory(PlaceCategory category) async {
    Provider.of<AppState>(context, listen: false).setSelectedCategory(category);
    await _showPlacesForSelectedCategory(category);
  }

  void _updateExistingPlaceMarker({required Place place}) {
    var marker = _markedPlaces.keys
        .singleWhere((value) => _markedPlaces[value]!.id == place.id);

    setState(() {
      final updatedMarker = marker.copyWith(
        infoWindowParam: InfoWindow(
          title: "Hey There",
        ),
      );
      _updateMarker(marker: marker, updatedMarker: updatedMarker, place: place);
    });
  }

  void _updateMarker({
    required Marker? marker,
    required Marker updatedMarker,
    required Place place,
  }) {
    _markers.remove(marker);
    _markedPlaces.remove(marker);

    _markers.add(updatedMarker);
    _markedPlaces[updatedMarker] = place;
  }

  // Future<void> _zoomToFitPlaces(List<Place> places) async {
  //   var controller = await mapController.future;

  //   // Default min/max values to latitude and longitude of center.
  //   var minLat = widget.center!.latitude;
  //   var maxLat = widget.center!.latitude;
  //   var minLong = widget.center!.longitude;
  //   var maxLong = widget.center!.longitude;

  //   for (var place in places) {
  //     minLat = min(minLat, place.latitude);
  //     maxLat = max(maxLat, place.latitude);
  //     minLong = min(minLong, place.longitude);
  //     maxLong = max(maxLong, place.longitude);
  //   }

  //   await controller.animateCamera(
  //     CameraUpdate.newLatLngBounds(
  //       LatLngBounds(
  //         southwest: LatLng(minLat, minLong),
  //         northeast: LatLng(maxLat, maxLong),
  //       ),
  //       48.0,
  //     ),
  //   );
  // }

  /// Determine the current position of the device.
  ///
  /// When the location services are not enabled or permissions
  /// are denied the `Future` will return an error.
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  static Future<BitmapDescriptor> _getPlaceMarkerIcon(
      BuildContext context, PlaceCategory category) async {
    switch (category) {
      case PlaceCategory.thief:
        return BitmapDescriptor.fromAssetImage(
            createLocalImageConfiguration(context, size: const Size.square(32)),
            'assets/thief.png');
      case PlaceCategory.death:
        return BitmapDescriptor.fromAssetImage(
            createLocalImageConfiguration(context, size: const Size.square(32)),
            'assets/death.png');
      case PlaceCategory.kidnapping:
        return BitmapDescriptor.fromAssetImage(
            createLocalImageConfiguration(context, size: const Size.square(32)),
            'assets/tied.png');
      default:
        return BitmapDescriptor.fromAssetImage(
            createLocalImageConfiguration(context, size: const Size.square(32)),
            'assets/warning.png');
    }
  }

  static List<Place> _getPlacesForCategory(
      PlaceCategory category, List<Place> places) {
    if (category == PlaceCategory.all) return places.toList();
    return places.where((place) => place.category == category).toList();
  }
}

class _AddPlaceButtonBar extends StatelessWidget {
  final bool visible;

  final VoidCallback onSavePressed;
  final VoidCallback onCancelPressed;

  const _AddPlaceButtonBar({
    Key? key,
    required this.visible,
    required this.onSavePressed,
    required this.onCancelPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 14.0),
        alignment: Alignment.bottomCenter,
        child: ButtonBar(
          alignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(primary: Colors.blueGrey[800]),
              child: const Text(
                'Salvar',
                style: TextStyle(color: Colors.white, fontSize: 16.0),
              ),
              onPressed: onSavePressed,
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(primary: Colors.brown[800]),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white, fontSize: 16.0),
              ),
              onPressed: onCancelPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryButtonBar extends StatelessWidget {
  final PlaceCategory selectedPlaceCategory;
  final bool visible;
  final ValueChanged<PlaceCategory> onChanged;

  const _CategoryButtonBar({
    Key? key,
    required this.selectedPlaceCategory,
    required this.visible,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      child: Container(
        height: 800,
        padding: const EdgeInsets.fromLTRB(15.0, 0.0, 0.0, 20),
        alignment: Alignment.bottomCenter,
        child: ButtonBar(
          alignment: MainAxisAlignment.start,
          children: [
            FloatingActionButton(
              backgroundColor: selectedPlaceCategory == PlaceCategory.thief
                  ? Colors.blueGrey[800]
                  : Colors.blueGrey[500],
              child: Image(
                image: AssetImage('assets/thief.png'),
                width: 32,
                alignment: Alignment.center,
              ),
              onPressed: () => onChanged(PlaceCategory.thief),
            ),
            FloatingActionButton(
              backgroundColor: selectedPlaceCategory == PlaceCategory.death
                  ? Colors.blueGrey[800]
                  : Colors.blueGrey[500],
              child: Image(
                image: AssetImage('assets/death.png'),
                width: 32,
                alignment: Alignment.center,
              ),
              onPressed: () => onChanged(PlaceCategory.death),
            ),
            FloatingActionButton(
              backgroundColor: selectedPlaceCategory == PlaceCategory.kidnapping
                  ? Colors.blueGrey[800]
                  : Colors.blueGrey[500],
              child: Image(
                image: AssetImage('assets/tied.png'),
                width: 32,
                alignment: Alignment.center,
              ),
              onPressed: () => onChanged(PlaceCategory.kidnapping),
            ),
            FloatingActionButton(
              backgroundColor: selectedPlaceCategory == PlaceCategory.all
                  ? Colors.orange[900]
                  : Colors.orange[700],
              child: Image(
                image: AssetImage('assets/warning.png'),
                width: 32,
                alignment: Alignment.center,
              ),
              onPressed: () => onChanged(PlaceCategory.all),
            )
          ],
        ),
      ),
    );
  }
}

class _MapFabs extends StatelessWidget {
  final bool visible;
  final VoidCallback onAddPlacePressed;
  final VoidCallback onToggleMapTypePressed;

  const _MapFabs({
    Key? key,
    required this.visible,
    required this.onAddPlacePressed,
    required this.onToggleMapTypePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topRight,
      margin: const EdgeInsets.only(top: 12.0, right: 12.0),
      child: Visibility(
        visible: visible,
        child: Column(
          children: [
            FloatingActionButton(
              heroTag: 'add_place_button',
              onPressed: onAddPlacePressed,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              backgroundColor: Colors.blueGrey[800],
              child: const Icon(Icons.add_location, size: 36.0),
            ),
            const SizedBox(height: 12.0),
            FloatingActionButton(
              heroTag: 'toggle_map_type_button',
              onPressed: onToggleMapTypePressed,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              mini: true,
              backgroundColor: Colors.orange[700],
              child: const Icon(Icons.map, size: 28.0),
            )
          ],
        ),
      ),
    );
  }
}
