import 'package:cloud_firestore/cloud_firestore.dart';

class League {
  final String id;
  final String name;
  final String shortName;
  final String country;
  final String? logo;
  final int? apiFootballId;
  final bool active;
  final int? currentSeason;

  League({
    required this.id,
    required this.name,
    required this.shortName,
    required this.country,
    this.logo,
    this.apiFootballId,
    this.active = true,
    this.currentSeason,
  });

  factory League.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return League(
      id: doc.id,
      name: data['name'] ?? '',
      shortName: data['shortName'] ?? data['name'] ?? '',
      country: data['country'] ?? '',
      logo: data['logo'] as String?,
      apiFootballId: data['apiFootballId'] as int?,
      active: data['active'] ?? true,
      currentSeason: data['currentSeason'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'shortName': shortName,
      'country': country,
      'logo': logo,
      'apiFootballId': apiFootballId,
      'active': active,
      'currentSeason': currentSeason,
    };
  }
}
