import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ptfm_tracker/activity_mapping.dart';
import 'package:ptfm_tracker/http_api_provider.dart';
import 'package:ptfm_tracker/mapping_dialog.dart';
import 'package:ptfm_tracker/resource.dart';
import 'package:ptfm_tracker/user.dart';
import 'package:ptfm_tracker/tracker_work_log.dart';
import 'package:ptfm_tracker/worklog.dart';

GetIt getIt = GetIt.instance;
const rowIconSize = 20.0;
const rowIconButtonSize = 28.0;
const extEnvironmentConst = 'Azure';
const defaultAzureAreaPathConst = 'tmapy';
const prefsPtfmUserName = 'ptfmUserName';
const prefsPtfmPassword = 'ptfmPassword';
const prefsPtfmOrganization = 'ptfmOrganization';
const prefsTrackerToken = 'trackerToken';
const prefsTrackerBaseUrl = 'trackerBaseUrl';
const prefsAzureAreaPath = 'azureDefaultAreaPath';

void main() {
  if (kReleaseMode) {
    // Don't log anything below warnings in production.
    Logger.root.level = Level.WARNING;
  } else {
    Logger.root.level = Level.ALL;
  }
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  getIt.registerSingleton<HttpApiProvider>(HttpApiProvider());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timetracker 2 PTFM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '7pace Timetracker -> PTFM'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final log = Logger('MyHomePage');
  bool isLoading = false;

  final _loginFormKey = GlobalKey<FormState>();
  final _settingsFormKey = GlobalKey<FormState>();
  final _areaPathFormKey = GlobalKey<FormState>();
  final _periodLengthFormKey = GlobalKey<FormState>();
  final _setCalendarRangeFormKey = GlobalKey<FormState>();
  final _ptfmUserNameController = TextEditingController();
  final _ptfmUserPasswordController = TextEditingController();
  final _ptfmOrganizationController = TextEditingController();
  final _trackerTokenController = TextEditingController();
  final _trackerBaseUrlController = TextEditingController();
  final _azureDefaultAreaPath = TextEditingController();
  final _dateFromTextFieldController = TextEditingController();
  final _dateToTextFieldController = TextEditingController();
  final _areaPathFilterController = TextEditingController();
  final _periodLengthController = TextEditingController();

  final _scrollController = ScrollController();

  String? ptfmUserName;
  String? ptfmPassword;
  String? ptfmOrganization;
  String? trackerToken;
  String? trackerBaseUrl;
  String azureArePath = defaultAzureAreaPathConst;

  late DateTime fromDate;
  late DateTime toDate;

  late String title;

  final HttpApiProvider api = getIt<HttpApiProvider>();

  User? _user;

  List<TrackerWorkLog> _trackerWorkLogs = [];
  final List<TrackerWorkLog> _displayedWorkLogs = [];
  int _totalMhrs = 0;
  int _mappedMhrs = 0;

  List<ActivityMapping> _mappings = [];
  List<Resource> _resources = [];
  Resource? _activeResource;

  late DateFormat shortFormat;
  late DateFormat standardFormat;
  late DateFormat longFormat;

  String? _errorString;
  @override
  void initState() {
    title = widget.title;
    initializeDateFormatting('cs_CZ', null);
    shortFormat = DateFormat.Md('cs_CZ');
    standardFormat = DateFormat.yMd('cs_CZ');
    longFormat = DateFormat.yMEd('cs_CZ');

    fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    toDate = DateTime.now();

    SharedPreferences.getInstance().then((prefs) {
      ptfmUserName = prefs.getString(prefsPtfmUserName) ?? '';
      ptfmPassword = prefs.getString(prefsPtfmPassword) ?? '';
      ptfmOrganization = prefs.getString(prefsPtfmOrganization) ?? '';
      trackerToken = prefs.getString(prefsTrackerToken) ?? '';
      trackerBaseUrl = prefs.getString(prefsTrackerBaseUrl) ?? '';
      azureArePath = prefs.getString(prefsAzureAreaPath) ?? defaultAzureAreaPathConst;

      _login().then((value) {
        setState(() => _user = value);

        if (_user != null) {
          api.getResources(null, ['active']).then((value) {
            setState(() {
              _resources = value;
            });
          }).onError((error, _) {
            setState(() => _errorString = error.toString());
          });
          _reloadMappings();
        } else {
          showDialog(
              context: context,
              builder: (_) => AlertDialog(
                    title: const Text('Login failed'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))
                    ],
                  ));
        }
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    _ptfmUserNameController.dispose();
    _ptfmUserPasswordController.dispose();
    _ptfmOrganizationController.dispose();
    _trackerBaseUrlController.dispose();
    _trackerTokenController.dispose();
    _azureDefaultAreaPath.dispose();
    _dateFromTextFieldController.dispose();
    _dateToTextFieldController.dispose();
    _areaPathFilterController.dispose();
    _periodLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
        actions: [
          DropdownButton<Resource>(
            hint: const Text('Select resource'),
            isDense: true,
            value: _activeResource,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
            items: _resources
                .map<DropdownMenuItem<Resource>>((r) => DropdownMenuItem<Resource>(
                      value: r,
                      child: Text(r.name),
                    ))
                .toList(),
            onChanged: _user != null
                ? (value) {
                    setState(() {
                      _activeResource = value!;
                      isLoading = true;
                    });
                    _reloadAzureWorkLogs().then((value) => setState(() => isLoading = false));
                  }
                : null,
            borderRadius: const BorderRadius.all(Radius.circular(16.0)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: OutlinedButton.icon(
                onPressed: _user != null ? () => _setCalendarRangeDialog(context) : null,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('${shortFormat.format(fromDate)} - ${shortFormat.format(toDate)}')),
          ),
          OutlinedButton.icon(
              onPressed: _user != null ? () => _setAreaPathFilterDialog(context) : null,
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(azureArePath)),
          IconButton(
              tooltip: 'Reload data',
              onPressed: _user != null
                  ? () {
                      _errorString = null;
                      setState(() => isLoading = true);
                      Future.wait([_reloadMappings(), _reloadAzureWorkLogs()])
                          .then((value) => setState(() => isLoading = false));
                    }
                  : null,
              icon: const Icon(Icons.refresh_outlined)),
          IconButton(
              tooltip: 'Azure -> PTFM mapping',
              onPressed: _user != null &&
                      trackerToken != null &&
                      trackerToken!.isNotEmpty &&
                      trackerBaseUrl != null &&
                      trackerBaseUrl!.isNotEmpty
                  ? () async {
                      await _showMappings(context);
                    }
                  : null,
              icon: const Icon(Icons.settings_input_composite_outlined)),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Open settings',
            onPressed: _user != null ? () => _showSettings(context) : null,
          ),
          if (_user == null)
            IconButton(
              icon: const Icon(Icons.login_outlined),
              tooltip: 'Log in',
              onPressed: () {
                ptfmUserName = null;
                ptfmPassword = null;
                ptfmOrganization = null;
                _login().then((value) {
                  setState(() => _user = value);
                  if (_user != null) {
                    api.getResources(null, ['active']).then((value) {
                      setState(() {
                        _resources = value;
                      });
                    }).onError((error, _) {
                      setState(() => _errorString = error.toString());
                    });
                    _reloadMappings();
                  } else {
                    showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                              title: const Text('Login failed'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('OK'))
                              ],
                            ));
                  }
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _displayedWorkLogs.isEmpty && !isLoading
                ? const Center(
                    child: Text('no data'),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1),
                            1: IntrinsicColumnWidth(),
                            2: IntrinsicColumnWidth(),
                            3: FlexColumnWidth(3),
                            4: FlexColumnWidth(3),
                            5: IntrinsicColumnWidth(),
                            6: IntrinsicColumnWidth(),
                            7: IntrinsicColumnWidth(),
                          },
                          border: const TableBorder(horizontalInside: BorderSide(width: 0.1)),
                          children: _getTableRows(context),
                        ),
                      ),
                    ),
                  ),
          ),
          Container(
            color: Theme.of(context).colorScheme.inversePrimary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                      'Total: ${(_totalMhrs / 3600).toStringAsFixed(2)} mhrs, Transferable: ${(_mappedMhrs / 3600).toStringAsFixed(2)} mhrs'),
                ),
                if (_errorString != null)
                  Flexible(
                    child: Text(
                      _errorString!,
                      style: const TextStyle(color: Colors.red),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                IconButton(
                    tooltip: 'Upload data to PTFM',
                    onPressed: _user != null ? () => _evaluateWorklogsUpload(context) : null,
                    icon: const Icon(Icons.send))
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Zobrazí celoobrazovkový dialog nastavení mapování
  Future<void> _showMappings(BuildContext context,
      {String? extCodeToEdit, String? ptfmActCodeToEdit}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MappingDialog(
          trackerToken: trackerToken!,
          trackerBaseUrl: trackerBaseUrl!,
          user: _user,
          extCodeToEdit: extCodeToEdit,
          ptfmActCodeToEdit: ptfmActCodeToEdit,
        ),
        fullscreenDialog: true,
      ),
    );
    setState(() => isLoading = true);
    Future.wait([_reloadMappings(), _reloadAzureWorkLogs()])
        .then((value) => setState(() => isLoading = false));
  }

  /// Vrátí řádky tabulky podle načtených dat
  List<TableRow> _getTableRows(BuildContext context) {
    List<TableRow> rows = [];
    bool isOdd = true;
    for (int i = 0; i < _displayedWorkLogs.length; i++) {
      isOdd = (i == 0 || _displayedWorkLogs[i - 1].shortDate != _displayedWorkLogs[i].shortDate)
          ? !isOdd
          : isOdd;
      List<ActivityMapping> workLogMappings =
          _mappings.where((element) => element.extCode == _displayedWorkLogs[i].areaPath).toList();
      rows.add(
          TableRow(decoration: isOdd ? BoxDecoration(color: Colors.grey[200]) : null, children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: i == 0 || _displayedWorkLogs[i - 1].shortDate != _displayedWorkLogs[i].shortDate
                ? Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: rowIconSize,
                        color: Colors.black26,
                      ),
                      const SizedBox(width: 4.0),
                      Flexible(
                        child: Text(
                          longFormat.format(_displayedWorkLogs[i].shortDate),
                        ),
                      ),
                    ],
                  )
                : Container(),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: InkWell(
            onTap: () => _setPeriodLengthDialog(context, i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text((_displayedWorkLogs[i].periodLength / 3600).toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: InkWell(
            onTap: () async {
              if (ptfmOrganization != null && trackerToken != null && trackerBaseUrl != null) {
                await _showMappings(context,
                    extCodeToEdit: workLogMappings.isNotEmpty
                        ? workLogMappings.first.extCode
                        : _displayedWorkLogs[i].areaPath,
                    ptfmActCodeToEdit:
                        workLogMappings.isNotEmpty ? workLogMappings.first.ptfmActCode : null);
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0, right: 4.0),
              child: workLogMappings.isNotEmpty
                  ? Icon(Icons.check, color: Colors.green[200])
                  : const Tooltip(
                      message: 'Missing PTFM mapping',
                      child: Icon(Icons.error_outline, color: Colors.red)),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(_displayedWorkLogs[i].title),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(_displayedWorkLogs[i].areaPath),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(workLogMappings.isNotEmpty
                ? workLogMappings.map((e) => e.ptfmActCode).join('//')
                : ''),
          ),
        ),
        TableCell(
          child: Tooltip(
            message: 'Move the item to a different area path',
            child: SizedBox(
              width: rowIconButtonSize,
              height: rowIconButtonSize,
              child: IconButton(
                icon: const Icon(
                  Icons.move_down,
                  color: Colors.black26,
                  size: rowIconSize,
                ),
                onPressed: () async {
                  final newAreaPath = await _selectAreaPathDialog(context);
                  if (newAreaPath != null) {
                    setState(() {
                      _displayedWorkLogs[i].areaPath = newAreaPath;
                    });
                  }
                },
                padding: const EdgeInsets.all(0.0),
              ),
            ),
          ),
        ),
        TableCell(
          child: Tooltip(
            message: 'Remove from upload',
            child: SizedBox(
              width: rowIconButtonSize,
              height: rowIconButtonSize,
              child: IconButton(
                icon: const Icon(
                  Icons.close_outlined,
                  color: Colors.black26,
                  size: rowIconSize,
                ),
                onPressed: () {
                  setState(() {
                    _displayedWorkLogs.remove(_displayedWorkLogs[i]);
                    _calcSum();
                  });
                },
                padding: const EdgeInsets.all(0.0),
              ),
            ),
          ),
        ),
      ]));
    }
    return rows;
  }

  Future<User?> _login() async {
    if (ptfmUserName == null ||
        ptfmPassword == null ||
        ptfmOrganization == null ||
        ptfmUserName!.isEmpty ||
        ptfmPassword!.isEmpty ||
        ptfmOrganization!.isEmpty) {
      await _showLoginDialog(context);
    }
    if (ptfmUserName != null &&
        ptfmPassword != null &&
        ptfmOrganization != null &&
        ptfmUserName!.isNotEmpty &&
        ptfmPassword!.isNotEmpty &&
        ptfmOrganization!.isNotEmpty) {
      return api
          .login(
              userName: ptfmUserName!, password: ptfmPassword!, organizationCode: ptfmOrganization)
          .onError((error, _) {
        setState(() => _errorString = error.toString());
        return null;
      });
    }
    return Future.value(null);
  }

  Future _showLoginDialog(BuildContext context) async {
    _ptfmUserNameController.text = ptfmUserName ?? '';
    _ptfmUserPasswordController.text = ptfmPassword ?? '';
    _ptfmOrganizationController.text = ptfmOrganization ?? '';
    await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Login'),
        content: Form(
            key: _loginFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _ptfmUserNameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'PTFM user name'),
                  validator: (value) => value == null || value.isEmpty ? 'Please user name' : null,
                ),
                TextFormField(
                  controller: _ptfmUserPasswordController,
                  decoration: const InputDecoration(labelText: 'PTFM password'),
                  obscureText: true,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter password' : null,
                ),
                TextFormField(
                  controller: _ptfmOrganizationController,
                  decoration: const InputDecoration(labelText: 'PTFM organization code'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter organization code' : null,
                ),
              ],
            )),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop()),
          TextButton(
              child: const Text("Login"),
              onPressed: () async {
                if (_loginFormKey.currentState!.validate()) {
                  final SharedPreferences prefs = await SharedPreferences.getInstance();
                  ptfmUserName = _ptfmUserNameController.text;
                  ptfmPassword = _ptfmUserPasswordController.text;
                  ptfmOrganization = _ptfmOrganizationController.text;

                  prefs.setString(prefsPtfmUserName, ptfmUserName!);
                  prefs.setString(prefsPtfmPassword, ptfmPassword!);
                  prefs.setString(prefsPtfmOrganization, ptfmOrganization!);
                  if (mounted) Navigator.of(context).pop();
                }
              })
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    _ptfmUserNameController.text = ptfmUserName ?? '';
    _ptfmUserPasswordController.text = ptfmPassword ?? '';
    _ptfmOrganizationController.text = ptfmOrganization ?? '';
    _trackerTokenController.text = trackerToken ?? '';
    _trackerBaseUrlController.text = trackerBaseUrl ?? '';
    _azureDefaultAreaPath.text = azureArePath;
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Settings'),
        content: Form(
            key: _settingsFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _ptfmUserNameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'PTFM user name'),
                  validator: (value) => value == null || value.isEmpty ? 'Please user name' : null,
                ),
                TextFormField(
                  controller: _ptfmUserPasswordController,
                  decoration: const InputDecoration(labelText: 'PTFM password'),
                  obscureText: true,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter password' : null,
                ),
                TextFormField(
                  controller: _ptfmOrganizationController,
                  decoration: const InputDecoration(labelText: 'PTFM organization code'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter organization code' : null,
                ),
                TextFormField(
                  controller: _trackerTokenController,
                  decoration: const InputDecoration(labelText: 'Timetracker token'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter token' : null,
                ),
                TextFormField(
                  controller: _trackerBaseUrlController,
                  decoration: const InputDecoration(labelText: 'Timetracker base URL'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter base url' : null,
                ),
                TextFormField(
                  controller: _azureDefaultAreaPath,
                  decoration:
                      const InputDecoration(labelText: '$extEnvironmentConst default area path'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter area path substring' : null,
                  onFieldSubmitted: (value) async {
                    if (_settingsFormKey.currentState!.validate()) {
                      await _onSettingsSubmit();
                      if (mounted) Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            )),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop()),
          TextButton(
              child: const Text("Save"),
              onPressed: () async {
                if (_settingsFormKey.currentState!.validate()) {
                  await _onSettingsSubmit();
                  if (mounted) Navigator.of(context).pop();
                }
              })
        ],
      ),
    );
  }

  Future<void> _onSettingsSubmit() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    ptfmUserName = _ptfmUserNameController.text;
    ptfmPassword = _ptfmUserPasswordController.text;
    ptfmOrganization = _ptfmOrganizationController.text;
    trackerToken = _trackerTokenController.text;
    trackerBaseUrl = _trackerBaseUrlController.text;
    azureArePath = _azureDefaultAreaPath.text;

    prefs.setString(prefsPtfmUserName, ptfmUserName!);
    prefs.setString(prefsPtfmPassword, ptfmPassword!);
    prefs.setString(prefsPtfmOrganization, ptfmOrganization!);
    prefs.setString(prefsTrackerToken, trackerToken!);
    prefs.setString(prefsTrackerBaseUrl, trackerBaseUrl!);
    prefs.setString(prefsAzureAreaPath, azureArePath);

    _login().then((value) {
      _activeResource = null;
      setState(() => _user = value);
      if (_user != null) {
        api.getResources(null, ['active']).then((value) {
          setState(() {
            _resources = value;
          });
        }).onError((error, _) {
          setState(() => _errorString = error.toString());
        });
        setState(() => isLoading = true);
        Future.wait([_reloadMappings(), _reloadAzureWorkLogs()])
            .then((value) => setState(() => isLoading = false));
      } else {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: const Text('Login failed'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))
                  ],
                ));
      }
    });
  }

  /// Vrátí dialog nastavení rozsahu kalendáře
  Future _setCalendarRangeDialog(BuildContext context) async {
    _dateFromTextFieldController.text = standardFormat.format(fromDate);
    _dateToTextFieldController.text = standardFormat.format(toDate);

    await showDialog(
        context: context,
        builder: (newContext) {
          return AlertDialog(
            title: const Text('Set calendar range'),
            content: Form(
              key: _setCalendarRangeFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _dateFromTextFieldController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.event),
                      labelText: 'Date from',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'can\'t be empty';
                      }
                      try {
                        standardFormat.parse(value);
                      } on FormatException catch (_) {
                        return 'incorrect format';
                      }
                      return null;
                    },
                    onTap: () async {
                      final date = await showDatePicker(
                          context: newContext,
                          initialDate: fromDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100));
                      if (date != null) {
                        _dateFromTextFieldController.text = standardFormat.format(date);
                      }
                    },
                  ),
                  TextFormField(
                    controller: _dateToTextFieldController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.event),
                      labelText: 'Date to',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'can\'t be empty';
                      }
                      try {
                        standardFormat.parse(value);
                      } on FormatException catch (_) {
                        return 'incorrect format';
                      }
                      return null;
                    },
                    onTap: () async {
                      final date = await showDatePicker(
                          context: newContext,
                          initialDate: toDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100));
                      if (date != null) {
                        _dateToTextFieldController.text = standardFormat.format(date);
                      }
                    },
                    onFieldSubmitted: (value) {
                      if (_setCalendarRangeFormKey.currentState!.validate()) {
                        setState(() {
                          fromDate = standardFormat.parse(_dateFromTextFieldController.text);
                          toDate = standardFormat.parse(_dateToTextFieldController.text);
                          isLoading = true;
                        });
                        _reloadAzureWorkLogs().then((value) => setState(() => isLoading = false));
                        Navigator.of(newContext).pop(true);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(newContext).pop();
                  },
                  child: const Text('Close')),
              TextButton(
                onPressed: () {
                  if (_setCalendarRangeFormKey.currentState!.validate()) {
                    setState(() {
                      fromDate = standardFormat.parse(_dateFromTextFieldController.text);
                      toDate = standardFormat.parse(_dateToTextFieldController.text);
                      isLoading = true;
                    });
                    _reloadAzureWorkLogs().then((value) => setState(() => isLoading = false));
                    Navigator.of(newContext).pop(true);
                  }
                },
                child: const Text('Set'),
              )
            ],
          );
        });
  }

  Future _reloadMappings() {
    return api.getMappings(extEnvironmentConst).then((value) {
      _mappings = value;
    }).onError((error, _) {
      setState(() => _errorString = error.toString());
    });
  }

  /// Načte vykázané položky přihlášeného uživatele
  Future _reloadAzureWorkLogs() {
    _displayedWorkLogs.clear();
    if (trackerToken != null &&
        trackerToken!.isNotEmpty &&
        trackerBaseUrl != null &&
        trackerBaseUrl!.isNotEmpty &&
        _activeResource != null) {
      return api
          .getWorkLogs(
              from: fromDate,
              to: toDate.add(const Duration(days: 1)),
              email: _activeResource!.contact,
              token: trackerToken,
              trackerBaseUrl: trackerBaseUrl)
          .then((value) {
        _trackerWorkLogs = value;
        for (final tw in _trackerWorkLogs) {
          if (tw.areaPath.contains(azureArePath)) {
            _displayedWorkLogs.add(tw);
          }
        }
        _calcSum();
      });
    }
    return Future.value();
  }

  void _calcSum() {
    _totalMhrs = 0;
    _mappedMhrs = 0;
    for (final wl in _displayedWorkLogs) {
      _totalMhrs += wl.periodLength;
      if (_mappings
          .where((element) =>
              element.extCode == wl.areaPath && element.extEnvironment == extEnvironmentConst)
          .isNotEmpty) {
        _mappedMhrs += wl.periodLength;
      }
    }
  }

  /// Vyhodnocení hodin před nahráním
  _evaluateWorklogsUpload(BuildContext context) async {
    var mappedSum = 0;
    var missingMappings = false;
    for (int i = 0; i < _displayedWorkLogs.length; i++) {
      List<ActivityMapping> areaCode =
          _mappings.where((element) => element.extCode == _displayedWorkLogs[i].areaPath).toList();
      //TODO: ještě ošetřit na přítomnost Activit v PTFM!!!
      if (areaCode.isNotEmpty) {
        mappedSum += _displayedWorkLogs[i].periodLength;
      } else {
        missingMappings = true;
      }
    }

    if (missingMappings) {
      final result = await showDialog(
          context: context,
          builder: (newContext) => _missingMappingsAlertDialog(context, mappedSum));
      if (result != null && result == true) {
        _uploadWorklogs().then((value) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$value worklogs saved')),
            ));
      }
    } else {
      final result = await showDialog(
          context: context, builder: (newContext) => _confirmUploadDialog(context));
      if (result != null && result == true) {
        _uploadWorklogs().then((value) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$value worklogs saved')),
            ));
      }
    }
  }

  /// Samotné nahrání hodin do PTFM
  Future<int> _uploadWorklogs() async {
    //Záznamy musíme vysčítat za jednotlivé dny
    Map<DateTime, Worklog> logs = {};
    if (ptfmOrganization != null && _activeResource != null) {
      for (int i = 0; i < _displayedWorkLogs.length; i++) {
        List<ActivityMapping> areaMappings = _mappings
            .where((element) => element.extCode == _displayedWorkLogs[i].areaPath)
            .toList();
        //TODO: ještě ošetřit na přítomnost Activit v PTFM!!!
        for (final m in areaMappings) {
          if (m.ptfmActCode != null) {
            if (logs.containsKey(_displayedWorkLogs[i].shortDate)) {
              //z počtu minut uděláme desetinné číslo v hodinách, vynásobíme multiplikátorem a zaokrouhlíme na 2 desetinná místa
              logs[_displayedWorkLogs[i].shortDate]!.manHours += double.parse(
                  ((_displayedWorkLogs[i].periodLength / 3600) * m.ratio).toStringAsFixed(2));
            } else {
              logs[_displayedWorkLogs[i].shortDate] = Worklog(
                  date: _displayedWorkLogs[i].shortDate,
                  activityCode: m.ptfmActCode!,
                  resourceCode: _activeResource!.code,
                  manHours: double.parse(
                      ((_displayedWorkLogs[i].periodLength / 3600) * m.ratio).toStringAsFixed(2)));
            }
          }
        }
      }
      return api.insertWorklogs(logs.values.toList()).onError((error, _) {
        setState(() => _errorString = error.toString());
        return 0;
      });
    }
    return 0;
  }

  /// Vrátí dialog nastavení množství odpracovaných hodin v položce worklog
  Future _setPeriodLengthDialog(BuildContext context, int index) async {
    _periodLengthController.text =
        (_displayedWorkLogs[index].periodLength / 3600).toStringAsFixed(2);
    await showDialog(
        context: context,
        builder: (newContext) {
          return AlertDialog(
            title: const Text('Set new duration'),
            content: Form(
              key: _periodLengthFormKey,
              child: TextFormField(
                  controller: _periodLengthController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.timelapse_outlined),
                    labelText: 'work job duration',
                  ),
                  autofocus: true,
                  onFieldSubmitted: (value) {
                    if (_periodLengthFormKey.currentState!.validate()) {
                      setState(() {
                        _displayedWorkLogs[index].periodLength =
                            (double.parse(_periodLengthController.text) * 3600).round();
                      });
                      Navigator.of(newContext).pop(true);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty || double.tryParse(value) == null) {
                      return 'please enter correct value';
                    }
                    return null;
                  }),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(newContext).pop();
                  },
                  child: const Text('Close')),
              TextButton(
                onPressed: () {
                  if (_periodLengthFormKey.currentState!.validate()) {
                    setState(() {
                      _displayedWorkLogs[index].periodLength =
                          (double.parse(_periodLengthController.text) * 3600).round();
                    });
                    Navigator.of(newContext).pop(true);
                  }
                },
                child: const Text('Set'),
              )
            ],
          );
        });
  }

  /// Dialog potvrzení nahrání záznamů
  AlertDialog _confirmUploadDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload worklogs?'),
      content: Text(
          'Do you realy want to upload ${(_totalMhrs / 3600).toStringAsFixed(2)} hours of worklogs?'),
      actions: <Widget>[
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('No')),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: const Text('Yes'),
        )
      ],
    );
  }

  /// Dialog potvrzení nahrání záznamů v případě, že neexistují všechna mapování
  Widget _missingMappingsAlertDialog(BuildContext context, int mappedSum) {
    return AlertDialog(
      icon: const Icon(Icons.warning),
      iconColor: Theme.of(context).colorScheme.error,
      title: const Text('Missing mappings!'),
      content: Text(
          'There are some $extEnvironmentConst worklogs without PFTM mapping. Do you realy want to upload just ${(mappedSum / 3600).toStringAsFixed(2)} hours of worklogs with mapping?'),
      actions: <Widget>[
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('No')),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: const Text('Yes'),
        )
      ],
    );
  }

  /// Vrátí dialog nastavení filtru arePath
  Future _setAreaPathFilterDialog(BuildContext context) async {
    _areaPathFilterController.text = azureArePath;
    await showDialog(
        context: context,
        builder: (newContext) {
          return AlertDialog(
            title: const Text('Set area path filter'),
            content: Form(
              key: _areaPathFormKey,
              child: TextFormField(
                controller: _areaPathFilterController,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.category_outlined),
                  labelText: 'Area path substring',
                  suffixIcon: InkWell(
                    child: const Icon(Icons.close),
                    onTap: () => SharedPreferences.getInstance().then((value) => {
                          _areaPathFilterController.text =
                              value.getString(prefsAzureAreaPath) ?? defaultAzureAreaPathConst
                        }),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'can\'t be empty';
                  }
                  return null;
                },
                onFieldSubmitted: (value) {
                  if (_areaPathFormKey.currentState!.validate()) {
                    setState(() {
                      azureArePath = _areaPathFilterController.text;
                      isLoading = true;
                    });
                    _reloadAzureWorkLogs().then((value) => setState(() => isLoading = false));
                    Navigator.of(newContext).pop(true);
                  }
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(newContext).pop();
                  },
                  child: const Text('Close')),
              TextButton(
                onPressed: () {
                  if (_areaPathFormKey.currentState!.validate()) {
                    setState(() {
                      azureArePath = _areaPathFilterController.text;
                      isLoading = true;
                    });
                    _reloadAzureWorkLogs().then((value) => setState(() => isLoading = false));
                    Navigator.of(newContext).pop(true);
                  }
                },
                child: const Text('Set'),
              )
            ],
          );
        });
  }

  Future _selectAreaPathDialog(BuildContext context) {
    _mappings.sortBy((element) => element.extCode);
    return showDialog(
        context: context,
        builder: (newContext) {
          return SimpleDialog(
            title: const Text('Select area path'),
            children: _mappings
                .map((m) => SimpleDialogOption(
                      child: Text(m.extCode),
                      onPressed: () {
                        Navigator.pop(context, m.extCode);
                      },
                    ))
                .toList(),
          );
        });
  }
}
