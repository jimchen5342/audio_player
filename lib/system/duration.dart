extension DurationParse on Duration{
	String format(){
    var duration = "$this".split(".")[0];
    if(duration.startsWith("0:")) {
      duration = duration.substring(2);
    }
    return duration;
	}
}