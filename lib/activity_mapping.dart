class ActivityMapping {
  //activity code nemusí být přiřazen
  String? ptfmActCode;
  String extEnvironment;
  String extCode;
  double ratio;
  String? note;
  DateTime? updateTime;

  ActivityMapping(
      {this.ptfmActCode,
      required this.extEnvironment,
      required this.extCode,
      this.ratio = 1,
      this.note});

  static const jsonPtfmActCode = 'activityCode';
  static const jsonExtEnvironment = 'extEnvironment';
  static const jsonExtCode = 'extCode';
  static const jsonRatio = 'ratio';
  static const jsonNote = 'note';
  static const jsonServerId = 'id';

  factory ActivityMapping.fromJson(Map<String, dynamic> map) {
    return ActivityMapping(
        ptfmActCode: map[jsonPtfmActCode],
        extEnvironment: map[jsonExtEnvironment],
        extCode: map[jsonExtCode],
        ratio: map[jsonRatio],
        note: map[jsonNote]);
  }

  Map<String, dynamic> toJson() => {
        if (ptfmActCode != null) jsonPtfmActCode: ptfmActCode,
        jsonExtEnvironment: extEnvironment,
        jsonExtCode: extCode,
        jsonRatio: ratio,
        if (note != null) jsonNote: note,
      };
}
