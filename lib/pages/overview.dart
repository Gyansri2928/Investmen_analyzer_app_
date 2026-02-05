import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:property_analyzer_mobile/controller/property_controller.dart';
import '../service/export_service.dart';
import '../main.dart'; // For AppColors

class OverviewTab extends StatelessWidget {
  final Map<String, dynamic>? results;
  final Function(int) onTabChange;

  const OverviewTab({super.key, this.results, required this.onTabChange});

  // --- LOGIC (Kept exactly as provided) ---
  Map<String, dynamic>? _calculateStrategy(
    Map<String, dynamic> breakdown,
    Map<String, dynamic> assumptions,
  ) {
    if (results == null) return null;
    if (breakdown['paymentPlan'] != 'clp' &&
        (breakdown['homeLoanAmount'] ?? 0) <= 0)
      return null;

    double hlAmount =
        double.tryParse(breakdown['homeLoanAmount'].toString()) ?? 0;
    double rate = double.tryParse(assumptions['homeLoanRate'].toString()) ?? 0;
    int tenure = int.tryParse(assumptions['homeLoanTerm'].toString()) ?? 20;
    int possession =
        int.tryParse(breakdown['possessionMonths'].toString()) ?? 24;
    int interval =
        int.tryParse(assumptions['bankDisbursementInterval'].toString()) ?? 3;

    double monthlyRate = rate / 12 / 100;
    double months = tenure * 12.0;
    double fullEMI = 0;
    if (monthlyRate > 0) {
      fullEMI =
          (hlAmount * monthlyRate * pow(1 + monthlyRate, months)) /
          (pow(1 + monthlyRate, months) - 1);
    } else {
      fullEMI = hlAmount / months;
    }

    double stdTotal = 0;
    double cumDisb = 0;
    int slabs = (breakdown['idcSchedule'] as List?)?.length ?? 1;
    double slabAmt = hlAmount / slabs;

    for (int m = 1; m <= possession; m++) {
      if (m % interval == 0 && cumDisb < hlAmount) {
        cumDisb += slabAmt;
        if (cumDisb > hlAmount) cumDisb = hlAmount;
      }
      stdTotal += (cumDisb * (rate / 100)) / 12;
    }

    double manTotal = 0;
    double manBal = 0;
    double manPrin = 0;
    cumDisb = 0;

    for (int m = 1; m <= possession; m++) {
      if (m % interval == 0 && cumDisb < hlAmount) {
        cumDisb += slabAmt;
        manBal += slabAmt;
        if (cumDisb > hlAmount) cumDisb = hlAmount;
      }
      double interest = (manBal * (rate / 100)) / 12;
      double prin = fullEMI - interest;
      manBal -= prin;
      manPrin += prin;
      manTotal += fullEMI;
    }

    return {
      'stdTotal': stdTotal,
      'stdBalance': hlAmount,
      'smartTotal': manTotal,
      'smartBalance': hlAmount - manPrin,
      'savings': manPrin,
    };
  }

  // --- HELPERS ---
  void _generateExcel(BuildContext context, Map<String, dynamic> data) async {
    Get.snackbar(
      "Exporting...",
      "Preparing Excel file",
      snackPosition: SnackPosition.BOTTOM,
    );
    await ExportService.exportToExcel(data);
  }

  void _generatePDF(BuildContext context, Map<String, dynamic> data) async {
    Get.snackbar(
      "Exporting...",
      "Preparing PDF Report",
      snackPosition: SnackPosition.BOTTOM,
    );
    await ExportService.exportToPDF(data);
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return "₹0";
    double val = double.tryParse(value.toString()) ?? 0;
    String result = val.toStringAsFixed(0);
    if (result.length <= 3) return "₹$result";
    String lastThree = result.substring(result.length - 3);
    String otherNumbers = result.substring(0, result.length - 3);
    if (otherNumbers.isNotEmpty) lastThree = ',$lastThree';
    String formattedLeft = otherNumbers.replaceAllMapped(
      RegExp(r'\B(?=(\d{2})+(?!\d))'),
      (m) => ",",
    );
    return "₹$formattedLeft$lastThree";
  }

