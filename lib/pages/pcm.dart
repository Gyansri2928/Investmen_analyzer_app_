import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ NEW: Import API Service
import 'package:property_analyzer_mobile/service/api_service.dart';

import 'package:property_analyzer_mobile/pages/inputs_tab.dart';
import 'package:property_analyzer_mobile/pages/overview.dart';
import 'package:property_analyzer_mobile/pages/details.dart';

import '../controller/property_controller.dart';

class PropertyComparisonMobile extends StatefulWidget {
  const PropertyComparisonMobile({super.key});

  @override
  State<PropertyComparisonMobile> createState() =>
      _PropertyComparisonMobileState();
}

class _PropertyComparisonMobileState extends State<PropertyComparisonMobile> {
  int _selectedIndex = 0; // 0: Inputs, 1: Overview, 2: Details

  bool _isProcessing = false;
  String _loadingMessage = "";

  // ✅ NEW: Store Server Data (Null initially)
  Map<String, dynamic>? _serverData;

  // --- 1. INITIAL STATE CONFIGURATION ---
  Map<String, dynamic> _getInitialPropertyData() => {
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
        'possessionMonths': '',
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
  };

  late Map<String, dynamic> propertyData;
  late Map<String, dynamic> userSelections;

  @override
  void initState() {
    super.initState();
    propertyData = _getInitialPropertyData();
    userSelections = {
      'selectedPropertyId': 1,
      'selectedExitPrice': '',
      'selectedPropertySize': '',
      'scenarioExitPrices': [],
    };
    _loadData();
  }

  // --- PERSISTENCE LOGIC (Keep as is) ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    // Wrap in try-catch to avoid GetX errors if controller isn't ready
    try {
      final controller = Get.find<PropertyController>();

      String? propJson = prefs.getString('propertyData');
      String? selectJson = prefs.getString('userSelections');

      if (propJson != null) {
        Map<String, dynamic> loadedProp = jsonDecode(propJson);
        setState(() {
          propertyData = loadedProp;
          if (propertyData['properties'] != null) {
            propertyData['properties'] = List<Map<String, dynamic>>.from(
              (propertyData['properties'] as List).map(
                (item) => Map<String, dynamic>.from(item),
              ),
            );
          }
        });
        controller.propertyData.value = loadedProp;
      }

      if (selectJson != null) {
        Map<String, dynamic> loadedSelect = jsonDecode(selectJson);
        setState(() {
          userSelections = jsonDecode(selectJson);
          if (userSelections['scenarioExitPrices'] != null) {
            userSelections['scenarioExitPrices'] = List<dynamic>.from(
              userSelections['scenarioExitPrices'],
            );
          }
        });
        controller.userSelections.value = loadedSelect;
      }
    } catch (e) {
      print("Controller or Data Load Error: $e");
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('propertyData', jsonEncode(propertyData));
    await prefs.setString('userSelections', jsonEncode(userSelections));
  }

  void _handleDataChange() {
    // No local recalculate() anymore! Just save inputs.
    _saveData();
  }

  void _handleReset() {
    setState(() {
      var currentPlan = propertyData['paymentPlan'];
      var currentAssumptions = propertyData['assumptions'];
      var defaults = _getInitialPropertyData();

      defaults['paymentPlan'] = currentPlan;
      defaults['assumptions']['homeLoanShare'] =
          currentAssumptions['homeLoanShare'];
      defaults['assumptions']['personalLoan1Share'] =
          currentAssumptions['personalLoan1Share'];
      defaults['assumptions']['personalLoan2Share'] =
          currentAssumptions['personalLoan2Share'];
      defaults['assumptions']['downPaymentShare'] =
          currentAssumptions['downPaymentShare'];

      propertyData = defaults;
      userSelections = {
        'selectedPropertyId': 1,
        'selectedExitPrice': '',
        'selectedPropertySize': '',
        'scenarioExitPrices': [],
      };
      // Clear results on reset
      _serverData = null;
    });
    _saveData();
  }

