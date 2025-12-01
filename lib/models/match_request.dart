import '../utils/json_utils.dart';

class TeamInfo {
  final String? captainUserId;
  final String? teamName;

  const TeamInfo({
    this.captainUserId,
    this.teamName,
  });

  bool get isEmpty => (captainUserId == null || captainUserId!.isEmpty)
      && (teamName == null || teamName!.trim().isEmpty);

  factory TeamInfo.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      final captain = JsonUtils.parseId(json['captainUserId'] ?? json['captain']);
      final rawName = json['teamName'] ?? json['name'];
      final teamName = rawName is String ? rawName.trim() : null;
      return TeamInfo(
        captainUserId: captain.isEmpty ? null : captain,
        teamName: teamName?.isEmpty ?? true ? null : teamName,
      );
    }
    return const TeamInfo();
  }

  Map<String, dynamic> toJson() => {
        if (captainUserId != null && captainUserId!.isNotEmpty)
          'captainUserId': captainUserId,
        if (teamName != null && teamName!.trim().isNotEmpty)
          'teamName': teamName!.trim(),
      };
}

class MatchRequest {
  final String id;
  final String sportId;
  final String? sportName;
  final String? facilityId;
  final String? facilityName;
  final String? courtId;
  final String? courtName;
  final DateTime? desiredStart;
  final DateTime? desiredEnd;
  final int? skillMin;
  final int? skillMax;
  final String mode;
  final String status;
  final String visibility;
  final String? creatorId;
  final List<String> participants;
  final int participantCount;
  final int? participantLimit;
  final int? teamSize;
  final bool isCreator;
  final bool hasJoined;
  final List<String> teamA;
  final List<String> teamB;
  final TeamInfo? hostTeam;
  final TeamInfo? guestTeam;
  final String? myTeam;
  final int? teamLimit;
  final String? notes;
  final String? bookingId;
  final String? bookingStatus;
  final DateTime? bookingStart;
  final DateTime? bookingEnd;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MatchRequest({
    required this.id,
    required this.sportId,
    this.sportName,
    this.facilityId,
    this.facilityName,
    this.courtId,
    this.courtName,
    this.desiredStart,
    this.desiredEnd,
    this.skillMin,
    this.skillMax,
    this.mode = 'solo',
    required this.status,
    required this.visibility,
    this.creatorId,
    this.participants = const [],
    this.participantCount = 0,
    this.participantLimit,
    this.teamSize,
    this.isCreator = false,
    this.hasJoined = false,
    this.teamA = const <String>[],
    this.teamB = const <String>[],
    this.hostTeam,
    this.guestTeam,
    this.myTeam,
    this.teamLimit,
    this.notes,
    this.bookingId,
    this.bookingStatus,
    this.bookingStart,
    this.bookingEnd,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
  });

  factory MatchRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    String? parseName(dynamic direct, [dynamic fallback]) {
      String? extract(dynamic source) {
        if (source == null) return null;
        if (source is String) {
          final trimmed = source.trim();
          return trimmed.isEmpty ? null : trimmed;
        }
        if (source is Map<String, dynamic>) {
          final nestedName = source['name'];
          if (nestedName is String) {
            final trimmed = nestedName.trim();
            if (trimmed.isNotEmpty) return trimmed;
          }
        }
        return null;
      }

      return extract(direct) ?? extract(fallback);
    }

    final participantsRaw = json['participants'];
    final participants = <String>[];
    if (participantsRaw is List) {
      for (final item in participantsRaw) {
        final id = JsonUtils.parseId(item);
        if (id.isNotEmpty) participants.add(id);
      }
    }

    final skillRange = json['skillRange'];
    int? parseSkill(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return null;
    }

    final status = (json['status'] ?? 'open').toString();
    final rawMode = (json['mode'] ?? 'solo').toString().trim().toLowerCase();
    final normalizedMode = rawMode.isEmpty ? 'solo' : rawMode;
    final visibility = (json['visibility'] ?? 'public').toString();

    int? parseCount(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    List<String> parseTeam(dynamic value) {
      final members = <String>[];
      if (value is List) {
        for (final item in value) {
          final id = JsonUtils.parseId(item);
          if (id.isNotEmpty) members.add(id);
        }
      } else if (value is Map<String, dynamic>) {
        final nested = value['members'];
        if (nested is List) {
          for (final item in nested) {
            final id = JsonUtils.parseId(item);
            if (id.isNotEmpty) members.add(id);
          }
        }
      }
      return members;
    }

    final teamsRaw = json['teams'];
    List<String> teamA = const [];
    List<String> teamB = const [];
    if (teamsRaw is Map<String, dynamic>) {
      teamA = parseTeam(teamsRaw['teamA']);
      teamB = parseTeam(teamsRaw['teamB']);
    }

    final participantSet = <String>{...participants, ...teamA, ...teamB};
    final participantList = participantSet.toList(growable: false);

    TeamInfo? parseTeamInfo(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        final team = TeamInfo.fromJson(raw);
        return team.isEmpty ? null : team;
      }
      return null;
    }

