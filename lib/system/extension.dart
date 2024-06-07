extension DurationExtension on Duration{
	String format(){
    var duration = "$this".split(".")[0];
    if(duration.startsWith("0:")) {
      duration = duration.substring(2);
    }
    return duration;
	}
}

extension StringnExtension on String{
  bool isNumeric(){
    RegExp numeric = RegExp(r'^-?[0-9]+$');
    return numeric.hasMatch(this);
  }
}

extension DateTimeFormatting on DateTime {
  // 格式化日期為指定格式的字符串
  String format({String pattern = "yy-MM-dd HH:mm:ss.ms"}) {
    final Map<String, String> replacements = {
      'yyyy': year.toString(),
      'yy': year.toString().substring(2, 4),
      'MM': _twoDigits(month),
      'dd': _twoDigits(day),
      'HH': _twoDigits(hour),
      'mm': _twoDigits(minute),
      'ss': _twoDigits(second),
      'ms': millisecond.toString().padLeft(3, '0')
    };

    var formattedDate = pattern;
    replacements.forEach((key, value) {
      formattedDate = formattedDate.replaceAll(key, value);
    });

    return formattedDate;
  }

  // 將單位數轉換為兩位數的字符串
  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }
}