  // --- ✅ NEW: REAL API CALL ---
  void _handleAnalyze() async {
    // ✅ FIX: Get the LATEST data from the Controller (Source of Truth)
    final controller = Get.find<PropertyController>();
    final livePropertyData = controller.propertyData;
    final liveUserSelections = controller.userSelections;

    // 1. Basic UI Validation (Using live data)
    final priceInput = livePropertyData['purchasePrice']?.toString() ?? '';
    if (priceInput.isEmpty || (double.tryParse(priceInput) ?? 0) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid Purchase Price"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _loadingMessage = "Connecting to Analysis Engine...";
    });

    try {
      // 2. Prepare Property List safely from Live Data
      final List<Map<String, dynamic>> propsList =
          List<Map<String, dynamic>>.from(livePropertyData['properties']);

      // 3. Find Selected Property
      final rawSelectedProp = propsList.firstWhere(
        (p) => p['id'] == liveUserSelections['selectedPropertyId'],
        orElse: () => propsList.first,
      );

      // 4. CLEAN THE PROPERTY OBJECT
      final cleanSelectedProperty = {
        "id": rawSelectedProp['id'],
        "name": rawSelectedProp['name'],
        "location": rawSelectedProp['location'],
        "size": double.tryParse(rawSelectedProp['size'].toString()) ?? 0,
        "possessionMonths":
            int.tryParse(rawSelectedProp['possessionMonths'].toString()) ?? 0,
      };

      // 5. Construct Payload using LIVE DATA
      final payload = {
        "purchasePrice": double.tryParse(priceInput) ?? 0,
        "otherCharges":
            double.tryParse(livePropertyData['otherCharges'].toString()) ?? 0,
        "stampDuty":
            double.tryParse(livePropertyData['stampDuty'].toString()) ?? 0,
        "gstPercentage":
            double.tryParse(livePropertyData['gstPercentage'].toString()) ?? 0,
        "paymentPlan": livePropertyData['paymentPlan'],
        "assumptions": {
          ...livePropertyData['assumptions'],
          // Ensure numbers
          "homeLoanRate":
              double.tryParse(
                livePropertyData['assumptions']['homeLoanRate'].toString(),
              ) ??
              0,
          "homeLoanTerm":
              int.tryParse(
                livePropertyData['assumptions']['homeLoanTerm'].toString(),
              ) ??
              0,
        },
        "selectedProperty": cleanSelectedProperty,
        "selectedExitPrice":
            double.tryParse(
              liveUserSelections['selectedExitPrice'].toString(),
            ) ??
            0,
        "scenarioExitPrices": liveUserSelections['scenarioExitPrices'] ?? [],
      };

      // Debug: See what is actually being sent
      print("Payload: ${jsonEncode(payload)}");

      // 6. Call Backend
      final result = await ApiService.calculateProperty(payload);

      if (result['success'] == true) {
        // ✅ Update the controller with results so other tabs can see them
        controller.results.value = result['data'];

        setState(() {
          _serverData = result['data'];
          _isProcessing = false;
          _selectedIndex = 1; // Switch to Overview
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Analysis Complete!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              // Tab 0: INPUTS
              InputsTab(
                propertyData: propertyData,
                userSelections: userSelections,
                onDataChanged: _handleDataChange,
                onReset: _handleReset,
                onAnalyze: _handleAnalyze,
              ),

              // Tab 1: OVERVIEW (Pass Server Data)
              OverviewTab(
                results: _serverData, // Can be null initially
                onTabChange: (index) => setState(() => _selectedIndex = index),
              ),

              // Tab 2: DETAILS (Pass Server Data)
              DetailsTab(
                results: _serverData, // Can be null initially
              ),
            ],
          ),

          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (idx) => setState(() => _selectedIndex = idx),
            selectedItemColor: const Color.fromARGB(255, 79, 122, 192),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Inputs'),
              BottomNavigationBarItem(
                icon: Icon(Icons.speed),
                label: 'Overview',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics),
                label: 'Details',
              ),
            ],
          ),
        ),

        // Loading Overlay
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    _loadingMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
