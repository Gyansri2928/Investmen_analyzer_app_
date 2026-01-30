import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Import Get
import 'package:property_analyzer_mobile/controller/property_controller.dart'; // Import Controller
import '../main.dart'; // For AppColors

class InputsTab extends StatefulWidget {
  final Map<String, dynamic> propertyData;
  final Map<String, dynamic> userSelections;
  final VoidCallback onDataChanged;
  final VoidCallback onReset;
  final VoidCallback onAnalyze;

  const InputsTab({
    super.key,
    required this.propertyData,
    required this.userSelections,
    required this.onDataChanged,
    required this.onReset,
    required this.onAnalyze,
  });

  @override
  State<InputsTab> createState() => _InputsTabState();
}

class _InputsTabState extends State<InputsTab> {
  final controller = Get.find<PropertyController>();
  int _currentStep = 1;
  int _maxStepReached = 1;
  String _activeAccordion = 'prop_mgmt';
  late TextEditingController _exitPriceCtrl;

  @override
  void initState() {
    super.initState();
    // Initialize with existing value
    _exitPriceCtrl = TextEditingController(
      text: controller.userSelections['selectedExitPrice']?.toString(),
    );
  }

  @override
  void dispose() {
    _exitPriceCtrl.dispose(); // Clean up
    super.dispose();
  }

  // ✅ HELPER: Removes ".0" if the number is whole (24.0 -> "24")
  String _formatValue(dynamic value) {
    if (value == null) return '';
    if (value is double) {
      // If the number has no decimal part, convert to int string
      if (value % 1 == 0) {
        return value.toInt().toString();
      }
    }
    return value.toString();
  }

