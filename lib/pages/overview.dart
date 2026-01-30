import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/property_controller.dart';
import '../service/export_service.dart';
import '../main.dart'; // For AppColors

// ✅ Stateless Widget (Controller handles data)
class OverviewTab extends StatelessWidget {
  // Optional parameter to maintain compatibility if called elsewhere
  // but we prefer using controller inside.
  final Map<String, dynamic>? results;
  final Function(int) onTabChange;

  const OverviewTab({super.key, this.results, required this.onTabChange});

  // --- HELPERS (Now static or instance methods) ---

  void _generateExcel(BuildContext context, Map<String, dynamic> data) async {
    Get.snackbar(
      "Exporting...",
      "Preparing Excel file",
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );

    try {
      await ExportService.exportToExcel(data);
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _generatePDF(BuildContext context, Map<String, dynamic> data) async {
    Get.snackbar(
      "Exporting...",
      "Preparing PDF Report",
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );

    try {
      await ExportService.exportToPDF(data);
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Formatting helpers
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

    // Theme Variables
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;
    final shadowColor = Colors.black.withOpacity(isDark ? 0.3 : 0.05);

    return Obx(() {
      // ✅ 1. Get Data from Controller
      final data = controller.results;

      // 2. Empty State Check
      if (data.isEmpty || (data['totalCost'] ?? 0) == 0) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, size: 64, color: subTextColor),
                const SizedBox(height: 20),
                Text(
                  "No Analysis Generated Yet",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: subTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Enter property details to see results.",
                  style: TextStyle(color: subTextColor),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () => onTabChange(0),
                  icon: const Icon(Icons.edit),
                  label: const Text("Start Analysis"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.headerLightEnd,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      List<dynamic> scenarios = data['multipleScenarios'] ?? [];

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: [BoxShadow(color: shadowColor, blurRadius: 8)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.headerLightEnd.withOpacity(
                          0.1,
                        ),
                        child: const Icon(
                          Icons.speed,
                          color: Color.fromARGB(255, 78, 111, 163),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Analysis Report",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Excel Button
                      InkWell(
                        onTap: () =>
                            _generateExcel(context, data), // Pass current data
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.table_view,
                            size: 16,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // PDF Button
                      InkWell(
                        onTap: () => _generatePDF(context, data),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf,
                            size: 16,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 1. Quick Stats Grid
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [BoxShadow(color: shadowColor, blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildGridItem(
                        "Total Cost",
                        _formatLakhs(data['totalCost']),
                        Icons.monetization_on,
                        Colors.blue,
                        textColor,
                        subTextColor,
                      ),
                      _buildGridItem(
                        "Net Profit",
                        _formatLakhs(data['netGainLoss']),
                        Icons.trending_up,
                        (data['netGainLoss'] ?? 0) >= 0
                            ? Colors.green
                            : Colors.red,
                        textColor,
                        subTextColor,
                      ),
                    ],
                  ),
                  Divider(height: 1, color: borderColor),
                  Row(
                    children: [
                      _buildGridItem(
                        "ROI",
                        _formatPercent(data['roi']),
                        Icons.percent,
                        Colors.blue,
                        textColor,
                        subTextColor,
                      ),
                      _buildGridItem(
                        "Cash After Sale",
                        _formatLakhs(data['leftoverCash']),
                        Icons.account_balance_wallet,
                        Colors.teal,
                        textColor,
                        subTextColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. Breakdown Lists
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: [BoxShadow(color: shadowColor, blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.layers, size: 18, color: subTextColor),
                      const SizedBox(width: 8),
                      Text(
                        "Stage-wise Breakdown",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),
                  _buildStageHeader(
                    "Stage 1: Basic Property Cost",
                    Icons.sell,
                    Colors.blue,
                  ),
                  _buildStageRow(
                    "Property Size",
                    "${data['propertySize'] ?? 0} sq.ft",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "Purchase Price",
                    "₹${data['purchasePrice'] ?? 0}/sq.ft",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "Stamp Duty",
                    _formatCurrency(data['stampDutyCost']),
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "GST charges",
                    _formatCurrency(data['gstCost']),
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "Total Property Cost",
                    _formatCurrency(data['totalCost']),
                    subTextColor,
                    textColor,
                  ),

                  const SizedBox(height: 15),
                  _buildStageHeader(
                    "Stage 2: Payment Plan Breakdown",
                    Icons.pie_chart,
                    Colors.green,
                  ),
                  _buildStageRow(
                    "Down Payment",
                    "${data['downPaymentShare']}% (${_formatCurrency(data['downPaymentAmount'])})",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "Home Loan",
                    "${data['homeLoanShare']}% (${_formatCurrency(data['homeLoanAmount'])})",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "PL1",
                    "${data['personalLoan1Share']}% (${_formatCurrency(data['personalLoan1Amount'])})",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "PL2",
                    "${data['personalLoan2Share']}% (${_formatCurrency(data['personalLoan2Amount'])})",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "Total PL Amount",
                    _formatCurrency(data['totalCashInvested']),
                    subTextColor,
                    textColor,
                  ),

                  const SizedBox(height: 15),
                  _buildStageHeader(
                    "Stage 3: EMI Calculations",
                    Icons.calendar_today,
                    Colors.orange,
                  ),
                  _buildStageRow(
                    "Home Loan EMI",
                    "${_formatCurrency(data['homeLoanEMI'])}/month",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "PL1 EMI",
                    "${_formatCurrency(data['personalLoan1EMI'])}/month",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "PL2 EMI",
                    "${_formatCurrency(data['personalLoan2EMI'])}/month",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "Total Monthly",
                    "${_formatCurrency((data['homeLoanEMI'] ?? 0) + (data['personalLoan1EMI'] ?? 0) + (data['personalLoan2EMI'] ?? 0))}/month",
                    subTextColor,
                    textColor,
                  ),

                  const SizedBox(height: 15),
                  _buildStageHeader(
                    "Stage 4: Holding Period",
                    Icons.door_back_door,
                    Colors.lightBlue,
                  ),
                  _buildStageRow(
                    "Duration",
                    "${data['years'] ?? 0} years (${((data['years'] ?? 0) * 12).toStringAsFixed(0)} months)",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "Possession",
                    "After ${data['possessionMonths']} months",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "Exit Price",
                    "₹${data['exitPrice']}/sq.ft",
                    subTextColor,
                    textColor,
                  ),
                  _buildStageRow(
                    "Sale Value",
                    _formatCurrency(data['saleValue']),
                    subTextColor,
                    textColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (scenarios.isNotEmpty)
              _buildProfitChart(
                scenarios,
                cardColor,
                borderColor,
                shadowColor,
                textColor,
                subTextColor,
              ),
            const SizedBox(height: 20),
            if (scenarios.isNotEmpty)
              _buildScenarioTable(
                scenarios,
                cardColor,
                borderColor,
                shadowColor,
                textColor,
                subTextColor,
                isDark,
                context,
              ),

            const SizedBox(height: 20),

            if (data['strategyComparison'] != null) ...[
              Container(
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
                          double.parse(
                            data['strategyComparison']['stdTotal'].toString(),
                          ),
                          double.parse(
                            data['strategyComparison']['stdBalance'].toString(),
                          ),
                          0,
                          false,
                        ),
                        const SizedBox(width: 12),
                        _buildStrategyCard(
                          "Full EMI",
                          double.parse(
                            data['strategyComparison']['smartTotal'].toString(),
                          ),
                          double.parse(
                            data['strategyComparison']['smartBalance']
                                .toString(),
                          ),
                          double.parse(
                            data['strategyComparison']['savings'].toString(),
                          ),
                          true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      );
    });
  }

  // --- UI WIDGETS ---

  Widget _buildGridItem(
    String label,
    String value,
    IconData icon,
    Color color,
    Color textColor,
    Color subTextColor,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStageRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 4, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: labelColor)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitChart(
    List<dynamic> scenarios,
    Color cardColor,
    Color borderColor,
    Color shadowColor,
    Color textColor,
    Color subTextColor,
  ) {
    double maxProfit = 0;
    for (var s in scenarios) {
      double p = double.tryParse(s['netProfit'].toString()) ?? 0;
      if (p.abs() > maxProfit) maxProfit = p.abs();
    }
    if (maxProfit == 0) maxProfit = 1;

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
              Icon(Icons.bar_chart, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                "Profit Potential",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: scenarios.map<Widget>((s) {
              double profit = double.tryParse(s['netProfit'].toString()) ?? 0;
              double heightFactor = (profit.abs() / maxProfit);
              bool isNegative = profit < 0;
              bool isSelected = s['isSelected'] == true;
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 120 * heightFactor,
                    decoration: BoxDecoration(
                      color: isNegative
                          ? Colors.red.shade400
                          : (isSelected
                                ? const Color(0xFF4A6FA5)
                                : const Color(0xFF6aa2e0)),
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "@${s['exitPrice'].toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    _formatLakhs(profit),
                    style: TextStyle(
                      fontSize: 9,
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
                    color: MaterialStateProperty.all(
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
