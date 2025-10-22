
class TagsObject {
  final List<String> general;
  final List<String> artist;
  final List<String> character;
  final List<String> species;
  final List<String> copyright;
  final List<String> lore;
  final List<String> meta;

  TagsObject({
    this.general = const [],
    this.artist = const [],
    this.character = const [],
    this.species = const [],
    this.copyright = const [],
    this.lore = const [],
    this.meta = const [],
  });

  factory TagsObject.fromJson(Map<String, dynamic> json) {
    return TagsObject(
      general: List<String>.from(json['general'] ?? []),
      artist: List<String>.from(json['artist'] ?? []),
      character: List<String>.from(json['character'] ?? []),
      species: List<String>.from(json['species'] ?? []),
      copyright: List<String>.from(json['copyright'] ?? []),
      lore: List<String>.from(json['lore'] ?? []),
      meta: List<String>.from(json['meta'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'general': general,
        'artist': artist,
        'character': character,
        'species': species,
        'copyright': copyright,
        'lore': lore,
        'meta': meta,
      };
}
