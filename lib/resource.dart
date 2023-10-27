import 'package:collection/collection.dart';

class Resource {
  String? org;
  late String code;
  late String name;

  ///typ zdroje - osoba, prostředek...
  late ResourceType type;

  ///skupina, do které zdroj patří (používá se pro filtrování a třídění
  String? group;

  ///základní kompetence zdroje - např. role na projektech
  String? competence;

  ///základní pozice zdroje (Job Position)
  String? position;

  ///režim fungování zdroje (Operation mode)
  String? mode;

  ///lokalizace zdroje (umístění)
  String? location;

  ///základní hodinová sazba zdroje
  double? rate;

  ///jednorázový náklad zdroje při alokaci na aktivitu
  double? fixedCost;

  ///manažer zdroje
  String? manager;

  ///kontaktní údaje na zdroj
  String? contact;

  ///poznámka ke zdroji
  String? note;

  DateTime? dateFrom;
  DateTime? dateTo;
  late ResourceState state;
  DateTime? updateTime;

  ///databázové ID na serveru
  int? serverId;

  Resource(
      {this.org,
      required this.name,
      required this.code,
      this.group,
      this.competence,
      this.position,
      this.mode,
      this.location,
      this.rate,
      this.fixedCost,
      this.dateFrom,
      this.dateTo,
      this.type = ResourceType.person,
      this.manager,
      this.contact,
      this.note,
      this.state = ResourceState.active,
      this.serverId});

  static const jsonOrg = 'org';
  static const jsonCode = 'code';
  static const jsonName = 'name';
  static const jsonGroup = 'group';
  static const jsonCompetence = 'competence';
  static const jsonPosition = 'position';
  static const jsonMode = 'mode';
  static const jsonLocation = 'location';
  static const jsonRate = 'rate';
  static const jsonFixedCost = 'fixedCost';
  static const jsonDateFrom = 'dateFrom';
  static const jsonDateTo = 'dateTo';
  static const jsonType = 'type';
  static const jsonManager = 'manager';
  static const jsonContact = 'contact';
  static const jsonNote = 'note';
  static const jsonState = 'state';
  static const jsonServerId = 'id';

  Map<String, dynamic> toJson() => {
        jsonOrg: org,
        jsonCode: code,
        jsonName: name,
        jsonType: type.name,
        if (group != null) jsonGroup: group,
        if (competence != null) jsonCompetence: competence,
        if (position != null) jsonPosition: position,
        if (mode != null) jsonMode: mode,
        if (location != null) jsonLocation: location,
        if (rate != null) jsonRate: rate,
        if (fixedCost != null) jsonFixedCost: fixedCost,
        if (dateFrom != null) jsonDateFrom: dateFrom!.toIso8601String(),
        if (dateTo != null) jsonDateTo: dateTo!.toIso8601String(),
        if (manager != null) jsonManager: manager,
        if (contact != null) jsonContact: contact,
        if (note != null) jsonNote: note,
        jsonState: state.name
      };

  factory Resource.fromJson(Map<String, dynamic> map) {
    return Resource(
        org: map[jsonOrg],
        code: map[jsonCode],
        name: map[jsonName],
        type: map[jsonType] != null
            ? ResourceType.values.firstWhereOrNull((element) => element.name == map[jsonType]) ??
                ResourceType.other
            : ResourceType.other,
        group: map[jsonGroup],
        competence: map[jsonCompetence],
        position: map[jsonPosition],
        mode: map[jsonMode],
        location: map[jsonLocation],
        rate: map[jsonRate],
        fixedCost: map[jsonFixedCost],
        dateFrom: map[jsonDateFrom] != null ? DateTime.tryParse(map[jsonDateFrom]) : null,
        dateTo: map[jsonDateTo] != null ? DateTime.tryParse(map[jsonDateTo]) : null,
        manager: map[jsonManager],
        contact: map[jsonContact],
        note: map[jsonNote],
        state: map[jsonState] != null
            ? ResourceState.values.firstWhereOrNull((element) => element.name == map[jsonState]) ??
                ResourceState.active
            : ResourceState.active,
        serverId: map[jsonServerId]);
  }
}

enum ResourceType { person, team, device, room, other }

enum ResourceState { active, inactive, archived }
