import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/incident_draft.dart';

/// Stores an editable report and its reserved submission ID per project and UID.
class IncidentDraftStore {
  final String projectId;
  final SharedPreferencesAsync _preferences;

  IncidentDraftStore({
    required this.projectId,
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  String _key(String uid) => 'campusfix.incidentDraft.v1.$projectId.$uid';

  Future<({IncidentDraft draft, String? submissionId, bool pending})?> read(
    String uid,
  ) async {
    final raw = await _preferences.getString(_key(uid));
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> ||
        data['title'] is! String ||
        data['description'] is! String ||
        data['location'] is! String ||
        (data['categoryId'] != null && data['categoryId'] is! String) ||
        (data['submissionId'] != null && data['submissionId'] is! String) ||
        data['pending'] is! bool ||
        (data['pending'] == true &&
            (data['submissionId'] == null || data['categoryId'] == null))) {
      throw const FormatException('The stored report draft is invalid.');
    }
    return (
      draft: IncidentDraft(
        title: data['title'] as String,
        description: data['description'] as String,
        location: data['location'] as String,
        categoryId: data['categoryId'] as String?,
      ),
      submissionId: data['submissionId'] as String?,
      pending: data['pending'] as bool,
    );
  }

  Future<void> write(
    String uid,
    IncidentDraft draft, {
    required String? submissionId,
    required bool pending,
  }) => _preferences.setString(
    _key(uid),
    jsonEncode({
      'title': draft.title,
      'description': draft.description,
      'location': draft.location,
      'categoryId': draft.categoryId,
      'submissionId': submissionId,
      'pending': pending,
    }),
  );

  Future<void> clear(String uid) => _preferences.remove(_key(uid));
}
