/// PTFM Worklog
class Worklog {
  late DateTime date;
  String? org;
  late String activityCode;
  late String resourceCode;
  late double manHours;
  String? note;
  String? leave;
  DateTime? updateTime;

  ///databázové ID na serveru
  int? serverId;

  Worklog(
      {required this.date,
      this.org,
      required this.activityCode,
      required this.resourceCode,
      required this.manHours,
      this.note,
      this.leave,
      this.serverId});

  static const jsonOrg = 'org';
  static const jsonActivityCode = 'activityCode';
  static const jsonResoureCode = 'resourceCode';
  static const jsonDate = 'date';
  static const jsonHours = 'manHours';
  static const jsonLeave = 'leave';
  static const jsonServerId = 'id';

  Map<String, dynamic> toJson() => {
        jsonOrg: org,
        jsonActivityCode: activityCode,
        jsonResoureCode: resourceCode,
        jsonDate: date.toIso8601String(),
        jsonHours: manHours,
        jsonLeave: leave,
      };

  factory Worklog.fromJson(Map<String, dynamic> map) {
    return Worklog(
        org: map[jsonOrg],
        activityCode: map[jsonActivityCode],
        resourceCode: map[jsonResoureCode],
        manHours: map[jsonHours],
        leave: map[jsonLeave],
        date: DateTime.parse(map[jsonDate]),
        serverId: map[jsonServerId]);
  }
}
