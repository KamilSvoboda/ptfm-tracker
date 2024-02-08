import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ptfm_tracker/activity.dart';
import 'package:ptfm_tracker/activity_mapping.dart';
import 'package:ptfm_tracker/http_api_provider.dart';

import 'package:ptfm_tracker/main.dart';
import 'package:ptfm_tracker/user.dart';
import 'package:ptfm_tracker/tracker_work_item.dart';

class MappingDialog extends StatefulWidget {
  final String trackerToken;
  final String trackerBaseUrl;
  final User? user;
  final String? extCodeToEdit;
  final String? activityCodeToEdit;
  final String selectedExtEnvironment;

  const MappingDialog(
      {super.key,
      required this.trackerToken,
      required this.trackerBaseUrl,
      required this.user,
      required this.selectedExtEnvironment,
      this.extCodeToEdit,
      this.activityCodeToEdit});
  @override
  State<MappingDialog> createState() => _MappingDialogState();
}

class _MappingDialogState extends State<MappingDialog> {
  static const rolePowerUser = 'poweruser';
  static const roleManager = 'manager';

  bool isLoading = false;

  final HttpApiProvider api = getIt<HttpApiProvider>();

  List<ActivityMapping> _mappings = [];
  List<Activity> _activities = [];
  List<TrackerWorkItem> _workItems = [];

  final List<ActivityMapping> _displayedMappings = [];

  String _extCodeFiterString = defaultAzureAreaPathConst;

  String? _errorString;

  final _formKey = GlobalKey<FormState>();
  final _ptfmCodeController = TextEditingController();
  final _extCodeController = TextEditingController();
  final _mappingRatioController = TextEditingController();

  final _extCodeFilterController = TextEditingController();
  final _mappingExtEnvController = TextEditingController();

  @override
  void initState() {
    isLoading = true;
    try {
      Future.wait([
        api.getMappings(widget.selectedExtEnvironment).then((value) {
          _mappings = value;
          //otevření dialog editace mapování ze základní obrazovky
          if (widget.extCodeToEdit != null) {
            //zkusíme mapování najít mezi již existujícími
            final m = _mappings.firstWhereOrNull((element) =>
                element.extCode == widget.extCodeToEdit &&
                element.extEnvironment == widget.selectedExtEnvironment &&
                element.activityCode == widget.activityCodeToEdit);
            _showInsertUpdateDialog(context, editedMapping: m);
          }
          return _mappings.sort((a, b) => a.extCode.compareTo(b.extCode));
        }).onError((error, _) {
          setState(() => _errorString = error.toString());
        }),
        SharedPreferences.getInstance().then((value) {
          _extCodeFiterString = value.getString(prefsAzureAreaPath) ?? defaultAzureAreaPathConst;
        }),
        api.getActivities(null, ['proposal', 'inprogress']).then((value) {
          _activities = value;
          return _activities.sort(((a, b) => a.name.compareTo(b.name)));
        }).onError((error, _) {
          setState(() => _errorString = error.toString());
        })
      ]).then((value) {
        api
            .getWorkItems(
                arePathFilter: _extCodeFiterString,
                token: widget.trackerToken,
                trackerBaseUrl: widget.trackerBaseUrl)
            .then((value) {
          _workItems = value;
          setState(() {
            _joinWorkItemsAndMappings();
            isLoading = false;
          });
        });
      });
    } catch (e) {
      setState(() {
        _errorString = e.toString();
        isLoading = false;
      });
    }

    super.initState();
  }

