/// Položka vykázané práce - v dotazu typicky agregovaná přes AreaPath
class TrackerWorkLog {
  String emailAddress;
  int periodLength;
  DateTime shortDate;
  String areaPath;
  String title;

  TrackerWorkLog(
      {required this.emailAddress,
      required this.periodLength,
      required this.shortDate,
      required this.areaPath,
      required this.title});

  factory TrackerWorkLog.fromJson(Map<String, dynamic> map) {
    return TrackerWorkLog(
        emailAddress: map['User']['Email'] as String,
        shortDate: DateTime.parse(map['WorklogDate']['ShortDate']),
        periodLength: map['PeriodLength'] as int,
        areaPath: map['WorkItem']['System_AreaPath'] != null
            ? map['WorkItem']['System_AreaPath'] as String
            : '',
        title: map['WorkItem']['System_Title'] != null
            ? map['WorkItem']['System_Title'] as String
            : '');
  }
}