  String _formatLakhs(dynamic value) {
    if (value == null) return "₹0L";
    double val = double.tryParse(value.toString()) ?? 0;
    return "₹${(val / 100000).toStringAsFixed(2)}L";
  }

  String _formatPercent(dynamic value) {
    if (value == null) return "0%";
    double val = double.tryParse(value.toString()) ?? 0;
    return "${val.toStringAsFixed(1)}%";
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PropertyController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Modern Color Palette
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final shadowColor = isDark ? Colors.black26 : Colors.grey.withOpacity(0.1);
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;

    if (results == null || results!['detailedBreakdown'] == null) {
      return _buildEmptyState(subTextColor);
    }

    final breakdown = results!['detailedBreakdown'];
    final scenarios = results!['multipleScenarios'] ?? [];
    final Map<String, dynamic> assumptions =
        controller.propertyData['assumptions'] ?? {};
    final strategyData = _calculateStrategy(breakdown, assumptions);
    final double purchasePrice =
        double.tryParse(controller.propertyData['purchasePrice'].toString()) ??
        0;
    final double otherCharges =
        double.tryParse(controller.propertyData['otherCharges'].toString()) ??
        0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // 1. Header
          _AnimatedEntry(
            delay: 0,
            child: _buildHeader(context, cardColor, textColor, shadowColor),
          ),

          const SizedBox(height: 24),

          // 2. Stats Grid
          _AnimatedEntry(
            delay: 100,
            child: _buildModernStatsGrid(breakdown, isDark),
          ),

          const SizedBox(height: 24),

          // 3. Stage Breakdown (Matches Image Content)
          _AnimatedEntry(
            delay: 200,
            child: _buildDetailedStages(
              breakdown,
              purchasePrice,
              otherCharges,
              isDark,
            ),
          ),

          const SizedBox(height: 24),

          // 4. Animated Profit Chart
          if (scenarios.isNotEmpty)
            _AnimatedEntry(
              delay: 300,
              child: _buildAnimatedProfitChart(
                scenarios,
                cardColor,
                textColor,
                isDark,
              ),
            ),

          const SizedBox(height: 24),

          // 5. Scenario Table (RESTORED)
          if (scenarios.isNotEmpty)
            _AnimatedEntry(
              delay: 350,
              child: _buildScenarioTable(
                scenarios,
                cardColor,
                borderColor,
                shadowColor,
                textColor,
                subTextColor,
                isDark,
                context,
              ),
            ),

          const SizedBox(height: 24),

          // 6. Strategy Comparison (Original Design)
          if (strategyData != null)
            _AnimatedEntry(
              delay: 400,
              child: _buildStrategySection(
                strategyData,
                cardColor,
                borderColor,
                shadowColor,
                textColor,
              ),
            ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildEmptyState(Color subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: subTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              "Ready to Analyze",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Enter property details to see ROI, Cash Flow, and Loan Strategy.",
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => onTabChange(0),
              icon: const Icon(Icons.arrow_forward),
              label: const Text("Go to Inputs"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.headerLightEnd,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color cardColor,
    Color textColor,
    Color shadowColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Overview",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    "Investment Summary",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildIconButton(
                Icons.table_view,
                Colors.green,
                () => _generateExcel(context, results!),
              ),
              const SizedBox(width: 10),
              _buildIconButton(
                Icons.picture_as_pdf,
                Colors.red,
                () => _generatePDF(context, results!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _buildModernStatsGrid(Map<String, dynamic> breakdown, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard(
              "Total Cost",
              _formatLakhs(breakdown['totalCost']),
              Icons.monetization_on,
              Colors.blue,
              isDark,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              "Net Profit",
              _formatLakhs(breakdown['netGainLoss']),
              Icons.trending_up,
              (breakdown['netGainLoss'] ?? 0) >= 0 ? Colors.green : Colors.red,
              isDark,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              "ROI",
              _formatPercent(breakdown['roi']),
              Icons.percent,
              Colors.orange,
              isDark,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              "Cash Out",
              _formatLakhs(breakdown['leftoverCash']),
              Icons.account_balance_wallet,
              Colors.teal,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STAGE BREAKDOWN (Replaces Tabs with 4 Cards matching Image) ---
  Widget _buildDetailedStages(
    Map<String, dynamic> breakdown,
    double purchasePrice,
    double otherCharges,
    bool isDark,
  ) {
    // Calculate Total PL Amount for Stage 2
    double pl1 =
        double.tryParse(breakdown['personalLoan1Amount'].toString()) ?? 0;
    double pl2 =
        double.tryParse(breakdown['personalLoan2Amount'].toString()) ?? 0;
    double totalPL = pl1 + pl2;

    return Column(
      children: [
        Row(
          children: [
            Text(
              "Stage-wise Calculation Breakdown",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Stage 1: Cost (Blue Header)
        _buildStageCard(
          "Stage 1: Cost",
          Icons.sell,
          const Color(0xFF2563EB), // Blue
          [
            {
              "label": "Property Size",
              "value": "${breakdown['propertySize'] ?? 0} sq.ft",
            },
            {"label": "Purchase Price", "value": "₹$purchasePrice/sq.ft"},
            {"label": "Other Charges", "value": _formatCurrency(otherCharges)},
            {
              "label": "Stamp Duty",
              "value": _formatCurrency(breakdown['stampDutyCost']),
            },
            {
              "label": "GST Charges",
              "value": _formatCurrency(breakdown['gstCost']),
            },
            {
              "label": "Total Property Cost",
              "value": _formatCurrency(breakdown['totalCost']),
            },
          ],
          isDark,
        ),
        const SizedBox(height: 12),

        // Stage 2: Funding (Green Header)
        _buildStageCard(
          "Stage 2: Funding",
          Icons.pie_chart,
          const Color(0xFF16A34A), // Green
          [
            {
              "label": "Down Payment",
              "value":
                  "${breakdown['downPaymentShare']}% (${_formatCurrency(breakdown['downPaymentAmount'])})",
            },
            {
              "label": "Home Loan",
              "value":
                  "${breakdown['homeLoanShare']}% (${_formatCurrency(breakdown['homeLoanAmount'])})",
            },
            {
              "label": "PL1",
              "value":
                  "${breakdown['personalLoan1Share']}% (${_formatCurrency(breakdown['personalLoan1Amount'])})",
            },
            {
              "label": "PL2",
              "value":
                  "${breakdown['personalLoan2Share']}% (${_formatCurrency(breakdown['personalLoan2Amount'])})",
            },
            {"label": "Total PL Amount", "value": _formatCurrency(totalPL)},
          ],
          isDark,
        ),
        const SizedBox(height: 12),

        // Stage 3: Monthly (Orange/Yellow Header)
        _buildStageCard(
          "Stage 3: Monthly",
          Icons.calendar_month,
          const Color(0xFFCA8A04), // Yellow-Orange
          [
            {
              "label": "Home Loan EMI",
              "value": "${_formatCurrency(breakdown['homeLoanEMI'])}/month",
            },
            {
              "label": "PL1 EMI",
              "value":
                  "${_formatCurrency(breakdown['personalLoan1EMI'])}/month",
            },
            {
              "label": "PL2 EMI",
              "value":
                  "${_formatCurrency(breakdown['personalLoan2EMI'])}/month",
            },
            {
              "label": "Total Monthly",
              "value":
                  "${_formatCurrency(breakdown['postPossessionEMI'])}/month",
            },
          ],
          isDark,
        ),
        const SizedBox(height: 12),

        // Stage 4: Exit (Cyan/Teal Header)
        _buildStageCard(
          "Stage 4: Exit",
          Icons.door_back_door,
          const Color(0xFF0891B2), // Cyan
          [
            {"label": "Duration", "value": "${breakdown['years']} years"},
            {
              "label": "Possession",
              "value": "After ${breakdown['possessionMonths']} months",
            },
            {
              "label": "Exit Price",
              "value": "₹${breakdown['exitPrice']}/sq.ft",
            },
            {
              "label": "Sale Value",
              "value": _formatCurrency(breakdown['saleValue']),
            },
          ],
          isDark,
        ),
      ],
    );
  }

  Widget _buildStageCard(
    String title,
    IconData icon,
    Color headerColor,
    List<Map<String, String>> items,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Colored Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: headerColor,
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        item['value']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedProfitChart(
    List<dynamic> scenarios,
    Color cardColor,
    Color textColor,
    bool isDark,
  ) {
    double maxProfit = 0;
    for (var s in scenarios) {
      double p = double.tryParse(s['netProfit'].toString()) ?? 0;
      if (p.abs() > maxProfit) maxProfit = p.abs();
    }
    if (maxProfit == 0) maxProfit = 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Profit Scenarios",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: scenarios.map<Widget>((s) {
              double profit = double.tryParse(s['netProfit'].toString()) ?? 0;
              bool isNegative = profit < 0;
              bool isSelected = s['isSelected'] == true;
              double percentage = (profit.abs() / maxProfit);

              return Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percentage),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.elasticOut,
                    builder: (context, val, _) {
                      return Container(
                        width: 40,
                        height: 120 * val,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isNegative
                                ? [Colors.red.shade900, Colors.red.shade400]
                                : isSelected
                                ? [
                                    const Color(0xFF1E3A8A),
                                    const Color(0xFF3B82F6),
                                  ]
                                : [Colors.blue.shade200, Colors.blue.shade400],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "@${s['exitPrice'].toInt()}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatLakhs(profit),
                    style: TextStyle(
                      fontSize: 10,
                      color: isNegative ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- SCENARIO TABLE (RESTORED) ---
  Widget _buildScenarioTable(
    List<dynamic> scenarios,
    Color cardColor,
    Color borderColor,
    Color shadowColor,
    Color textColor,
    Color subTextColor,
    bool isDark,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_chart, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                "Multiple Exit Scenarios",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${scenarios.length} scenarios",
                  style: TextStyle(fontSize: 10, color: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 64,
              ),
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 50,
                columnSpacing: 20,
                border: TableBorder(bottom: BorderSide(color: borderColor)),
                columns: [
                  DataColumn(
                    label: Text(
                      "Price",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: subTextColor,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Sale Value",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: subTextColor,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Net Profit",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: subTextColor,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "ROI",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: subTextColor,
                      ),
                    ),
                  ),
                ],
                rows: scenarios.map<DataRow>((s) {
                  bool isSel = s['isSelected'] == true;
                  double profit =
                      double.tryParse(s['netProfit'].toString()) ?? 0;
                  return DataRow(
                    color: WidgetStateProperty.all(
                      isSel
                          ? (isDark
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.blue.shade50)
                          : Colors.transparent,
                    ),
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            Text(
                              "₹${s['exitPrice'].toStringAsFixed(0)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: textColor,
                              ),
                            ),
                            if (isSel)
                              Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatLakhs(s['saleValue']),
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatLakhs(s['netProfit']),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: profit >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatPercent(s['roi']),
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STRATEGY SECTION (ORIGINAL DESIGN RESTORED) ---
  Widget _buildStrategySection(
    Map<String, dynamic> data,
    Color cardColor,
    Color borderColor,
    Color shadowColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                "Smart Saver Strategy",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStrategyCard(
                "Standard CLP",
                double.parse(data['stdTotal'].toString()),
                double.parse(data['stdBalance'].toString()),
                0,
                false,
              ),
              const SizedBox(width: 12),
              _buildStrategyCard(
                "Full EMI",
                double.parse(data['smartTotal'].toString()),
                double.parse(data['smartBalance'].toString()),
                double.parse(data['savings'].toString()),
                true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyCard(
    String title,
    double paid,
    double balance,
    double savings,
    bool isRecommended,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRecommended
              ? Colors.blue.withOpacity(0.1)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRecommended
                ? Colors.blue.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: isRecommended ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (isRecommended)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "SMART CHOICE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              _formatCurrency(paid),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Paid till Possession",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const Divider(height: 24),
            const Text(
              "Loan Balance",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              _formatLakhs(balance),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isRecommended ? Colors.green : Colors.red,
              ),
            ),
            if (isRecommended) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "Save ${_formatLakhs(savings)} on Principal",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- ANIMATION HELPER ---
class _AnimatedEntry extends StatelessWidget {
  final Widget child;
  final int delay;
  const _AnimatedEntry({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}
