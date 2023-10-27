/// Položka na kterou je možné vykazovat v Azure (Epic, Featrue...)
/// V tuto chvíli nás zajímá pouze pro výčet všech areaPath
class TrackerWorkItem {
  String areaPath;

  TrackerWorkItem({required this.areaPath});

  factory TrackerWorkItem.fromJson(Map<String, dynamic> map) {
    return TrackerWorkItem(
      areaPath: map['System_AreaPath'],
    );
  }
}