    final hostTeam = parseTeamInfo(json['hostTeam']);
    final guestTeam = parseTeamInfo(json['guestTeam']);

    String? normalizeTeam(dynamic rawTeam) {
      if (rawTeam is String) {
        final trimmed = rawTeam.trim();
        if (trimmed.isEmpty) return null;
        final normalized = trimmed.toLowerCase();
        const aliasesA = {'teama', 'team a', 'team_a', 'team-a', 'a', 'team1'};
        const aliasesB = {'teamb', 'team b', 'team_b', 'team-b', 'b', 'team2'};
        if (aliasesA.contains(normalized)) return 'teamA';
        if (aliasesB.contains(normalized)) return 'teamB';
        if (trimmed == 'teamA' || trimmed == 'teamB') return trimmed;
      } else if (rawTeam is Map<String, dynamic>) {
        return normalizeTeam(rawTeam['value']);
      }
      return null;
    }

    final myTeam = normalizeTeam(json['myTeam']);

    final participantCount =
        parseCount(json['participantCount']) ?? participantList.length;

    final sportSource = json['sportId'] ?? json['sport'];
    final facilitySource = json['facilityId'] ?? json['facility'];
    final courtSource = json['courtId'] ?? json['court'];

    return MatchRequest(
      id: JsonUtils.parseId(json['id'] ?? json['_id']),
      sportId: JsonUtils.parseId(sportSource),
      sportName: parseName(json['sportName'], json['sport']),
      facilityId: JsonUtils.parseIdOrNull(facilitySource),
      facilityName: parseName(json['facilityName'], json['facility']),
      courtId: JsonUtils.parseIdOrNull(courtSource),
      courtName: parseName(json['courtName'], json['court']),
      desiredStart: parseDate(json['desiredStart']),
      desiredEnd: parseDate(json['desiredEnd']),
      skillMin: parseSkill(
        skillRange is Map<String, dynamic>
            ? skillRange['min']
            : json['skillMin'],
      ),
      skillMax: parseSkill(
        skillRange is Map<String, dynamic>
            ? skillRange['max']
            : json['skillMax'],
      ),
      mode: normalizedMode,
      status: status,
      visibility: visibility,
      creatorId: JsonUtils.parseId(json['creatorId']),
      participants: participantList,
      participantCount: participantCount,
      participantLimit: parseCount(json['participantLimit']),
      teamSize: parseCount(json['teamSize']),
      isCreator: json['isCreator'] == true,
      hasJoined: json['hasJoined'] == true || (myTeam != null),
      teamA: teamA,
      teamB: teamB,
      hostTeam: hostTeam,
      guestTeam: guestTeam,
      myTeam: myTeam,
      teamLimit: parseCount(json['teamLimit']),
      notes: json['notes']?.toString(),
      bookingId: JsonUtils.parseIdOrNull(json['bookingId']),
      bookingStatus: json['bookingStatus']?.toString(),
      bookingStart: parseDate(json['bookingStart']),
      bookingEnd: parseDate(json['bookingEnd']),
      cancelledAt: parseDate(json['cancelledAt']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'sportId': sportId,
        if (sportName != null) 'sportName': sportName,
        if (facilityId != null) 'facilityId': facilityId,
        if (facilityName != null) 'facilityName': facilityName,
        if (courtId != null) 'courtId': courtId,
        if (courtName != null) 'courtName': courtName,
        if (desiredStart != null)
          'desiredStart': desiredStart!.toIso8601String(),
        if (desiredEnd != null) 'desiredEnd': desiredEnd!.toIso8601String(),
        if (skillMin != null || skillMax != null)
          'skillRange': {
            if (skillMin != null) 'min': skillMin,
            if (skillMax != null) 'max': skillMax,
          },
        'status': status,
        'visibility': visibility,
        if (mode.isNotEmpty) 'mode': mode,
        if (creatorId != null) 'creatorId': creatorId,
        'participants': participants,
        'participantCount': participantCount,
        if (participantLimit != null) 'participantLimit': participantLimit,
        if (teamSize != null) 'teamSize': teamSize,
        'teamA': teamA,
        'teamB': teamB,
        if (hostTeam != null && !hostTeam!.isEmpty)
          'hostTeam': hostTeam!.toJson(),
        if (guestTeam != null && !guestTeam!.isEmpty)
          'guestTeam': guestTeam!.toJson(),
        if (myTeam != null) 'myTeam': myTeam,
        if (teamLimit != null) 'teamLimit': teamLimit,
        if (notes != null) 'notes': notes,
        if (bookingId != null) 'bookingId': bookingId,
        if (bookingStatus != null) 'bookingStatus': bookingStatus,
        if (bookingStart != null) 'bookingStart': bookingStart!.toIso8601String(),
        if (bookingEnd != null) 'bookingEnd': bookingEnd!.toIso8601String(),
        if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}