  @override
  void dispose() {
    _ptfmCodeController.dispose();
    _extCodeController.dispose();
    _extCodeFilterController.dispose();
    _mappingRatioController.dispose();
    _mappingExtEnvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.selectedExtEnvironment} -> PTFM mappings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: OutlinedButton.icon(
                onPressed: () => _setAreaPathFilterDialog(context),
                icon: const Icon(Icons.filter_alt_outlined),
                label: Text(_extCodeFiterString)),
          ),
          IconButton(
              tooltip: 'Save as new environment',
              onPressed: () => _saveAsNewEnvDialog(context),
              icon: Icon(Icons.save_as_outlined)),
        ],
      ),
      body: Column(
        children: [
          if (isLoading) const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: IntrinsicColumnWidth(),
                    2: IntrinsicColumnWidth(),
                    3: FlexColumnWidth(1),
                    4: IntrinsicColumnWidth(),
                    5: IntrinsicColumnWidth()
                  },
                  border: const TableBorder(horizontalInside: BorderSide(width: 0.1)),
                  children: _getTableRows(context),
                ),
              ),
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.inversePrimary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_errorString != null)
                  Flexible(
                    child: Text(
                      _errorString!,
                      style: const TextStyle(color: Colors.red),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (userIsEditor)
                  IconButton(
                      tooltip: 'Add mapping',
                      onPressed: () => _showInsertUpdateDialog(context),
                      icon: const Icon(Icons.add_outlined)),
              ],
            ),
          ),
        ],
      ), //
    );
  }

  /// Vrátí řádky tabulky podle načtených dat
  List<TableRow> _getTableRows(BuildContext context) {
    List<TableRow> rows = [];
    bool isOdd = true;
    for (int i = 0; i < _displayedMappings.length; i++) {
      isOdd = !isOdd;
      final act = _activities
          .firstWhereOrNull((element) => element.code == _displayedMappings[i].activityCode);
      rows.add(
          TableRow(decoration: isOdd ? BoxDecoration(color: Colors.grey[200]) : null, children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Icon(Icons.category_outlined, size: rowIconSize, color: Colors.black26),
                const SizedBox(width: 4.0),
                Flexible(
                    child: Text(_displayedMappings[i].extCode,
                        style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: _displayedMappings[i].ratio != 1
              ? Text('x ${_displayedMappings[i].ratio.toStringAsFixed(2)}',
                  style:
                      Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold))
              : Container(),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: InkWell(
            onTap: () => _showInsertUpdateDialog(context, editedMapping: _displayedMappings[i]),
            child: const SizedBox(
              width: rowIconButtonSize,
              child: Icon(
                Icons.chevron_right_outlined,
                color: Colors.black26,
                size: rowIconSize,
              ),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: act != null
                ? Text('${act.group} / ${act.name} [${act.code}]',
                    style: Theme.of(context).textTheme.bodyMedium)
                : Container(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_displayedMappings[i].activityCode != null)
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                          ),
                        Text(_displayedMappings[i].activityCode ?? ''),
                      ],
                    ),
                  ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: userIsEditor && _displayedMappings[i].activityCode != null
              ? Tooltip(
                  message: 'Edit/Copy ${_displayedMappings[i].extCode} mapping',
                  child: SizedBox(
                    width: rowIconButtonSize,
                    height: rowIconButtonSize,
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: rowIconSize,
                      ),
                      onPressed: () {
                        _showInsertUpdateDialog(context, editedMapping: _displayedMappings[i]);
                      },
                      padding: const EdgeInsets.all(0.0),
                    ),
                  ),
                )
              : Container(),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: userIsEditor && _displayedMappings[i].activityCode != null
              ? Tooltip(
                  message: 'Delete ${_displayedMappings[i].extCode} mapping',
                  child: SizedBox(
                    width: rowIconButtonSize,
                    height: rowIconButtonSize,
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete_forever_outlined,
                        size: rowIconSize,
                      ),
                      onPressed: () async {
                        final res = await showDialog(
                            context: context,
                            builder: (c) {
                              return AlertDialog(
                                title: const Text('Delete mapping?'),
                                content: Text(
                                    'Do you really want to delete \'${_displayedMappings[i].activityCode}\' mapping?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('No')),
                                  TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Yes')),
                                ],
                              );
                            });
                        if (res != null && res) {
                          api.deleteActivityMappings([_displayedMappings[i]]).onError((error, _) {
                            setState(() => _errorString = error.toString());
                            return -1;
                          });
                          setState(() {
                            _mappings.remove(_displayedMappings[i]);
                            _joinWorkItemsAndMappings();
                          });
                        }
                      },
                      padding: const EdgeInsets.all(0.0),
                    ),
                  ),
                )
              : _displayedMappings[i].activityCode == null
                  ?
                  //pokud není známé mapování, tak v posledním sloupci zobrazíme ikonu pro vložení/editaci
                  Tooltip(
                      message: 'Insert ${_displayedMappings[i].extCode} mapping',
                      child: SizedBox(
                        width: rowIconButtonSize,
                        height: rowIconButtonSize,
                        child: IconButton(
                          icon: const Icon(
                            Icons.add_outlined,
                            size: rowIconSize,
                          ),
                          onPressed: () {
                            _showInsertUpdateDialog(context, editedMapping: _displayedMappings[i]);
                          },
                          padding: const EdgeInsets.all(0.0),
                        ),
                      ),
                    )
                  : Container(),
        ),
      ]));
    }
    return rows;
  }

  /// Připojí načtené AreaPath z Azure do existujích mappings jako "prázdné" mapování
  void _joinWorkItemsAndMappings() {
    _displayedMappings.clear();
    for (final ma in _mappings) {
      if (ma.extCode.contains(_extCodeFiterString)) {
        _displayedMappings.add(ma);
      }
    }
    for (final wi in _workItems) {
      //pokud načtenou areaPath nenajdeme mezi existujícím mapováním, tak ji přidáme jako mapování bez vazby
      if (_displayedMappings.firstWhereOrNull((element) =>
              element.extEnvironment == widget.selectedExtEnvironment &&
              element.extCode == wi.areaPath) ==
          null) {
        _displayedMappings.add(
            ActivityMapping(extCode: wi.areaPath, extEnvironment: widget.selectedExtEnvironment));
      }
    }
  }

  bool get userIsEditor =>
      widget.user != null &&
      widget.user!.roles != null &&
      (widget.user!.roles!.contains(roleManager) || widget.user!.roles!.contains(rolePowerUser));

  void _showInsertUpdateDialog(BuildContext context, {ActivityMapping? editedMapping}) {
    _extCodeController.text = editedMapping?.extCode ?? '';
    _ptfmCodeController.text = editedMapping?.activityCode ?? '';
    _mappingRatioController.text = editedMapping?.ratio.toString() ?? '1.0';
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Mapping'),
        content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _extCodeController,
                  decoration: const InputDecoration(
                      labelText: 'External code',
                      floatingLabelBehavior: FloatingLabelBehavior.auto),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter external code' : null,
                ),
                TextFormField(
                  controller: _ptfmCodeController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'PTFM activity code',
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    isDense: true,
                    suffixIcon: InkWell(
                        onTap: () async {
                          final activityCode = await _selectActivityDialog(context);
                          if (activityCode != null) {
                            _ptfmCodeController.text = activityCode;
                          }
                        },
                        child: const Icon(Icons.search_outlined)),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Please enter PTFM code' : null,
                  onFieldSubmitted: (value) {
                    if (_formKey.currentState!.validate()) {
                      _onUpdateDialogSubmitted(editedMapping: editedMapping);
                      Navigator.of(context).pop();
                    }
                  },
                ),
                TextFormField(
                  controller: _mappingRatioController,
                  decoration: const InputDecoration(
                    labelText: 'Ratio',
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    isDense: true,
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty || double.tryParse(value) == null
                          ? 'Enter a value in the range 0.0 - 1.0'
                          : null,
                  onFieldSubmitted: (value) {
                    if (_formKey.currentState!.validate()) {
                      _onUpdateDialogSubmitted(editedMapping: editedMapping);
                      Navigator.of(context).pop();
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
                if (_formKey.currentState!.validate()) {
                  _onUpdateDialogSubmitted(editedMapping: editedMapping);
                  Navigator.of(context).pop();
                }
              })
        ],
      ),
    );
  }

  void _onUpdateDialogSubmitted({ActivityMapping? editedMapping}) async {
    if (editedMapping != null) {
      //původní editované mapování nemuselo být úplné - proto není v DB, pouze v GUI
      if (editedMapping.activityCode != null) {
        await api.deleteActivityMappings([editedMapping]);
      }
      _mappings.removeWhere((element) =>
          element.activityCode == editedMapping.activityCode &&
          element.extEnvironment == editedMapping.extEnvironment &&
          element.extCode == editedMapping.extCode);
    }
    final mapping = ActivityMapping(
        activityCode: _ptfmCodeController.text.trim(),
        extEnvironment: widget.selectedExtEnvironment,
        extCode: _extCodeController.text.trim(),
        ratio: double.parse(_mappingRatioController.text));

    api.insertActivityMappings([mapping]).onError((error, _) {
      setState(() => _errorString = error.toString());
      return -1;
    });
    _mappings.add(mapping);
    _mappings.sort((a, b) => a.extCode.compareTo(b.extCode));
    setState(() {
      _joinWorkItemsAndMappings();
    });
  }

  /// Vrátí dialog nastavení filtru arePath
  Future _setAreaPathFilterDialog(BuildContext context) async {
    _extCodeFilterController.text = _extCodeFiterString;

    await showDialog(
        context: context,
        builder: (newContext) {
          return AlertDialog(
            title: const Text('Set area path filter'),
            content: Form(
              key: _formKey,
              child: TextFormField(
                controller: _extCodeFilterController,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.category_outlined),
                  labelText: 'Area path substring',
                  suffixIcon: InkWell(
                    child: const Icon(Icons.close),
                    onTap: () => SharedPreferences.getInstance().then((value) => {
                          _extCodeFilterController.text =
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
                  if (_formKey.currentState!.validate()) {
                    _onAreaPathSubmitted();
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
                  if (_formKey.currentState!.validate()) {
                    _onAreaPathSubmitted();
                    Navigator.of(newContext).pop(true);
                  }
                },
                child: const Text('Set'),
              )
            ],
          );
        });
  }

  void _onAreaPathSubmitted() {
    setState(() {
      _extCodeFiterString = _extCodeFilterController.text;
      isLoading = true;
    });
    api
        .getWorkItems(
            arePathFilter: _extCodeFiterString,
            token: widget.trackerToken,
            trackerBaseUrl: widget.trackerBaseUrl)
        .then((value) {
      setState(() {
        _workItems = value;
        _joinWorkItemsAndMappings();
        isLoading = false;
      });
    }).onError((error, _) {
      setState(() => _errorString = error.toString());
    });
  }

  Future _selectActivityDialog(BuildContext context) {
    return showDialog(
        context: context,
        builder: (newContext) {
          return SimpleDialog(
            title: const Text('Select activity'),
            children: _activities
                .map((m) => SimpleDialogOption(
                      child: Text(m.name),
                      onPressed: () {
                        Navigator.pop(context, m.code);
                      },
                    ))
                .toList(),
          );
        });
  }

  /// Dialog uložení zobrazených mapování do nového protředí
  void _saveAsNewEnvDialog(
    BuildContext context,
  ) {
    _mappingExtEnvController.text = widget.selectedExtEnvironment;
    showDialog(
      context: context,
      builder: (BuildContext newContext) => AlertDialog(
        title: const Text('Save as new'),
        content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                //Uživateli umožníme změnit identifikátor externího prostředí. Díky tomu je možné "kopírovat" záznamy do nového prostředí
                TextFormField(
                  controller: _mappingExtEnvController,
                  decoration: const InputDecoration(
                    labelText: 'External code',
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    isDense: true,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'cannot be empty' : null,
                  onFieldSubmitted: (value) {
                    if (_formKey.currentState!.validate()) {
                      _saveAsNewEnvDialogSubmitted(context);
                      Navigator.of(newContext).pop();
                    }
                  },
                ),
              ],
            )),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(newContext).pop()),
          TextButton(
              child: const Text('Save'),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _saveAsNewEnvDialogSubmitted(context);
                  Navigator.of(newContext).pop();
                }
              })
        ],
      ),
    );
  }

  /// Uložit zobrazené záznamy do nového prostředí
  Future _saveAsNewEnvDialogSubmitted(BuildContext context) async {
    int count = 0;
    final newEnv = _mappingExtEnvController.text.trim();
    if (newEnv.isNotEmpty) {
      for (final m in _displayedMappings) {
        if (m.activityCode != null) {
          final mapping = ActivityMapping(
              extEnvironment: newEnv,
              activityCode: m.activityCode,
              extCode: m.extCode,
              ratio: m.ratio,
              note: m.note);
          await api.insertActivityMappings([mapping]);
          debugPrint(
              '${mapping.extCode} - ${mapping.activityCode} saved to ${mapping.extEnvironment}');
          count++;
        }
      }

      if (mounted) {
        return ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$count mappings saved to $newEnv'),
        ));
      }
    }
  }
}
