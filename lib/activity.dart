import 'package:collection/collection.dart';

class Activity {
  String? org;
  late String code;
  late String name;

  ///typ aktivity - projekt, workpackage, task
  late ActivityType type;

  ///kód rodičovské aktivity
  String? parentCode;

  ///skupina, do které aktivita patří (pro zobrazování, filtrování)
  String? group;

  ///obchodní oblast, do které aktivita patří
  String? business;

  ///priorita aktivity
  String? priority;

  ///hodnota aktivity (výnos)
  double? value;

  ///rozpočet aktivity (předpokládané náklady)
  double? budget;

  ///předpokládané úsilí - množství man hours
  double? effort;

  ///zákazník
  String? stakeholder;

  ///pravděpodobnost realizace (probability of win)
  double? pwin;

  ///poznámka k aktivitě
  String? note;
  DateTime? dateFrom;
  DateTime? dateTo;
  late ActivityState state;
  DateTime? updateTime;

  ///databázové ID na serveru
  int? serverId;

  Activity(
      {this.org,
      required this.name,
      required this.code,
      this.type = ActivityType.activity,
      this.parentCode,
      this.group,
      this.business,
      this.priority,
      this.dateFrom,
      this.dateTo,
      this.value,
      this.budget,
      this.effort,
      this.stakeholder,
      this.pwin,
      this.note,
      this.state = ActivityState.inprogress,
      this.serverId});

  static const jsonOrg = 'org';
  static const jsonCode = 'code';
  static const jsonName = 'name';
  static const jsonType = 'type';
  static const jsonParentCode = 'parentCode';
  static const jsonGroup = 'group';
  static const jsonBusiness = 'business';
  static const jsonPriority = 'priority';
  static const jsonDateFrom = 'dateFrom';
  static const jsonDateTo = 'dateTo';
  static const jsonValue = 'value';
  static const jsonBudget = 'budget';
  static const jsonEffort = 'effort';
  static const jsonStakeholder = 'stakeholder';
  static const jsonPwin = 'pwin';
  static const jsonNote = 'note';
  static const jsonState = 'state';
  static const jsonServerId = 'id';

  Map<String, dynamic> toJson() => {
        jsonOrg: org,
        jsonCode: code,
        jsonName: name,
        jsonType: type.name,
        if (parentCode != null) jsonParentCode: parentCode,
        if (group != null) jsonGroup: group,
        if (business != null) jsonBusiness: business,
        if (priority != null) jsonPriority: priority,
        if (dateFrom != null) jsonDateFrom: dateFrom!.toIso8601String(),
        if (dateTo != null) jsonDateTo: dateTo!.toIso8601String(),
        if (value != null) jsonValue: value,
        if (budget != null) jsonBudget: budget,
        if (effort != null) jsonEffort: effort,
        if (stakeholder != null) jsonStakeholder: stakeholder,
        if (pwin != null) jsonPwin: pwin,
        if (note != null) jsonNote: note,
        jsonState: state.name
      };

  factory Activity.fromJson(Map<String, dynamic> map) {
    return Activity(
        org: map[jsonOrg],
        code: map[jsonCode],
        parentCode: map[jsonParentCode],
        name: map[jsonName],
        type: map[jsonType] != null
            ? ActivityType.values.firstWhereOrNull((element) => element.name == map[jsonType]) ??
                ActivityType.activity
            : ActivityType.activity,
        group: map[jsonGroup],
        business: map[jsonBusiness],
        priority: map[jsonPriority],
        dateFrom: map[jsonDateFrom] != null ? DateTime.tryParse(map[jsonDateFrom]) : null,
        dateTo: map[jsonDateTo] != null ? DateTime.tryParse(map[jsonDateTo]) : null,
        value: map[jsonValue],
        budget: map[jsonBudget],
        effort: map[jsonEffort],
        stakeholder: map[jsonStakeholder],
        pwin: map[jsonPwin],
        note: map[jsonNote],
        state: map[jsonState] != null
            ? ActivityState.values.firstWhereOrNull((element) => element.name == map[jsonState]) ??
                ActivityState.inprogress
            : ActivityState.inprogress,
        serverId: map[jsonServerId]);
  }
}

enum ActivityType { activity, project, workpackage, task }

enum ActivityState { proposal, inprogress, closed, archived }
