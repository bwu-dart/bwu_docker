library bwu_docker.src.shared.version;

class Version implements Comparable {
  final int major;
  final int minor;
  final int patch;

  Version(this.major, this.minor, this.patch) {
    if (major == null || major < 0) {
      throw new ArgumentError('"major" must not be null and must not be < 0.');
    }
    if (minor == null || minor < 0) {
      throw new ArgumentError('"minor" must not be null and must not be < 0.');
    }
    if (patch != null && patch < 0) {
      throw new ArgumentError('If "patch" is provided the value must be >= 0.');
    }
  }

  factory Version.fromString(String version) {
    assert(version != null && version.isNotEmpty);
    final List<String> parts = version.split('.');
    int major = 0;
    int minor = 0;
    int patch;

    if (parts.length < 2) {
      throw 'Unsupported version string format "${version}".';
    }

    if (parts.length >= 1) {
      major = int.parse(parts[0]);
    }
    if (parts.length >= 2) {
      minor = int.parse(parts[1]);
    }
    if (parts.length >= 3) {
      patch = int.parse(parts[2]);
    }
    if (parts.length >= 4) {
      throw 'Unsupported version string format "${version}".';
    }
    return new Version(major, minor, patch);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Version) {
      return false;
    }
    final Version o = other as Version;
    return o.major == major &&
        o.minor == minor &&
        ((o.patch == null && patch == null) || (o.patch == patch));
  }

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() => '${major}.${minor}${patch != null ? '.${patch}' : ''}';

  bool operator <(Version other) {
    assert(other != null);
    if (major < other.major) {
      return true;
    } else if (major > other.major) {
      return false;
    }
    if (minor < other.minor) {
      return true;
    } else if (minor > other.minor) {
      return false;
    }
    if (patch == null && other.patch == null) {
      return false;
    }
    if (patch == null || other.patch == null) {
      throw 'Only version with an equal number of parts can be compared.';
    }
    if (patch < other.patch) {
      return true;
    }
    return false;
  }

  bool operator >(Version other) {
    return other != this && !(this < other);
  }

  bool operator >=(Version other) {
    return this == other || this > other;
  }

  bool operator <=(Version other) {
    return this == other || this < other;
  }

  @override
  int compareTo(Version other) {
    if (this < other) {
      return -1;
    } else if (this == other) {
      return 0;
    }
    return 1;
  }

  static int compare(Comparable a, Comparable b) => a.compareTo(b);
}

/// Enum of API versions currently considered for API differences.
class RemoteApiVersion extends Version {
  static final RemoteApiVersion v1x15 = new RemoteApiVersion(1, 15, null);
  @Deprecated('See v1x15') // deprecated 2015-11-26
  // ignore: non_constant_identifier_names
  static final RemoteApiVersion v1_15 = v1x15;

  static final RemoteApiVersion v1x16 = new RemoteApiVersion(1, 16, null);
  @Deprecated('See v1x16')
  // ignore: non_constant_identifier_names
  static final RemoteApiVersion v1_16 = v1x16;

  static final RemoteApiVersion v1x17 = new RemoteApiVersion(1, 17, null);
  @Deprecated('See v1x17')
  // ignore: non_constant_identifier_names
  static final RemoteApiVersion v1_17 = v1x17;

  static final RemoteApiVersion v1x18 = new RemoteApiVersion(1, 18, null);
  @Deprecated('See v1x18')
  // ignore: non_constant_identifier_names
  static final RemoteApiVersion v1_18 = v1x18;

  static final RemoteApiVersion v1x19 = new RemoteApiVersion(1, 19, null);
  @Deprecated('See v1x19')
  // ignore: non_constant_identifier_names
  static final RemoteApiVersion v1_19 = v1x19;

  // ignore: non_constant_identifier_names
  static final RemoteApiVersion v1x20 = new RemoteApiVersion(1, 20, null);
  static final RemoteApiVersion v1x21 = new RemoteApiVersion(1, 21, null);
  static final RemoteApiVersion v1x22 = new RemoteApiVersion(1, 22, null);

  static final List<RemoteApiVersion> versions = <RemoteApiVersion>[
    v1x15,
    v1x16,
    v1x17,
    v1x18,
    v1x19,
    v1x20,
    v1x21,
    v1x22,
  ];

  RemoteApiVersion(int major, int minor, int patch)
      : super(major, minor, patch);

  factory RemoteApiVersion.fromVersion(Version version) => versions.firstWhere(
      (RemoteApiVersion v) => v == version,
      orElse: () =>
          new RemoteApiVersion(version.major, version.minor, version.patch));

  bool get isSupported => versions.contains(this);

  /// Add this to the request Uri to use a specific version of the remote API.
  String get asDirectory =>
      '/v${major}.${minor}${patch == null ? '' : '.${patch}'}';
}
