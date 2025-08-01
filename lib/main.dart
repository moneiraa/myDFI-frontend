import 'alert_service.dart';
import 'dart:convert'; // <-- for jsonEncode, jsonDecode
import 'package:http/http.dart' as http; // <-- for http.get, http.post, etc.
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const String baseUrl = "https://mydfi.onrender.com";

  // Only initialize notifications on mobile platforms
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android) {
    try {
      await initializeNotifications();
      await requestNotificationPermissions();
      await scheduleAlertIfInteractionsExist(baseUrl);
    } catch (e, s) {
      debugPrint("Notification initialization error: $e\n$s");
    }
  }

  runApp(const MedicationApp());
}


// ------------------- ORIGINAL APP CODE -------------------

class Medication {
  String id;
  String sfdaDrugId;
  String tradeName;
  String scientificName;
  String startDate;
  String endDate;
  String userId="1"; // <-- NEW field for future multi-user support

  Medication(
    this.id,
    this.sfdaDrugId,
    this.tradeName,
    this.scientificName,
    this.startDate,
    this.endDate, {
    this.userId = "1", // default shared user for now
  });

  Map<String, dynamic> toJson() => {

        "sfda_drug_id": sfdaDrugId,
        "trade_name": tradeName,
        "scientific_name": scientificName,
        "duration": "$startDate - $endDate",
        "user_id": userId, // new field for future unique users
      };

  factory Medication.fromJson(Map<String, dynamic> json) {
    try {
      String trade = json['drug_trade_name'] ?? json['trade_name'] ?? '';
      String scientific =
          json['drug_scientific_name'] ?? json['scientific_name'] ?? '';
      String id = json['_id'] ?? '';
      String start = '';
      if (json['drug_duration_start_date'] != null &&
          json['drug_duration_start_date'].toString().isNotEmpty) {
        start = _formatBackendDate(json['drug_duration_start_date']);
      }
      String end = '';
      if (json['drug_duration_end_date'] == null ||
          json['drug_duration_end_date'].toString().isEmpty) {
        end = 'Ongoing';
      } else if (json['drug_duration_end_date'].toString().toLowerCase() ==
          'ongoing') {
        end = 'Ongoing';
      } else {
        end = _formatBackendDate(json['drug_duration_end_date']);
      }
      return Medication(
        id,
        json['sfda_drug_id'] ?? '',
        trade,
        scientific,
        start,
        end,
        userId: json['user_id'] ?? "test-user", // support backend multi-user field
      );
    } catch (e) {
      print("Error parsing medication: $e, data: $json");
      return Medication('', '', '', '', '', '');
    }
  }
}

String _formatBackendDate(dynamic date) {
  DateTime parsed;
  if (date is DateTime) {
    parsed = date;
  } else {
    parsed = DateTime.tryParse(date.toString()) ?? DateTime.now();
  }
  return "${parsed.day.toString().padLeft(2, '0')}/"
      "${parsed.month.toString().padLeft(2, '0')}/"
      "${parsed.year}";
}


class MedicationApp extends StatefulWidget {
  const MedicationApp({super.key});
  @override
  State<MedicationApp> createState() => _MedicationAppState();
}

class _MedicationAppState extends State<MedicationApp> {
  bool isDarkMode = false;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medication List',
      theme: ThemeData(
        primaryColor: Colors.blue,
        colorScheme:
            const ColorScheme.light(primary: Colors.blue, secondary: Colors.blue),
        textSelectionTheme:
            const TextSelectionThemeData(cursorColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        primaryColor: Colors.blue,
        colorScheme:
            const ColorScheme.dark(primary: Colors.blue, secondary: Colors.blue),
        textSelectionTheme:
            const TextSelectionThemeData(cursorColor: Colors.blue),
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MedicationListPage(
        onToggleTheme: () => setState(() => isDarkMode = !isDarkMode),
      ),
    );
  }
}


class MedicationListPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const MedicationListPage({Key? key, required this.onToggleTheme})
      : super(key: key);

  @override
  _MedicationListPageState createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  List<Medication> medications = [];

  // PLACEHOLDER BACKEND URL 
