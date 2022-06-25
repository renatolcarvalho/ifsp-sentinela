// Copyright 2020 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'place.dart';
import 'place_tracker_app.dart';

class PlaceList extends StatefulWidget {
  const PlaceList({Key? key}) : super(key: key);

  @override
  PlaceListState createState() => PlaceListState();
}

class PlaceListState extends State<PlaceList> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    var state = Provider.of<AppState>(context);
    return Column(
      children: [
        _ListCategoryButtonBar(
          selectedCategory: state.selectedCategory,
          onCategoryChanged: (value) => _onCategoryChanged(value),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
            controller: _scrollController,
            shrinkWrap: true,
            children: state.places
                .where((place) => place.category == state.selectedCategory)
                .map((place) => _PlaceListTile(
                      place: place,
                      onPlaceChanged: (value) => _onPlaceChanged(value),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  void _onCategoryChanged(PlaceCategory newCategory) {
    _scrollController.jumpTo(0.0);
    Provider.of<AppState>(context, listen: false)
        .setSelectedCategory(newCategory);
  }

  void _onPlaceChanged(Place value) {
    // Replace the place with the modified version.
    final newPlaces =
        List<Place>.from(Provider.of<AppState>(context, listen: false).places);
    final index = newPlaces.indexWhere((place) => place.id == value.id);
    newPlaces[index] = value;

    Provider.of<AppState>(context, listen: false).setPlaces(newPlaces);
  }
}

class _CategoryButton extends StatelessWidget {
  final PlaceCategory category;

  final bool selected;
  final ValueChanged<PlaceCategory> onCategoryChanged;
  const _CategoryButton({
    Key? key,
    required this.category,
    required this.selected,
    required this.onCategoryChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    late String _buttonText;
    switch (category) {
      case PlaceCategory.thief:
        _buttonText = 'Assalto';
        break;
      case PlaceCategory.death:
        _buttonText = 'Homicídio';
        break;
      case PlaceCategory.kidnapping:
        _buttonText = 'Sequestro';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? Colors.blue : Colors.transparent,
          ),
        ),
      ),
      child: ButtonTheme(
        height: 50.0,
        child: TextButton(
          child: Text(
            _buttonText,
            style: TextStyle(
              fontSize: selected ? 20.0 : 18.0,
              color: selected ? Colors.blue : Colors.black87,
            ),
          ),
          onPressed: () => onCategoryChanged(category),
        ),
      ),
    );
  }
}

class _ListCategoryButtonBar extends StatelessWidget {
  final PlaceCategory selectedCategory;

  final ValueChanged<PlaceCategory> onCategoryChanged;
  const _ListCategoryButtonBar({
    Key? key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CategoryButton(
          category: PlaceCategory.thief,
          selected: selectedCategory == PlaceCategory.thief,
          onCategoryChanged: onCategoryChanged,
        ),
        _CategoryButton(
          category: PlaceCategory.death,
          selected: selectedCategory == PlaceCategory.death,
          onCategoryChanged: onCategoryChanged,
        ),
        _CategoryButton(
          category: PlaceCategory.kidnapping,
          selected: selectedCategory == PlaceCategory.kidnapping,
          onCategoryChanged: onCategoryChanged,
        ),
      ],
    );
  }
}

class _PlaceListTile extends StatelessWidget {
  final Place place;

  final ValueChanged<Place> onPlaceChanged;
  const _PlaceListTile({
    Key? key,
    required this.place,
    required this.onPlaceChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Container(
        padding: const EdgeInsets.only(top: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.address,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 16,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16.0),
            Divider(
              height: 2.0,
              color: Colors.grey[700],
            ),
          ],
        ),
      ),
    );
  }
}
