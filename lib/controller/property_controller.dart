import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../service/logic.dart';

class PropertyController extends GetxController {
  // ✅ 1. Initialize the Storage Box
  final box = GetStorage();

  // =========================================================
  // 2. OBSERVABLE STATE
  // =========================================================
  var propertyData = <String, dynamic>{}.obs;

  var userSelections = <String, dynamic>{
    'selectedPropertyId': 1,
    'selectedPropertySize': '',
    'selectedExitPrice': '',
    'scenarioExitPrices': [],
  }.obs;

  var results = <String, dynamic>{}.obs;
  var isDataLoaded = false.obs;

  // =========================================================
  // 3. INITIALIZATION & PERSISTENCE
  // =========================================================
  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  void loadData() {
    print("📦 STORAGE: Attempting to load data...");

    // 1. Read the raw strings once
    String? propJson = box.read('propertyData');
    String? selectJson = box.read('userSelections');

    print("📦 STORAGE: Found Property JSON? ${propJson != null}");

    // 2. Handle Property Data
    if (propJson != null) {
      try {
        var decodedProp = jsonDecode(propJson);

        // Safety Fix for List<dynamic> before assigning
        if (decodedProp['properties'] != null) {
          decodedProp['properties'] = List<Map<String, dynamic>>.from(
            (decodedProp['properties'] as List).map(
              (item) => Map<String, dynamic>.from(item),
            ),
          );
        }

        propertyData.assignAll(decodedProp);
        print("✅ STORAGE: Property Data Loaded!");
      } catch (e) {
        print("❌ STORAGE ERROR (Property): $e");
        // Optional: If data is corrupt, you might want to reset memory here too
        // _resetMemoryState();
      }
    } else {
      print(
        "⚠️ STORAGE: No property data found. Using defaults (Memory Only).",
      );
      // ✅ FIX 1: Use internal reset that DOES NOT save to disk immediately
      _resetMemoryState();
    }

    // 3. Handle User Selections
    if (selectJson != null) {
      try {
        userSelections.assignAll(jsonDecode(selectJson));
        print("✅ STORAGE: User Selections Loaded!");
      } catch (e) {
        print("❌ STORAGE ERROR (Selections): $e");
      }
    } else {
      // Ensure selections have defaults if missing (Memory Only)
      userSelections.assignAll({
        'selectedPropertyId': 1,
        'selectedPropertySize': '',
        'selectedExitPrice': '',
        'scenarioExitPrices': [],
      });
    }

    isDataLoaded.value = true;
    calculate();
  }

  // SAVE DATA
  void saveData() {
    print("💾 STORAGE: Saving data...");
    try {
      // ✅ FIX: Use jsonEncode on the RxMap directly
      box.write('propertyData', jsonEncode(propertyData));
      box.write('userSelections', jsonEncode(userSelections));
      print("✅ STORAGE: Save Complete!");
    } catch (e) {
      print("❌ STORAGE SAVE ERROR: $e");
    }
  }

  // ✅ FIX 2: INTERNAL RESET (Updates Memory ONLY, No Save)
  void _resetMemoryState() {
    propertyData.assignAll({
      'purchasePrice': '',
      'otherCharges': '',
      'stampDuty': '',
      'gstPercentage': '',
      'paymentPlan': 'clp',
      'exitPrices': [],
      'properties': [
        {
          'id': 1,
          'name': '',
          'location': '',
          'size': '',
          'possessionMonths': '', // Kept empty for logic
          'rating': 0,
          'isHighlighted': true,
        },
      ],
      'assumptions': {
        'homeLoanRate': '',
        'homeLoanTerm': '',
        'homeLoanShare': 80,
        'homeLoanStartMonth': 0,
        'homeLoanStartMode': 'default',
        'personalLoan1Rate': '',
        'personalLoan1Term': '',
        'personalLoan1StartMonth': 0,
        'personalLoan1Share': 10,
        'personalLoan2Rate': '',
        'personalLoan2Term': '',
        'personalLoan2StartMonth': 0,
        'personalLoan2Share': 10,
        'downPaymentShare': 0,
        'investmentPeriod': '',
        'holdingPeriodUnit': 'years',
        'clpDurationYears': '',
        'bankDisbursementStartMonth': '',
        'bankDisbursementInterval': '',
        'lastBankDisbursementMonth': '',
      },
    });

    userSelections.assignAll({
      'selectedPropertyId': 1,
      'selectedPropertySize': '',
      'selectedExitPrice': '',
      'scenarioExitPrices': [],
    });

    results.clear();

    // Refresh GetX listeners
    propertyData.refresh();
    userSelections.refresh();
  }

  // ✅ FIX 3: PUBLIC RESET (Updates Memory AND Saves)
  // This is what your "Reset" button calls
  void resetToDefaults() {
    _resetMemoryState(); // Reset memory variables
    saveData(); // Explicitly overwrite the disk now
  }

  // =========================================================
  // 4. ACTION METHODS
  // =========================================================

  void updateInput(String key, dynamic value) {
    propertyData[key] = value;
    calculate();
    saveData();
  }

  void updateAssumption(String key, dynamic value) {
    propertyData['assumptions'][key] = value;
    propertyData.refresh(); // Crucial for nested maps in Obx
    calculate();
    saveData();
  }

  void updateProperty(int id, String key, dynamic value) {
    var props = propertyData['properties'] as List;
    var index = props.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      props[index][key] = value;
      // Sync size if it's the selected property
      if (id == userSelections['selectedPropertyId'] && key == 'size') {
        userSelections['selectedPropertySize'] = value;
      }
      propertyData.refresh();
      calculate();
      saveData();
    }
  }

  void updateSelection(String key, dynamic value) {
    userSelections[key] = value;
    // Special handling for nested lists (like scenarios) requires explicit refresh
    if (value is List) {
      userSelections.refresh();
    }
    calculate();
    saveData();
  }

  void calculate() {
    try {
      var calcResult = PropertyCalculator.calculate(
        propertyData,
        userSelections,
      );
      results.value = calcResult;
    } catch (e) {
      print("Calc Error: $e");
    }
  }
}
