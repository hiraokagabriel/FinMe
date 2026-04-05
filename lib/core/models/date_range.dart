class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end})
      : assert(!end.isBefore(start), 'end must be on or after start');

  bool contains(DateTime date) {
    return (date.isAtSameMomentAs(start) || date.isAfter(start)) &&
        (date.isAtSameMomentAs(end) || date.isBefore(end));
  }
}
