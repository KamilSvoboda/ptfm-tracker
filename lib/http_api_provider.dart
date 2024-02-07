import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:ptfm_tracker/activity.dart';
import 'package:ptfm_tracker/activity_mapping.dart';
import 'package:ptfm_tracker/resource.dart';
import 'package:ptfm_tracker/worklog.dart';
import 'package:ptfm_tracker/user.dart';
import 'package:ptfm_tracker/tracker_work_item.dart';
import 'package:ptfm_tracker/tracker_work_log.dart';

///
/// HTTP API provider
/// see https://restfulapi.net/http-status-codes/
///
class HttpApiProvider {
  final log = Logger('HttpApiProvider');
  final loginTimeout = const Duration(seconds: 10);
  final shortRequestTimeout = const Duration(seconds: 10);
  final longRequestTimeout = const Duration(seconds: 30);

  //final String ptfmServerName = "localhost:7292";
  final String ptfmServerName = "www.manager.technology";

  static const String ptfmLoginPath = "api/v1/login";
  static const String ptfmWorklogsPath = "api/v1/worklogs";
  static const String ptfmActivitiesPath = "api/v1/activities";
  static const String ptfmResourcesPath = "api/v1/resources";
  static const String ptfmMappingsPath = "api/v1/ActivityMappings";
  static const String trackerWorkLogWorkItemsPath = "api/odata/v3.2/workLogsWorkItems";
  static const String trakcerWorkItemsPath = "api/odata/v3.2/workItems";

  static const String stateParam = 'state';
  static const String workspaceParam = 'workspace';

  String? _ptfmToken;

