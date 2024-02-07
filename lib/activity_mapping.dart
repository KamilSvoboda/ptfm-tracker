class ActivityMapping {
  //activity code nemusí být přiřazen
  String? activityCode;
  String extEnvironment;
  String extCode;
  double ratio;
  String? note;
  DateTime? updateTime;

  ActivityMapping(
      {this.activityCode,
      required this.extEnvironment,
      required this.extCode,
      this.ratio = 1,
      this.note});

  static const jsonActivityCode = 'activityCode';
  static const jsonExtEnvironment = 'extEnvironment';
  static const jsonExtCode = 'extCode';
  static const jsonRatio = 'ratio';
  static const jsonNote = 'note';
  static const jsonServerId = 'id';

  factory ActivityMapping.fromJson(Map<String, dynamic> map) {
    return ActivityMapping(
        activityCode: map[jsonActivityCode],
        extEnvironment: map[jsonExtEnvironment],
        extCode: map[jsonExtCode],
        ratio: map[jsonRatio],
        note: map[jsonNote]);
  }

  Map<String, dynamic> toJson() => {
        if (activityCode != null) jsonActivityCode: activityCode,
        jsonExtEnvironment: extEnvironment,
        jsonExtCode: extCode,
        jsonRatio: ratio,
        if (note != null) jsonNote: note,
      };
}