final String baseUrl = "https://mydfi.onrender.com";


  Future<List<Map<String, dynamic>>> autocomplete(String query) async {
  final response = await http.get(
    Uri.parse("$baseUrl/autocomplete?q=${Uri.encodeComponent(query)}")
  );
  if (response.statusCode == 200) {
    return List<Map<String, dynamic>>.from(
        jsonDecode(response.body)['results']);
  } else {
    return [];
  }
}


  Future<Map<String, dynamic>> autofill(String name) async {
    final response = await http.get(
        Uri.parse("$baseUrl/autofill?input_name=${Uri.encodeComponent(name)}"));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {};
    }
  }
Future<void> addMedication(Medication med) async {
  try {
    final body = jsonEncode(med.toJson());
    print("Sending to backend: $body");

    final response = await http.post(
      Uri.parse("$baseUrl/add_medication"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");

    if (response.statusCode == 200) {
      await fetchMedications();
    } else {
      print("Error adding medication: ${response.body}");
    }
  } catch (e) {
    print("Error adding medication: $e");
  }
}


  Future<void> deleteMedication(Medication med) async {
    try {
      await http.delete(
        Uri.parse("$baseUrl/delete_medication"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"_id": med.id}),
      );
    } catch (e) {
      print("Error deleting medication: $e");
    }
  }

  Future<void> fetchMedications() async {
  try {
    print("Fetching medications...");
    final response =
        await http.get(Uri.parse("$baseUrl/get_medications?user_id=1"));
    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("Parsed data: $data");

      if (data['medications'] != null) {
        final List<dynamic> medsJson = data['medications'];
        setState(() {
          medications = medsJson.map((e) {
            try {
              return Medication.fromJson(e);
            } catch (err) {
              print("Error parsing one medication: $err | data: $e");
              return Medication('', '', '', '', '', '');
            }
          }).toList();
        });
        print("Final medications count: ${medications.length}");
      }
    } else {
      print("Non-200 response: ${response.statusCode}");
    }
  } catch (e) {
    print("Error fetching medications: $e");
  }
}

  void _navigateToAddPage() async {
    final med = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AddMedicationPage(
                autocomplete: autocomplete,
                autofill: autofill,
              )),
    );
    if (med != null && med is Medication) {
      await addMedication(med);
    }
  }

  void _confirmDelete(int index) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Medication"),
          content:
              const Text("Are you sure you want to delete this medication?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("No")),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Yes")),
          ],
        );
      },
    );
    if (confirmed == true) {
      await deleteMedication(medications[index]);
      setState(() => medications.removeAt(index));
    }
  }
  Widget _buildMedicationCard(int index, Medication med) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.lightBlue[100],
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(med.tradeName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
                onPressed: () => _confirmDelete(index),
                icon: const Icon(Icons.close))
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(med.scientificName),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(med.startDate),
              Text(med.endDate)
            ])
          ])
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchMedications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.person, color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Medication List',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6, color: Colors.black),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: medications.isEmpty
            ? const Center(
                child: Text(
                  "No medications added yet.",
                  style: TextStyle(fontSize: 16),
                ),
              )
            : Column(
                children: medications
                    .asMap()
                    .entries
                    .map((entry) => _buildMedicationCard(entry.key, entry.value))
                    .toList(),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton.extended(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: Colors.blue,
              onPressed: _navigateToAddPage,
              icon: const Icon(Icons.add),
              label: const Text("Add Medication"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {},
              icon: const Icon(Icons.subdirectory_arrow_right,
                  color: Colors.white),
              label: const Text(
                "Interactions",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// =================== AddMedicationPage ===================
class AddMedicationPage extends StatefulWidget {
  final Future<List<dynamic>> Function(String) autocomplete;
  final Future<Map<String, dynamic>> Function(String) autofill;

  const AddMedicationPage({
    Key? key,
    required this.autocomplete,
    required this.autofill,
  }) : super(key: key);

  @override
  _AddMedicationPageState createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final TextEditingController _tradeController = TextEditingController();
  final TextEditingController _scientificController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  String? _sfdaDrugId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _tradeController.dispose();
    _scientificController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
          _startDateController.text = _formatDate(date);
        } else {
          _endDate = date;
          _endDateController.text = _formatDate(date);
        }
      });
    }
  }

  String _formatDate(DateTime date) =>
      "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";

  void _showInvalidDateDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invalid Dates'),
        content: const Text('End date cannot be before start date.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }
void _onTapOutside() => FocusScope.of(context).unfocus();

@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: _onTapOutside,
    behavior: HitTestBehavior.translucent,
    child: Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.person, color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Add Medication',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Please fill in information to add your new medication"),
            const SizedBox(height: 12),

            // -------- Trade Name Autocomplete --------
            TypeAheadField<Map<String, dynamic>>(
              suggestionsBoxDecoration: const SuggestionsBoxDecoration(
                constraints: BoxConstraints(maxHeight: 250), // <-- FIX
              ),
              textFieldConfiguration: TextFieldConfiguration(
                controller: _tradeController,
                decoration: const InputDecoration(labelText: "Trade Name"),
              ),
              suggestionsCallback: (pattern) async {
                final results = await widget.autocomplete(pattern);
                return results.cast<Map<String, dynamic>>();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion['trade_name'] ?? ''),
                  subtitle: Text(suggestion['scientific_name'] ?? ''),
                );
              },
              onSuggestionSelected: (suggestion) async {
                final auto = await widget.autofill(
                    suggestion['trade_name'] ?? suggestion['scientific_name']);
                _sfdaDrugId = auto['sfda_drug_id'] ?? '';
                _tradeController.text = auto['trade_name'] ?? '';
                _scientificController.text = auto['scientific_name'] ?? '';
              },
            ),
            const SizedBox(height: 8),

            // -------- Scientific Name Autocomplete --------
            TypeAheadField<Map<String, dynamic>>(
              suggestionsBoxDecoration: const SuggestionsBoxDecoration(
                constraints: BoxConstraints(maxHeight: 250), // <-- FIX
              ),
              textFieldConfiguration: TextFieldConfiguration(
                controller: _scientificController,
                decoration: const InputDecoration(labelText: "Scientific Name"),
              ),
              suggestionsCallback: (pattern) async {
                final results = await widget.autocomplete(pattern);
                return results.cast<Map<String, dynamic>>();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion['trade_name'] ?? ''),
                  subtitle: Text(suggestion['scientific_name'] ?? ''),
                );
              },
              onSuggestionSelected: (suggestion) async {
                final auto = await widget.autofill(
                    suggestion['trade_name'] ?? suggestion['scientific_name']);
                _sfdaDrugId = auto['sfda_drug_id'] ?? '';
                _tradeController.text = auto['trade_name'] ?? '';
                _scientificController.text = auto['scientific_name'] ?? '';
              },
            ),
            const SizedBox(height: 8),

            // -------- Start & End Dates --------
            TextField(
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "Start Date",
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _pickDate(true),
              controller: _startDateController,
            ),
            const SizedBox(height: 8),
            TextField(
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "End Date",
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _pickDate(false),
              controller: _endDateController,
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () {
                    if (_tradeController.text.isNotEmpty &&
                        _scientificController.text.isNotEmpty) {
                      if (_startDate != null &&
                          _endDate != null &&
                          _startDate!.isAfter(_endDate!)) {
                        _showInvalidDateDialog();
                        return;
                      }

                      final med = Medication(
                        "",
                        _sfdaDrugId ?? '',
                        _tradeController.text,
                        _scientificController.text,
                        _startDate != null ? _formatDate(_startDate!) : "",
                        _endDate != null ? _formatDate(_endDate!) : "",
                      );

                      Navigator.pop(context, med);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Medication added successfully!')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all fields.')),
                      );
                    }
                  },
                  child: const Text("OK", style: TextStyle(color: Colors.blue)),
                ),
              ],
            )
          ],
        ),
      ),
    ),
  );
}
}