library bwu_docker.src.shared.json_util;

import 'dart:collection';
import 'version.dart';

/// Ensure all provided JSON keys are actually supported.
void checkSurplusItems(Version apiVersion, Map<Version, List<String>> expected,
    Iterable<String> actual) {
  assert(expected != null);
  assert(actual != null);
  if (apiVersion == null || expected.isEmpty) {
    return;
  }
  List<String> expectedForVersion = expected[apiVersion];
  if (expectedForVersion == null) {
    if (expected.length == 1) {
      expectedForVersion = expected.values.first;
    } else {
      final List<Version> ascSortedKeys = expected.keys.toList()..sort();
      expectedForVersion =
          expected[ascSortedKeys..lastWhere((Version k) => k < apiVersion)];
      if (expectedForVersion == null) {
        expectedForVersion = expected[ascSortedKeys.first];
      }
    }
  }
  assert(actual.every((String k) {
    if (!expectedForVersion.contains(k)) {
      print('Unsupported key: "${k}"');
      return false;
    }
    return true;
  }));
}

DateTime parseDate(Object dateValue) {
  if (dateValue == null) {
    return null;
  }
  if (dateValue is String) {
    if (dateValue == '0001-01-01T00:00:00Z') {
      return new DateTime(1, 1, 1);
    }

    try {
      final int years = int.parse((dateValue).substring(0, 4));
      final int months = int.parse(dateValue.substring(5, 7));
      final int days = int.parse(dateValue.substring(8, 10));
      final int hours = int.parse(dateValue.substring(11, 13));
      final int minutes = int.parse(dateValue.substring(14, 16));
      final int seconds = int.parse(dateValue.substring(17, 19));
      final int milliseconds = int.parse(dateValue.substring(20, 23));
      return new DateTime.utc(
          years, months, days, hours, minutes, seconds, milliseconds);
    } catch (_) {
      print('parsing "${dateValue}" failed.');
      rethrow;
    }
  } else if (dateValue is int) {
    return new DateTime.fromMillisecondsSinceEpoch(dateValue * 1000,
        isUtc: true);
  }
  throw 'Unsupported type "${dateValue.runtimeType}" passed.';
}

bool parseBool(dynamic boolValue) {
  if (boolValue == null) {
    return null;
  }
  if (boolValue is bool) {
    return boolValue;
  }
  if (boolValue is int) {
    return boolValue == 1;
  }
  if (boolValue is String) {
    if (boolValue.toLowerCase() == 'true') {
      return true;
    } else if (boolValue.toLowerCase() == 'false') {
      return false;
    }
  }

  throw new FormatException(
      'Value "${boolValue}" can not be converted to bool.');
}

UnmodifiableMapView<String, String> parseLabels(
    Map<String, List<String>> json) {
  if (json == null) {
    return null;
  }
  final Iterable<List<String>> l = json['Labels'] != null
      ? json['Labels'].map /*<List<String>>*/ ((String l) => l.split('='))
      : null;
  return l == null
      ? null
      : toUnmodifiableMapView /*<String,String>*/ (
          new Map<String, String>.fromIterable(l,
              key: (List<String> l) => l[0],
              value: (String l) => l.length == 2 ? l[1] : null));
}

UnmodifiableMapView<dynamic /*=K*/,
    dynamic /*=V*/ > toUnmodifiableMapView /*<K,V>*/ (
    Map<dynamic /*=K*/, dynamic /*=V*/ > map) {
  if (map == null) {
    return null;
  }
  return new UnmodifiableMapView /*<K,V>*/ (
      new Map<dynamic /*=K*/, dynamic /*=V*/ >.fromIterable(map.keys,
          key: (dynamic /*=K*/ k) => k, value: (dynamic k) {
    if (map == null) {
      return null;
    }
    if (map[k] is Map) {
      return toUnmodifiableMapView /*<V,dynamic>*/ (map[k] as Map)
          as dynamic /*=V*/;
    } else if (map[k] is List) {
      return toUnmodifiableListView /*<V>*/ (map[k] as List) as dynamic /*=V*/;
    } else {
      return map[k] as dynamic /*=V*/;
    }
  }));
}

UnmodifiableListView /*<T>*/ toUnmodifiableListView /*<T>*/ (Iterable list) {
  if (list == null) {
    return null;
  }
  if (list.length == 0) {
    return new UnmodifiableListView /*<T>*/ (const []);
  }

  return new UnmodifiableListView /*<T>*/ (list.map /*<T>*/ ((dynamic e) {
    if (e is Map) {
      return toUnmodifiableMapView /*<T>*/ (e);
    } else if (e is List) {
      return toUnmodifiableListView /*<T>*/ (e);
    } else {
      return e as Iterable /*<T>*/;
    }
  }));
}
