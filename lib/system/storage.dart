import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Storage {
  static setJSON(String key, List<dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(key, jsonEncode(value));
  }

  static getJSON(String key) async {
    final prefs = await SharedPreferences.getInstance();
    var s = prefs.getString(key) ??  "[]";
    List<dynamic> dataList = jsonDecode(s);
    return dataList;
  }

  // 设置布尔的值
  static setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(key, value);
  }

  // 设置double的值
  static setDoubl(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(key, value);
  }

  // 设置int的值
  static setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(key, value);
  }

  // 设置Sting的值
  static setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(key, value);
  }

  // 设置StringList
  static setStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(key, value);
  }

  // 获取返回为bool的内容
  static getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    bool value = prefs.getBool(key) ?? false;
    return value;
  }

  // 获取返回为double的内容
  static getDouble(String key) async {
    final prefs = await SharedPreferences.getInstance();
    double value = prefs.getDouble(key) ?? 0;
    return value;
  }

  // 获取返回为int的内容
  static getInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    int value = prefs.getInt(key) ?? 0;
    return value;
  }

  // 获取返回为String的内容
  static getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    String value = prefs.getString(key) ?? "";
    return value;
  }

  // 获取返回为StringList的内容
  static getStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> value = prefs.getStringList(key) ?? [];
    return value;
  }

  // 移除单个
  static remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(key);
  }

  // 清空所有的
  static clear() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }
}
