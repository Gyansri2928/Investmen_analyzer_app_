import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../main.dart'; // For AppColors
import '../controller/property_controller.dart';
import 'package:property_analyzer_mobile/pages/monthlybreakdown.dart';
import 'package:property_analyzer_mobile/pages/idc_schedule.dart';

class DetailsTab extends StatelessWidget {
  // ✅ No constructor parameters needed anymore
  const DetailsTab({super.key});

  // --- HELPERS FOR FORMATTING (INDIAN STYLE) ---
  String _formatCurrency(dynamic value) {
    if (value == null) return "₹0";
    double val = double.tryParse(value.toString()) ?? 0;
    String result = val.toStringAsFixed(0);

    if (result.length <= 3) return "₹$result";

    String lastThree = result.substring(result.length - 3);
    String otherNumbers = result.substring(0, result.length - 3);

    if (otherNumbers.isNotEmpty) {
      lastThree = ',$lastThree';
    }

    String formattedLeft = otherNumbers.replaceAllMapped(
      RegExp(r'\B(?=(\d{2})+(?!\d))'),
      (Match m) => ",",
    );

    return "₹$formattedLeft$lastThree";
  }

  String _formatLakhs(dynamic value) {
    if (value == null) return "₹0L";
    double val = double.tryParse(value.toString()) ?? 0;
    return "₹${(val / 100000).toStringAsFixed(2)}L";
  }

  @override
  Widget build(BuildContext context) {
    // 1. Access Controller
    final controller = Get.find<PropertyController>();

    // 2. Theme Variables
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.3 : 0.05);