  /// Společné hlavičky requestu
  final _headers = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };

  /// Přihlásí uživatele - povinné je jméno a heslo. Volitelně pak organizace při přihlašování do konkrétní organizace
  Future<User?> login(
      {required String userName, required String password, String? organizationCode}) async {
    final uri = Uri.https(ptfmServerName, ptfmLoginPath);
    log.finest(uri.toString());
    final body =
        json.encode({'userName': userName, 'password': password, 'organization': organizationCode});
    final response =
        await http.post(uri, headers: _headers, body: body).timeout(longRequestTimeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final parsedResponse = UserLoginResponse.fromJson(jsonDecode(response.body));
      _ptfmToken = 'Bearer ${parsedResponse.jwtToken}';
      log.info('user ${parsedResponse.user.userName} logged in PTFM');
      return parsedResponse.user;
    } else {
      log.shout(
          '${response.statusCode} ${response.reasonPhrase}: ${response.request?.method.toString()} - ${response.request?.url.toString()}');
    }
    return null;
  }

  ///Vrátí mapování aktivit do externích prostředí
  Future<List<ActivityMapping>> getMappings(String? environment) async {
    if (_ptfmToken != null) {
      _headers[HttpHeaders.authorizationHeader] = _ptfmToken!;
      Map<String, dynamic>? queryParameters = {};
      if (environment != null) queryParameters['extEnvironment'] = environment;
      final uri = Uri.https(ptfmServerName, ptfmMappingsPath, queryParameters);
      log.finest(uri.toString());
      final response = await http.get(uri, headers: _headers).timeout(shortRequestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        var list = json.decode(response.body) as List;
        log.info('${list.length} records of activity mapping loaded');
        return list.map((i) => ActivityMapping.fromJson(i)).toList();
      } else {
        log.shout(
            '${response.statusCode} ${response.reasonPhrase}: ${response.request?.method.toString()} - ${response.request?.url.toString()}');
      }
    } else {
      log.shout('not logged in PTFM!');
    }
    return [];
  }

  Future<int> insertActivityMappings(List<ActivityMapping> mappings) async {
    final start = DateTime.now();
    if (_ptfmToken != null) {
      _headers[HttpHeaders.authorizationHeader] = _ptfmToken!;
      final uri = Uri.https(ptfmServerName, ptfmMappingsPath);
      log.finest(uri.toString());
      final body = json.encode(mappings);
      final response =
          await http.post(uri, headers: _headers, body: body).timeout(shortRequestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        log.finest(
            'insertActivityMappings request time: ${DateTime.now().difference(start).inMilliseconds}ms');
        return json.decode(response.body);
      } else {
        log.shout(
            '${response.statusCode} ${response.reasonPhrase}: ${response.request?.method.toString()} - ${response.request?.url.toString()}');
      }
    } else {
      log.shout('not logged in PTFM!');
    }
    return 0;
  }

  Future<int> deleteActivityMappings(List<ActivityMapping> mappings) async {
    final start = DateTime.now();
    if (_ptfmToken != null) {
      _headers[HttpHeaders.authorizationHeader] = _ptfmToken!;
      final uri = Uri.https(ptfmServerName, ptfmMappingsPath);
      log.finest(uri.toString());
      final bodyJson = json.encode(mappings);
      final response =
          await http.delete(uri, headers: _headers, body: bodyJson).timeout(shortRequestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        log.finest(
            'deleteActivityMappings request time: ${DateTime.now().difference(start).inMilliseconds}ms');
        return 1;
      } else {
        log.shout(
            '${response.statusCode} ${response.reasonPhrase}: ${response.request?.method.toString()} - ${response.request?.url.toString()}');
      }
    } else {
      log.shout('not logged in PTFM!');
    }
    return 0;
  }

  ///Vrátí zdroje organizace
  ///[workspace] filtr zdrojů, které patří do předaného workspace
  ///[state] filtr zdrojů, které mají hodnotu state pole předané hodnoty
  Future<List<Resource>> getResources(String? workspace, List<String>? state) async {
    if (_ptfmToken != null) {
      _headers[HttpHeaders.authorizationHeader] = _ptfmToken!;
      Map<String, dynamic>? queryParameters = {};
      if (workspace != null) queryParameters[workspaceParam] = workspace;
      if (state != null) queryParameters[stateParam] = state;
      final uri = Uri.https(ptfmServerName, ptfmResourcesPath, queryParameters);

      final response = await http.get(uri, headers: _headers).timeout(shortRequestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        var list = json.decode(response.body) as List;
        log.info('${list.length} records of resource loaded');
        return list.map((i) => Resource.fromJson(i)).toList();
      } else {
        log.shout(
            '${response.statusCode} ${response.reasonPhrase}: ${response.request?.method.toString()} - ${response.request?.url.toString()}');
      }
    }
    return [];
  }

  ///Vrátí aktivity organizace
  ///[workspace] filtr aktivit, které patří do předaného workspace
  ///[state] filtr aktivit, které mají hodnotu state podle předané hodnoty
  Future<List<Activity>> getActivities(String? workspace, List<String>? states) async {
    if (_ptfmToken != null) {
      _headers[HttpHeaders.authorizationHeader] = _ptfmToken!;
      Map<String, dynamic>? queryParameters = {};
      if (workspace != null) queryParameters[workspaceParam] = workspace;
      if (states != null) queryParameters[stateParam] = states;
      final uri = Uri.https(ptfmServerName, ptfmActivitiesPath, queryParameters);
      log.finest(uri.toString());
      final response = await http.get(uri, headers: _headers).timeout(shortRequestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        var list = json.decode(response.body) as List;
        log.info('${list.length} records of activity loaded');
        return list.map((i) => Activity.fromJson(i)).toList();
      } else {
        log.shout(
            '${response.statusCode} ${response.reasonPhrase}: ${response.request?.method.toString()} - ${response.request?.url.toString()}');
      }
    } else {
      log.shout('not logged in PTFM!');
    }
    return [];
  }

  /// Vrátí pracovní položky, na které je možné vykazovat - resp. výčet areaPath (agregace všech položek)
  Future<List<TrackerWorkItem>> getWorkItems(
      {String? arePathFilter, required String? token, required String? trackerBaseUrl}) async {
    if (token != null && trackerBaseUrl != null) {
      _headers[HttpHeaders.authorizationHeader] = 'Basic ${base64Encode(utf8.encode(':$token'))}';
      Map<String, dynamic>? queryParameters = {};
      //filter(System_State ne 'Closed' and System_State ne 'Resolved' and contains(System_AreaPath, 'tmapy\IZS'))/groupby((System_AreaPath))
      queryParameters['\$apply'] =
          'filter(System_State ne \'Closed\' and System_State ne \'Resolved\' and contains(System_AreaPath, \'${arePathFilter ?? ''}\'))/groupby((System_AreaPath))';
      queryParameters['\$orderby'] = 'System_AreaPath asc';

      final uri = Uri.https(trackerBaseUrl, trakcerWorkItemsPath, queryParameters);
      log.finest(uri.toString());
      final response = await http.get(uri, headers: _headers).timeout(longRequestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonBody = json.decode(response.body);
        final entries = jsonBody['value'] as List;
        log.info('${entries.length} records of workitem loaded');
        return entries.map((i) => TrackerWorkItem.fromJson(i)).toList();
      } else {
        log.shout(
            '${response.statusCode} ${response.reasonPhrase}: ${response.request?.method.toString()} - ${response.request?.url.toString()}');
      }
    }
    return [];
  }

  ///Vrátí záznamy práce z Timetrakeru
  ///[email] e-mail uživatele Azure
  ///[token] token 7pace Timetracker
  ///[trackerBaseUrl] základní URL 7pace Timetracker
  Future<List<TrackerWorkLog>> getWorkLogs(
      {required DateTime from,
      required DateTime to,
      required String? email,
      required String? token,
      required String? trackerBaseUrl}) async {
    if (email != null && token != null && trackerBaseUrl != null) {
      _headers[HttpHeaders.authorizationHeader] = 'Basic ${base64Encode(utf8.encode(':$token'))}';

      final df = DateFormat('yyyy-MM-dd');
      Map<String, dynamic>? queryParameters = {};
      queryParameters['\$apply'] =
          'filter(Timestamp ge ${df.format(from)} and Timestamp lt ${df.format(to)} and User/Email eq \'$email\')/groupby((User/Email,WorklogDate/ShortDate,WorkItem/System_AreaPath,WorkItem/System_Title),aggregate(PeriodLength with sum as PeriodLength))';
      queryParameters['\$orderby'] = 'WorklogDate/ShortDate asc';

      final uri = Uri.https(trackerBaseUrl, trackerWorkLogWorkItemsPath, queryParameters);
      log.finest(uri.toString());
      final response = await http.get(uri, headers: _headers).timeout(longRequestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonBody = json.decode(response.body);
        final entries = jsonBody['value'] as List;
        log.info('${entries.length} records of worklog loaded');
        return entries.map((i) => TrackerWorkLog.fromJson(i)).toList();
      } else {
        log.shout(
            '${response.statusCode} ${response.reasonPhrase}: ${response.request?.method.toString()} - ${response.request?.url.toString()}');
      }
    }
    return [];
  }

  ///Uloží, nebo aktualizuje seznam výkazů práce
  Future<int> insertWorklogs(List<Worklog> worklogs) async {
    if (_ptfmToken != null) {
      _headers[HttpHeaders.authorizationHeader] = _ptfmToken!;
      final uri = Uri.https(ptfmServerName, ptfmWorklogsPath);
      log.finest(uri.toString());
      final body = json.encode(worklogs);
      final response =
          await http.post(uri, headers: _headers, body: body).timeout(shortRequestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        log.shout(
            '${response.statusCode} ${response.reasonPhrase}: ${response.request?.method.toString()} - ${response.request?.url.toString()}');
      }
    } else {
      log.shout('not logged in PTFM!');
    }
    return 0;
  }
}

class UserLoginResponse {
  final String jwtToken;
  final User user;
  const UserLoginResponse({required this.jwtToken, required this.user});
  factory UserLoginResponse.fromJson(Map<String, dynamic> json) {
    return UserLoginResponse(
      jwtToken: json['token'] as String,
      user: User.fromJson(json['user']),
    );
  }
}