  void _toggleAccordion(String id) {
    setState(() {
      _activeAccordion = _activeAccordion == id ? '' : id;
    });
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
      if (step > _maxStepReached) _maxStepReached = step;
    });
    if (step == 4) _autoPopulateExitPrice();
  }

  void _autoPopulateExitPrice() {
    // Read from controller
    double purchasePrice =
        double.tryParse(controller.propertyData['purchasePrice'].toString()) ??
        0;
    String currentExitPrice = controller.userSelections['selectedExitPrice']
        .toString();

    if (purchasePrice > 0 &&
        (currentExitPrice.isEmpty ||
            currentExitPrice == '0' ||
            currentExitPrice == 'null')) {
      double duration =
          double.tryParse(
            controller.propertyData['assumptions']['investmentPeriod']
                .toString(),
          ) ??
          0;
      String unit =
          controller.propertyData['assumptions']['holdingPeriodUnit'] ??
          'years';
      double years = unit == 'months' ? duration / 12 : duration;

      double increment = years < 1
          ? 500
          : (years < 2 ? 1000 : (years < 3 ? 2000 : 3500));
      double calculatedExit = purchasePrice + increment;
      String newVal = calculatedExit.toStringAsFixed(0);

      // ✅ Update Controller & UI
      controller.updateSelection('selectedExitPrice', newVal);
      _exitPriceCtrl.text = newVal;
    }
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Reset Property Details?"),
          content: const Text(
            "This will clear all prices, taxes, and scenarios.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                // 1. Reset the Data in GetX
                controller.resetToDefaults();

                // 2. Reset the UI State
                setState(() {
                  _currentStep = 1;
                  _maxStepReached = 1;

                  // ✅ FIX: Manually clear the persistent text controller
                  _exitPriceCtrl.clear();

                  // Optional: if you have other internal UI flags, reset them here
                  _activeAccordion = 'prop_mgmt';
                });

                Navigator.of(ctx).pop();

                Get.snackbar(
                  "Reset Successful",
                  "All inputs have been cleared.",
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.8),
                  colorText: Colors.white,
                );
              },
              child: const Text("Reset", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _addProperty() {
    List<dynamic> props = controller.propertyData['properties'];

    // ... (Your maxId logic is correct) ...
    int maxId = 0;
    if (props.isNotEmpty) {
      maxId = props.fold<int>(0, (prev, element) {
        int currentId = int.tryParse(element['id'].toString()) ?? 0;
        return max(prev, currentId);
      });
    }
    int newId = maxId + 1;

    // 1. Add to the list
    props.add({
      'id': newId,
      'size': '1000',
      'name': 'Property $newId',
      'location': '',
      'possessionMonths': '24',
      'rating': 0,
      'isHighlighted': false,
    });

    controller.updateProperty(newId, 'name', 'Property $newId');
  }

  void _removeProperty(int index) {
    List<dynamic> props = controller.propertyData['properties'];
    var removedProp = props[index];
    props.removeAt(index);

    // Logic to switch selection if the deleted one was active
    if (controller.userSelections['selectedPropertyId'] == removedProp['id']) {
      if (props.isNotEmpty) {
        // Direct assignment to controller map
        controller.userSelections['selectedPropertyId'] = props[0]['id'];
        controller.userSelections['selectedPropertySize'] = props[0]['size'];
      }
    }

    // ✅ FIX: Trigger GetX updates manually since we modified the list directly
    controller.propertyData.refresh();
    controller.userSelections.refresh();
    controller.calculate();
    controller.saveData(); // Persists to storage
  }

  void _addExitScenario() {
    double currentBase =
        double.tryParse(
          controller.userSelections['selectedExitPrice'].toString(),
        ) ??
        0;

    List currentScenarios =
        controller.userSelections['scenarioExitPrices'] as List;

    double maxPrice = currentBase;
    if (currentScenarios.isNotEmpty) {
      maxPrice = currentScenarios
          .map((e) => double.parse(e.toString()))
          .reduce(max);
    }

    // 1. Add the new price
    currentScenarios.add(maxPrice + 500);

    // ✅ 2. FIX: Tell GetX that the 'userSelections' map has changed internally
    controller.userSelections.refresh();

    // 3. Trigger math and save
    controller.calculate();
    controller.saveData();
  }

  void _removeExitScenario(int index) {
    List currentScenarios =
        controller.userSelections['scenarioExitPrices'] as List;
    currentScenarios.removeAt(index);

    // ✅ FIX: Tell GetX to refresh the UI
    controller.userSelections.refresh();

    controller.calculate();
    controller.saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Access data here to trigger updates
      return SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 100,
        ),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            _buildStepperItem(
              stepIndex: 1,
              title: "Property Details",
              content: _buildStep1Content(),
              isLast: false,
            ),
            _buildStepperItem(
              stepIndex: 2,
              title: "Payment Plan",
              content: _buildStep2Content(),
              isLast: false,
            ),
            _buildStepperItem(
              stepIndex: 3,
              title: "Loan Config",
              content: _buildStep3Content(),
              isLast: false,
            ),
            _buildStepperItem(
              stepIndex: 4,
              title: "Exit Scenarios",
              content: _buildStep4Content(),
              isLast: true,
            ),
          ],
        ),
      );
    }); // ✅ Close Obx
  }

  // --- WIDGET HELPERS (UPDATED FOR DARK MODE) ---

  // 1. Updated Glass Decoration
  BoxDecoration _glassDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF1E293B)
          : Colors.white, // Dark Slate vs White
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
          blurRadius: 4,
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.headerLightEnd.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerLightStart.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.headerLightEnd.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.tune, color: AppColors.headerLightEnd),
              ),
              const SizedBox(width: 12),
              // Dynamic Text Color
              const Text(
                "Inputs",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _confirmReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              minimumSize: const Size(0, 32),
            ),
            child: const Text("Reset", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  bool _validateCurrentStep(int step) {
    // 1. Get Active Property Safely
    List props = controller.propertyData['properties'] as List? ?? [];
    var matchingProps = props.where(
      (p) => p['id'] == controller.userSelections['selectedPropertyId'],
    );
    var activeProp = matchingProps.isNotEmpty
        ? matchingProps.first
        : (props.isNotEmpty ? props[0] : {});
    var assumptions = controller.propertyData['assumptions'];

    // Helper to check emptiness
    bool isEmpty(dynamic val) {
      if (val == null) return true;
      if (val is String && val.trim().isEmpty) return true;
      if (val is num && val <= 0) return true;
      return false;
    }

    String? errorMsg;

    // --- STEP 1 CHECKS ---
    if (step == 1) {
      if (isEmpty(activeProp['name']))
        errorMsg = "Please enter a Property Name.";
      else if (isEmpty(activeProp['location']))
        errorMsg = "Please enter a Location.";
      else if (isEmpty(activeProp['size']))
        errorMsg = "Please enter Property Size.";
      else if (isEmpty(activeProp['possessionMonths']))
        errorMsg = "Please enter Possession Months.";
      else if (isEmpty(controller.propertyData['purchasePrice']))
        errorMsg = "Please enter Purchase Price.";
    }
    // --- STEP 2 CHECKS ---
    else if (step == 2) {
      if (isEmpty(assumptions['investmentPeriod']))
        errorMsg = "Please enter a valid Holding Period.";

      // Custom Plan 100% Check
      if (controller.propertyData['paymentPlan'] == 'custom') {
        double total =
            (double.tryParse(assumptions['downPaymentShare'].toString()) ?? 0) +
            (double.tryParse(assumptions['personalLoan1Share'].toString()) ??
                0) +
            (double.tryParse(assumptions['personalLoan2Share'].toString()) ??
                0) +
            (double.tryParse(assumptions['homeLoanShare'].toString()) ?? 0);
        if ((total - 100).abs() > 0.1)
          errorMsg =
              "Total allocation is ${total.toStringAsFixed(1)}%. It must be exactly 100%.";
      }

      // CLP Logic Check
      if (controller.propertyData['paymentPlan'] == 'clp') {
        if (isEmpty(assumptions['clpDurationYears']))
          errorMsg = "Please enter Construction Duration.";
        else if (isEmpty(assumptions['bankDisbursementInterval']))
          errorMsg = "Please enter Disbursement Interval.";
        else {
          // Logic Check: Construction vs Possession
          double constrMonths =
              (double.tryParse(assumptions['clpDurationYears'].toString()) ??
                  0) *
              12;
          double possMonths =
              double.tryParse(activeProp['possessionMonths'].toString()) ?? 0;
          if (constrMonths > possMonths)
            errorMsg =
                "Construction ($constrMonths mo) cannot exceed Possession ($possMonths mo).";
        }
      }
    }
    // --- STEP 3 CHECKS ---
    else if (step == 3) {
      if (isEmpty(assumptions['homeLoanRate']))
        errorMsg = "Please enter Home Loan Rate.";
      else if (isEmpty(assumptions['homeLoanTerm']))
        errorMsg = "Please enter Home Loan Tenure.";

      // PL1 Validation
      double pl1Share =
          double.tryParse(assumptions['personalLoan1Share'].toString()) ?? 0;
      if (pl1Share > 0) {
        if (isEmpty(assumptions['personalLoan1Rate']))
          errorMsg = "Please enter Personal Loan 1 Rate.";
        else if (isEmpty(assumptions['personalLoan1Term']))
          errorMsg = "Please enter Personal Loan 1 Tenure.";
      }

      // PL2 Validation
      double pl2Share =
          double.tryParse(assumptions['personalLoan2Share'].toString()) ?? 0;
      if (pl2Share > 0) {
        if (isEmpty(assumptions['personalLoan2Rate']))
          errorMsg = "Please enter Personal Loan 2 Rate.";
        else if (isEmpty(assumptions['personalLoan2Term']))
          errorMsg = "Please enter Personal Loan 2 Tenure.";
      }
    }
    // --- STEP 4 CHECKS ---
    else if (step == 4) {
      if (isEmpty(controller.userSelections['selectedExitPrice']))
        errorMsg = "Please enter an Expected Exit Price.";
    }

    // --- DISPLAY ERROR ---
    if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(errorMsg)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return false; // Validation Failed
    }
    return true; // Validation Passed
  }

  Widget _buildStepperItem({
    required int stepIndex,
    required String title,
    required Widget content,
    required bool isLast,
  }) {
    bool isActive = _currentStep == stepIndex;
    bool isCompleted = _currentStep > stepIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color lineColor = isCompleted
        ? Colors.green
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade300);

    return IntrinsicHeight(
      // Remove this if possible, but Stack inside works fine too.
      // Better approach: Remove IntrinsicHeight entirely and use Stack to draw line
      child: Stack(
        children: [
          // 1. THE VERTICAL LINE (Background)
          if (!isLast)
            Positioned(
              top: 32, // Start below the circle
              bottom: 0, // Stretch to the very bottom
              left: 15, // Center align with the 32px circle (16 - 1 width/2)
              width: 2,
              child: Container(color: lineColor),
            ),

          // 2. THE CONTENT (Foreground)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- LEFT SIDE: Just the Circle ---
              Column(
                children: [
                  InkWell(
                    onTap: () => _goToStep(stepIndex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green
                            : (isActive
                                  ? AppColors.headerLightEnd
                                  : (isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200)),
                        shape: BoxShape.circle,
                        border: isActive
                            ? Border.all(
                                color: isDark ? Colors.white : Colors.white,
                                width: 2,
                              )
                            : Border.all(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.transparent,
                              ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.headerLightEnd.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : Text(
                                "$stepIndex",
                                style: TextStyle(
                                  color: isActive ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 16),

              // --- RIGHT SIDE: Content ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _goToStep(stepIndex),
                      child: Container(
                        // Min height ensures space for line even when collapsed
                        constraints: const BoxConstraints(minHeight: 40),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isActive || isCompleted
                                ? (isDark ? Colors.white : Colors.black87)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),

                    AnimatedCrossFade(
                      firstChild: Container(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          children: [
                            content,
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (stepIndex > 1)
                                  OutlinedButton(
                                    onPressed: () => _goToStep(stepIndex - 1),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.black12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                    ),
                                    child: const Text("Back"),
                                  )
                                else
                                  const SizedBox(),

                                ElevatedButton.icon(
                                  onPressed: () {
                                    // ✅ NEW: Validate before proceeding
                                    if (_validateCurrentStep(stepIndex)) {
                                      if (isLast) {
                                        widget.onAnalyze();
                                      } else {
                                        _goToStep(stepIndex + 1);
                                      }
                                    }
                                  },
                                  icon: isLast
                                      ? const Icon(Icons.analytics)
                                      : const Icon(Icons.arrow_forward),
                                  label: Text(isLast ? "Analyze" : "Next"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.headerLightEnd,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: isActive
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- UPDATED INPUT WIDGET WITH RED STAR SUPPORT ---
  Widget _buildInput(
    String label,
    dynamic value,
    Function(String) onChanged, {
    String? prefix,
    String? hint,
    TextInputType keyboardType = TextInputType.number,
    TextEditingController? controller,
    bool isRequired = false, // <--- ✅ NEW PARAMETER
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ NEW: RichText allows mixing colors (Gray Text + Red Star)
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white70
                  : const Color.fromARGB(255, 58, 56, 56),
              fontFamily: Theme.of(
                context,
              ).textTheme.bodyMedium?.fontFamily, // Uses default font
            ),
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: TextFormField(
            key: ValueKey(
              "${label}_${Get.find<PropertyController>().results.length}",
            ),
            controller: controller,
            initialValue: controller != null ? null : _formatValue(value),
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              prefixText: prefix,
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                fontSize: 13,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.headerLightEnd,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<Map<String, String>> items,
    Function(String) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isDark ? Colors.transparent : Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              dropdownColor: isDark
                  ? const Color(0xFF1E293B)
                  : Colors.white, // Fix popup background
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
              ), // Fix selected text color
              items: items
                  .map(
                    (i) => DropdownMenuItem(
                      value: i['val'],
                      child: Text(
                        i['label']!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => onChanged(v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccordionSection({
    required String id,
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    bool isOpen = _activeAccordion == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _glassDecoration(), // Uses the updated decoration
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleAccordion(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: content,
            ),
        ],
      ),
    );
  }

  // --- STEPS CONTENT (UNCHANGED LOGIC, JUST USES NEW HELPERS) ---
  // (Paste _buildStep1Content, _buildStep2Content, _buildStep3Content, _buildStep4Content here)
  // Since the helpers (_buildInput, _buildDropdown) now handle the theme,
  // you can just paste the previous content blocks here.

  Widget _buildStep1Content() {
    final properties = controller.propertyData['properties'] as List;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _buildAccordionSection(
          id: 'prop_mgmt',
          title: "Properties (${properties.length})",
          icon: Icons.apartment,
          content: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _addProperty,
                  icon: const Icon(Icons.add_circle, size: 14),
                  label: const Text("Add", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.headerLightEnd,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(70, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...properties.asMap().entries.map((entry) {
                int idx = entry.key;
                Map<String, dynamic> prop = entry.value;
                return Container(
                  key: ValueKey(prop['id']),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: _glassDecoration(),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white10
                              : Colors.grey.shade50, // Dark mode header
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.headerLightEnd,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "#${idx + 1}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (properties.length > 1)
                              InkWell(
                                onTap: () => _removeProperty(idx),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            _buildInput(
                              "Property Name",
                              prop['name'],
                              (v) {
                                prop['name'] = v;
                                controller.saveData();
                              },
                              hint: "e.g. Supernova",
                              keyboardType: TextInputType.text,
                              isRequired: true,
                            ),
                            const SizedBox(height: 8),
                            _buildInput(
                              "Location",
                              prop['location'],
                              (v) {
                                prop['location'] = v;
                                controller.saveData();
                              },
                              hint: "e.g. Noida",
                              keyboardType: TextInputType.text,
                              isRequired: true,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInput(
                                    "Size (sq.ft)",
                                    prop['size'],
                                    (v) {
                                      prop['size'] = v;
                                      if (prop['id'] ==
                                          controller
                                              .userSelections['selectedPropertyId'])
                                        controller
                                                .userSelections['selectedPropertySize'] =
                                            v;
                                      controller.saveData();
                                    },
                                    hint: "e.g. 1250",
                                    isRequired: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildInput(
                                    "Possession (Mo)",
                                    prop['possessionMonths'],
                                    (v) {
                                      prop['possessionMonths'] = v;
                                      controller.saveData();
                                    },
                                    hint: "e.g. 24",
                                    isRequired: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildAccordionSection(
          id: 'fin_basics',
          title: "Financial & Tax Details",
          icon: Icons.attach_money,
          content: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      "Price (₹/sq.ft) ",
                      controller.propertyData['purchasePrice'],
                      (v) => controller.updateInput(
                        'purchasePrice',
                        v,
                      ), // ✅ Uses Controller Logic
                      hint: "e.g. 6500",
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                      "Other Charges",
                      controller.propertyData['otherCharges'],
                      (v) => controller.updateInput(
                        'otherCharges',
                        v,
                      ), // ✅ Cleaner & Consistent
                      hint: "Lumpsum",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      "Stamp Duty (%)",
                      controller.propertyData['stampDuty'],
                      (v) => controller.updateInput(
                        'stampDuty',
                        v,
                      ), // ✅ Uses Controller Logic
                      hint: "e.g. 5",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                      "GST (%)",
                      controller.propertyData['gstPercentage'],
                      (v) => controller.updateInput(
                        'gstPercentage',
                        v,
                      ), // ✅ Uses Controller Logic
                      hint: "e.g. 5",
                      isRequired: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Content() {
    final assumptions = controller.propertyData['assumptions'];
    return Column(
      children: [
        _buildDropdown(
          "Select Payment Plan",
          controller.propertyData['paymentPlan'],
          [
            {'val': 'clp', 'label': 'CLP (Construction Linked)'},
            {'val': '80-20', 'label': '80:20 (80% HL)'},
            {'val': '25-75', 'label': '25:75 (75% HL)'},
            {'val': 'rtm', 'label': 'Ready to Move'},
            {'val': 'custom', 'label': 'Custom'},
          ],
          (v) => controller.updateInput(
            'paymentPlan',
            v,
          ), // ✅ Cleaner & Consistent
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInput(
                "Holding Period",
                assumptions['investmentPeriod'],
                (v) => controller.updateAssumption(
                  'investmentPeriod',
                  v,
                ), // ✅ Uses Controller Logic
                hint: "e.g. 5",
                isRequired: true,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 100,
              margin: const EdgeInsets.only(top: 22),
              height: 40,
              decoration:
                  _glassDecoration(), // Reuse glass decoration for dropdown container
              child: Center(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: assumptions['holdingPeriodUnit'] ?? 'years',
                    isDense: true,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'years', child: Text("Years")),
                      DropdownMenuItem(value: 'months', child: Text("Months")),
                    ],
                    onChanged: (v) => controller.updateAssumption(
                      'holdingPeriodUnit',
                      v,
                    ), // ✅ Uses Controller Logic
                  ),
                ),
              ),
            ),
          ],
        ),
        // ... inside _buildStep2Content ...

        // CLP Specifics (Updated with Funding Window)
        if (controller.propertyData['paymentPlan'] == 'clp') ...[
          const SizedBox(height: 12),
          _buildAccordionSection(
            id: 'clp_details',
            title: "Construction Details",
            icon: Icons.construction,
            content: Column(
              children: [
                // Row 1: Duration & Interval
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(
                        "Duration (Yrs)",
                        assumptions['clpDurationYears'],
                        (v) => controller.updateAssumption(
                          'clpDurationYears',
                          v,
                        ), // ✅ Uses Controller Logic
                        hint: "e.g. 2",
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInput(
                        "Interval (Mo)",
                        assumptions['bankDisbursementInterval'],
                        (v) => controller.updateAssumption(
                          'bankDisbursementInterval',
                          v,
                        ), // ✅ Uses Controller Logic
                        hint: "e.g. 3",
                        isRequired: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Row 2: Bank Funding Window (Styled Box)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "BANK FUNDING WINDOW",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput(
                              "First Disb. (Mo)",
                              assumptions['bankDisbursementStartMonth'],
                              (v) => controller.updateAssumption(
                                'bankDisbursementStartMonth',
                                v,
                              ), // ✅ Uses Controller Logic
                              hint: "e.g. 2",
                            ),
                          ),
                          const SizedBox(width: 10),
                          // ... inside the Bank Funding Window Row ...
                          Expanded(
                            child: Builder(
                              builder: (ctx) {
                                // 1. Get the list safely from Controller
                                List props =
                                    controller.propertyData['properties']
                                        as List? ??
                                    [];

                                // 2. Find the active property using Controller selections
                                var matchingProps = props.where(
                                  (p) =>
                                      p['id'] ==
                                      controller
                                          .userSelections['selectedPropertyId'],
                                );

                                // 3. Fallback logic
                                var activeProp = matchingProps.isNotEmpty
                                    ? matchingProps.first
                                    : (props.isNotEmpty ? props[0] : {});

                                // 4. Parse possession
                                int poss =
                                    int.tryParse(
                                      activeProp['possessionMonths']
                                              ?.toString() ??
                                          '24',
                                    ) ??
                                    24;
                                int safeLast = (poss - 6) > 0 ? (poss - 6) : 24;

                                return _buildInput(
                                  "Last Disb. (Mo)",
                                  controller
                                      .propertyData['assumptions']['lastBankDisbursementMonth'], // ✅ Read from Controller
                                  (v) => controller.updateAssumption(
                                    'lastBankDisbursementMonth',
                                    v,
                                  ), // ✅ Uses Controller Logic
                                  hint: "e.g. $safeLast",
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Stops IDC growth (e.g. when structure is ready)",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ======================================================
  // 📝 CONTENT: Step 3 (Loan Config - Updated Logic)
  // ======================================================
  Widget _buildStep3Content() {
    final assumptions = controller.propertyData['assumptions'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String getLoanAmount(String shareKey) {
      double price =
          double.tryParse(
            controller.propertyData['purchasePrice'].toString(),
          ) ??
          0;
      double size =
          double.tryParse(
            controller.userSelections['selectedPropertySize'].toString(),
          ) ??
          0;
      double share = double.tryParse(assumptions[shareKey].toString()) ?? 0;
      double total = price * size;
      return "₹${(total * (share / 100)).toStringAsFixed(0)}";
    }

    return Column(
      children: [
        // --- 1. HOME LOAN SECTION ---
        _buildAccordionSection(
          id: 'hl_config',
          title: "Home Loan Details",
          icon: Icons.account_balance,
          content: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      "Rate (%)",
                      assumptions['homeLoanRate'],
                      (v) => controller.updateAssumption(
                        'homeLoanRate',
                        v,
                      ), // ✅ Correct
                      hint: "e.g. 8.5",
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                      "Tenure (Yrs)",
                      assumptions['homeLoanTerm'],
                      (v) => controller.updateAssumption(
                        'homeLoanTerm',
                        v,
                      ), // ✅ Correct
                      hint: "e.g. 20",
                      isRequired: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // EMI Start Logic Toggle Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "EMI Start Logic",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.grey,
                          ),
                        ),
                        ToggleButtons(
                          isSelected: [
                            (assumptions['homeLoanStartMode'] ?? 'default') ==
                                'default',
                            assumptions['homeLoanStartMode'] == 'manual',
                          ],
                          onPressed: (idx) {
                            controller.updateAssumption(
                              'homeLoanStartMode',
                              idx == 0 ? 'default' : 'manual',
                            ); // ✅ Correct
                          },
                          borderRadius: BorderRadius.circular(8),
                          constraints: const BoxConstraints(
                            minHeight: 28,
                            minWidth: 60,
                          ),
                          color: isDark ? Colors.white60 : Colors.black54,
                          selectedColor: Colors.white,
                          fillColor: AppColors.headerLightEnd,
                          children: const [
                            Text("Auto", style: TextStyle(fontSize: 11)),
                            Text("Manual", style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Logic Display
                    if (assumptions['homeLoanStartMode'] == 'manual')
                      _buildInput(
                        "Exact Start Month",
                        assumptions['homeLoanStartMonth'],
                        (v) => controller.updateAssumption(
                          'homeLoanStartMonth',
                          v,
                        ), // ✅ Correct
                        hint: "e.g. 25",
                        isRequired: true,
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white,
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.blue.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Linked to Construction",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Calculate display value
                            Builder(
                              builder: (context) {
                                int last =
                                    int.tryParse(
                                      assumptions['lastBankDisbursementMonth']
                                          .toString(),
                                    ) ??
                                    0;
                                return Text(
                                  "Month ${last + 1}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 46, 104, 151),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // --- 2. PERSONAL LOAN 1 (With Visual Slider) ---
        _buildAccordionSection(
          id: 'pl1_config',
          title: "Personal Loan 1 Details",
          icon: Icons.credit_score,
          content: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      "Share (%)",
                      assumptions['personalLoan1Share'],
                      (v) => controller.updateAssumption(
                        'personalLoan1Share',
                        v,
                      ), // ✅ Correct
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStaticInfo(
                      "Amount",
                      getLoanAmount('personalLoan1Share'),
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      "Tenure (Yrs)",
                      assumptions['personalLoan1Term'],
                      (v) => controller.updateAssumption(
                        'personalLoan1Term',
                        v,
                      ), // ✅ Correct
                      hint: "e.g. 7",
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                      "Rate (%)",
                      assumptions['personalLoan1Rate'],
                      (v) => controller.updateAssumption(
                        'personalLoan1Rate',
                        v,
                      ), // ✅ Correct
                      hint: "e.g. 10.5",
                      isRequired: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildSliderWithTicks(
                "Start Month",
                assumptions['personalLoan1StartMonth'],
                84,
                (v) => controller.updateAssumption(
                  'personalLoan1StartMonth',
                  v,
                ), // ✅ Correct
                isDark,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "Independent of possession",
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.white38 : Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // --- 3. PERSONAL LOAN 2 ---
        _buildAccordionSection(
          id: 'pl2_config',
          title: "Personal Loan 2 Details",
          icon: Icons.credit_score,
          content: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      "Share (%)",
                      assumptions['personalLoan2Share'],
                      (v) => controller.updateAssumption(
                        'personalLoan2Share',
                        v,
                      ), // ✅ Correct
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStaticInfo(
                      "Amount",
                      getLoanAmount('personalLoan2Share'),
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      "Tenure (Yrs)",
                      assumptions['personalLoan2Term'],
                      (v) => controller.updateAssumption(
                        'personalLoan2Term',
                        v,
                      ), // ✅ Correct
                      hint: "e.g. 7",
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                      "Rate (%)",
                      assumptions['personalLoan2Rate'],
                      (v) => controller.updateAssumption(
                        'personalLoan2Rate',
                        v,
                      ), // ✅ Correct
                      hint: "e.g. 10.5",
                      isRequired: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildSliderWithTicks(
                "Start Month (After Poss.)",
                assumptions['personalLoan2StartMonth'],
                36,
                (v) => controller.updateAssumption(
                  'personalLoan2StartMonth',
                  v,
                ), // ✅ Correct
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- NEW HELPERS FOR THIS STEP ---

  Widget _buildStaticInfo(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          height: 38,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderWithTicks(
    String label,
    dynamic value,
    double maxVal,
    Function(String) onChanged,
    bool isDark,
  ) {
    // 1. Safe Parse
    double parsedVal = double.tryParse(value.toString()) ?? 0;

    // 2. Safe Clamp (Prevents crash if saved value > maxVal)
    double currentVal = parsedVal.clamp(0.0, maxVal);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            Text(
              "Month ${currentVal.toInt()}",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.center,
          children: [
            // Ticks background
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                9,
                (index) => Container(
                  width: 1,
                  height: 6,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
            ),
            // The Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: AppColors.headerLightEnd,
                inactiveTrackColor: isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade200,
                thumbColor: AppColors.headerLightEnd,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: currentVal, // Uses the clamped safe value
                min: 0,
                max: maxVal,
                divisions: maxVal > 0
                    ? maxVal.toInt()
                    : 1, // Prevents division by zero
                onChanged: (v) => onChanged(v.toInt().toString()),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("0", style: TextStyle(fontSize: 9, color: Colors.grey)),
            Text(
              maxVal.toInt().toString(),
              style: TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep4Content() {
    return Column(
      children: [
        _buildInput(
          "Expected Exit Price (Base) *",
          controller.userSelections['selectedExitPrice'],
          (v) => controller.updateSelection('selectedExitPrice', v),
          prefix: "₹",
          hint: "e.g. 6000",
          controller: _exitPriceCtrl,
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addExitScenario,
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Add Higher Scenario (+500)"),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (controller.userSelections['scenarioExitPrices'] as List)
              .asMap()
              .entries
              .map((entry) {
                return Chip(
                  label: Text("₹${entry.value}"),
                  deleteIcon: const Icon(Icons.cancel, size: 16),
                  onDeleted: () => _removeExitScenario(entry.key),
                  backgroundColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                );
              })
              .toList(),
        ),
      ],
    );
  }
}