    // 3. Reactive UI
    return Obx(() {
      // ✅ Get latest results directly from controller
      final results = controller.results;

      // 4. Empty State
      if (results.isEmpty || (results['totalCost'] ?? 0) == 0) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_late_outlined,
                  size: 64,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
                const SizedBox(height: 20),
                Text(
                  "No Calculation Yet",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: subTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Please enter property details in the Inputs tab to generate this report.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subTextColor),
                ),
              ],
            ),
          ),
        );
      }

      // ✅ Safe extraction for variables used in UI and Navigation
      final Map assumptions = results['assumptions'] ?? {};

      final String safeStartMode =
          results['homeLoanStartMode'] ??
          assumptions['homeLoanStartMode'] ??
          'default';

      final dynamic safeStartMonth =
          results['homeLoanStartMonth'] ?? assumptions['homeLoanStartMonth'];

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Header Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: [BoxShadow(color: shadowColor, blurRadius: 8)],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color.fromARGB(
                      255,
                      35,
                      77,
                      145,
                    ).withValues(alpha: 0.1),
                    child: Icon(
                      Icons.calculate,
                      color: AppColors.headerLightEnd,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Detailed Breakdown",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        "Financial Details & Schedules",
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Monthly EMI Timeline
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.headerLightEnd, width: 4),
                  ),
                ),
                child: Text(
                  "EMI Timeline",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.headerLightEnd,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // --- TIMELINE 1 CARD ---
            _buildTimelineAccordion(
              title: "Timeline 1: Pre-Possession",
              subtitle:
                  "Month 0 - ${results['possessionMonths']} (Construction)",
              amount: _formatCurrency(results['prePossessionTotal']),
              color: Colors.blue,
              icon: Icons.hourglass_top,
              context: context,
              content: Column(
                children: [
                  _buildRow(
                    "Personal Loan 1 EMI",
                    "${_formatCurrency(results['personalLoan1EMI'])}/mo",
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  if ((results['monthlyIDCEMI'] ?? 0) > 0)
                    _buildRow(
                      "Avg. IDC Interest",
                      "${_formatCurrency(results['monthlyIDCEMI'])}/mo",
                      valueColor: Colors.orange,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                  const SizedBox(height: 20),

                  // 2. BUTTON: View Construction Schedule
                  if (safeStartMode != 'manual')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IdcSchedulePage(
                                  // Passing params for compatibility
                                  params: {
                                    'idcSchedule': results['idcSchedule'] ?? [],
                                    'pl1EMI': results['personalLoan1EMI'],
                                    'possessionMonths':
                                        results['possessionMonths'],
                                    'homeLoanAmount': results['homeLoanAmount'],
                                    'totalHoldingMonths':
                                        results['totalHoldingMonths'],
                                    'lastBankDisbursementMonth':
                                        results['lastBankDisbursementMonth'] ??
                                        assumptions['lastBankDisbursementMonth'],
                                    'interestRate': results['homeLoanRate'],
                                    'homeLoanStartMode': safeStartMode,
                                    'manualStartMonth': safeStartMonth,
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.construction, size: 16),
                          label: const Text("View Construction Schedule"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(color: Colors.orange.shade200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // 3. BUTTON: View Monthly Ledger
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Extract Rate Safely
                        final double safeRate =
                            double.tryParse(
                              (results['homeLoanRate'] ??
                                      assumptions['homeLoanRate'] ??
                                      9.0)
                                  .toString(),
                            ) ??
                            9.0;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MonthlyBreakdownPage(
                              params: {
                                'idcSchedule': results['idcSchedule'] ?? [],
                                'pl1EMI': results['personalLoan1EMI'],
                                'possessionMonths': results['possessionMonths'],
                                'homeLoanAmount': results['homeLoanAmount'],
                                'propertyName': "Property",
                                'interestRate': safeRate,
                                'homeLoanTerm':
                                    results['homeLoanTerm'] ??
                                    assumptions['homeLoanTerm'],
                                'lastBankDisbursementMonth':
                                    results['lastBankDisbursementMonth'] ??
                                    assumptions['lastBankDisbursementMonth'],
                                'fullHomeLoanEMI': results['homeLoanEMI'],
                                'homeLoanStartMode': safeStartMode,
                                'manualStartMonth': safeStartMonth,
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.table_chart, size: 16),
                      label: const Text("View Monthly Ledger"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        foregroundColor: Colors.blue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // --- TIMELINE 2 LOGIC ---
            Builder(
              builder: (context) {
                int postMonths =
                    (double.tryParse(
                              results['postPossessionMonths'].toString(),
                            ) ??
                            0)
                        .toInt();
                // CASE A: Standard Scenario
                if (postMonths > 0) {
                  return _buildTimelineAccordion(
                    title: "Timeline 2: Post-Possession",
                    subtitle:
                        "Month ${results['possessionMonths'] + 1} - ${results['totalHoldingMonths']}",
                    amount:
                        "${_formatCurrency(results['postPossessionEMI'])}/mo",
                    color: Colors.green,
                    icon: Icons.check_circle_outline,
                    context: context,
                    content: Column(
                      children: [
                        _buildRow(
                          "Home Loan EMI",
                          _formatCurrency(results['homeLoanEMI']),
                          textColor: textColor,
                          subTextColor: subTextColor,
                        ),
                        if ((results['personalLoan1EMI'] ?? 0) > 0)
                          _buildRow(
                            "PL1 EMI",
                            _formatCurrency(results['personalLoan1EMI']),
                            textColor: textColor,
                            subTextColor: subTextColor,
                          ),
                        if ((results['personalLoan2EMI'] ?? 0) > 0)
                          _buildRow(
                            "PL2 EMI",
                            _formatCurrency(results['personalLoan2EMI']),
                            textColor: textColor,
                            subTextColor: subTextColor,
                          ),
                        _buildRow(
                          "Total Paid in Phase 2",
                          _formatCurrency(results['postPossessionTotal']),
                          textColor: textColor,
                          subTextColor: subTextColor,
                        ),
                      ],
                    ),
                  );
                }
                // CASE B: Early Exit
                else {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.hourglass_bottom,
                          size: 28,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Timeline 2: Not Applicable",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Holding period ends before possession.\nNo post-possession payments.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 20),

            // 3. IDC Summary
            if ((results['totalIDC'] ?? 0) > 0)
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
                        Icon(Icons.construction, size: 18, color: textColor),
                        const SizedBox(width: 8),
                        Text(
                          "IDC Summary",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStatCard(
                          "Avg Monthly",
                          _formatCurrency(results['monthlyIDCEMI']),
                          "",
                          Colors.blue,
                          textColor,
                        ),
                        const SizedBox(width: 10),
                        _buildStatCard(
                          "Total Interest",
                          _formatCurrency(results['totalIDC']),
                          "Construction Phase",
                          Colors.red,
                          textColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 4. Loan Analysis
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.headerLightEnd, width: 4),
                  ),
                ),
                child: Text(
                  "Loan Analysis",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.headerLightEnd,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Home Loan Breakdown
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
                  Text(
                    "HOME LOAN BREAKDOWN",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: subTextColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildStatCard(
                        "EMI Amount",
                        _formatCurrency(results['homeLoanEMI']),
                        "Monthly",
                        Colors.blue,
                        textColor,
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        "Total Paid",
                        _formatCurrency(results['totalEMIPaid']),
                        "Principal + Int",
                        Colors.green,
                        textColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildStatCard(
                        "Interest Only",
                        _formatCurrency(results['totalInterestPaid']),
                        "Cost of Loan",
                        Colors.orange,
                        textColor,
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        "Balance Due",
                        _formatCurrency(results['totalLoanOutstanding']),
                        "To Close",
                        Colors.red,
                        textColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 5. Final Summaries
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Interest Cost",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${results['years']} Years",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatLakhs(results['totalInterestPaid']),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  if ((results['totalIDC'] ?? 0) > 0)
                    Text(
                      "Includes construction interest",
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.green.shade100,
                  width: 2,
                ),
                boxShadow: [BoxShadow(color: shadowColor, blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Projected Cash Exit",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "@ ₹${results['exitPrice']}",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatLakhs(results['leftoverCash']),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    "Cash in hand after loan closure",
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 6. Net Profit Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (results['netGainLoss'] ?? 0) >= 0
                    ? Colors.green
                    : Colors.red,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        ((results['netGainLoss'] ?? 0) >= 0
                                ? Colors.green
                                : Colors.red)
                            .withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "NET POSITION",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatLakhs(results['netGainLoss']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (results['netGainLoss'] ?? 0) >= 0 ? "PROFIT" : "LOSS",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      );
    });
  }

  // --- HELPERS (Theme Aware) ---

  Widget _buildTimelineAccordion({
    required String title,
    required String subtitle,
    required String amount,
    required Color color,
    required IconData icon,
    required Widget content,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? color.withValues(alpha: 0.5)
        : color.withValues(alpha: 0.3);
    final expandedColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.shade50;
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.3 : 0.05);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 4)],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            backgroundColor: color,
            radius: 18,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: expandedColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    Color? valueColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: subTextColor)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String subtext,
    Color color,
    Color textColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtext.isNotEmpty)
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 8,
                  color: color.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
