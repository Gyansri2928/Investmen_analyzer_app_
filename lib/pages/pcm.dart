import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:property_analyzer_mobile/service/logic.dart'; // Ensure this matches your file path (e.g. logic.dart or service/logic.dart)

// Import the new modular pages
import 'package:property_analyzer_mobile/pages/inputs_tab.dart';
import 'package:property_analyzer_mobile/pages/overview.dart';
import 'package:property_analyzer_mobile/pages/details.dart';

class PropertyComparisonMobile extends StatefulWidget {
  const PropertyComparisonMobile({super.key});

  @override
  State<PropertyComparisonMobile> createState() =>
      _PropertyComparisonMobileState();
}

class _PropertyComparisonMobileState extends State<PropertyComparisonMobile> {
  int _selectedIndex = 0; // 0: Inputs, 1: Overview, 2: Details

  // --- NEW: Loading State ---
  bool _isProcessing = false;
  String _loadingMessage = "";

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
  // --- PERSISTENCE LOGIC ---

  // 1. Load Data (Run on App Start)
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Try to read the strings
    String? propJson = prefs.getString('propertyData');
    String? selectJson = prefs.getString('userSelections');

    if (propJson != null) {
      setState(() {
        // Decode JSON back to Map
        propertyData = jsonDecode(propJson);
        // Ensure properties list is dynamic list of maps
        if (propertyData['properties'] != null) {
          propertyData['properties'] = List<Map<String, dynamic>>.from(
            (propertyData['properties'] as List).map(
              (item) => Map<String, dynamic>.from(item),
            ),
          );
        }
      });
    }

    if (selectJson != null) {
      setState(() {
        userSelections = jsonDecode(selectJson);
        // Ensure lists are typed correctly
        if (userSelections['scenarioExitPrices'] != null) {
          userSelections['scenarioExitPrices'] = List<dynamic>.from(
            userSelections['scenarioExitPrices'],
          );
        }
      });
    }
  }

  // 2. Save Data (Run on every change)
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('propertyData', jsonEncode(propertyData));
    await prefs.setString('userSelections', jsonEncode(userSelections));
  }

  late Map<String, dynamic> propertyData;
  late Map<String, dynamic> userSelections;
  Map<String, dynamic> _results = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    propertyData = _getInitialPropertyData();
    userSelections = {
      'selectedPropertyId': 1,
      'selectedExitPrice': '',
      'selectedPropertySize': '',
      'scenarioExitPrices': [],
    };
    _recalculate();
  }

  void _recalculate() {
    setState(() {
      _results = PropertyCalculator.calculate(propertyData, userSelections);
    });
  }

  // This function is triggered whenever the user types in InputsTab
  void _handleDataChange() {
    setState(() {
      // 1. Trigger a UI rebuild (so calculations update)
      _recalculate();
    });

    // 2. Save the new data to local storage
    _saveData();
  }

  // --- THE RESET LOGIC ---
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
    });
    _saveData();
    _recalculate();
  }

  // --- NEW: HANDLE ANALYZE CLICK (The logic you requested) ---
  void _handleAnalyze() async {
    // 1. Start Loading Animation
    setState(() {
      _isProcessing = true;
      _loadingMessage = "Analyzing Property Parameters...";
    });

    // 2. Wait 1.5 seconds (Simulate calculation/processing time)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    setState(() {
      // B. Stop Loading
      _isProcessing = false;
      // A. Switch to Overview Tab
      _selectedIndex = 1;
    });

    // C. Show Success Alert (SnackBar is the Flutter equivalent)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text("Analysis Complete! Viewing results.")),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3), // E. Auto-hide
      ),
    );
  }

  // --- 3. UI BUILDER ---
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
                onAnalyze: _handleAnalyze, // <--- PASSING THE CALLBACK
              ),

              // Tab 1: OVERVIEW
              OverviewTab(
                results: _results,
                onTabChange: (index) => setState(() => _selectedIndex = index),
              ),

              // Tab 2: DETAILS
              DetailsTab(),
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

        // --- LOADING OVERLAY ---
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
