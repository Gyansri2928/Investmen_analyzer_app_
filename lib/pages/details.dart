import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../main.dart'; // For AppColors
import '../controller/property_controller.dart';
import 'package:property_analyzer_mobile/pages/monthlybreakdown.dart';
import 'package:property_analyzer_mobile/pages/idc_schedule.dart';

class DetailsTab extends StatelessWidget {
  const DetailsTab({super.key, this.results});

  final Map<String, dynamic>? results;

  // --- HELPERS ---
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
      final rootData = results ?? controller.results;
      final breakdown =
          rootData['detailedBreakdown'] as Map<String, dynamic>? ?? {};

      if (breakdown.isEmpty || (breakdown['totalCost'] ?? 0) == 0) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_late_outlined,
                  size: 64,
                  color: subTextColor,
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
              ],
            ),
          ),
        );
      }

      final String safeStartMode = breakdown['homeLoanStartMode'] ?? 'default';
      double getVal(String key) =>
          double.tryParse(breakdown[key]?.toString() ?? '0') ?? 0;
      // Home Loan Outstanding
      double hlPrincipal = getVal('homeLoanAmount');
      double hlPaid = getVal('homeLoanEMIPaid');
      double hlInterest = getVal('homeLoanInterestPaid');
      double hlOutstanding = (hlPrincipal - (hlPaid - hlInterest)).clamp(
        0,
        double.infinity,
      );

      // PL1 Outstanding
      double pl1Principal = getVal('personalLoan1Amount');
      double pl1Paid = getVal('personalLoan1EMIPaid');
      double pl1Interest = getVal('personalLoan1InterestPaid');
      double pl1Outstanding = (pl1Principal - (pl1Paid - pl1Interest)).clamp(
        0,
        double.infinity,
      );

      // PL2 Outstanding
      double pl2Principal = getVal('personalLoan2Amount');
      double pl2Paid = getVal('personalLoan2EMIPaid');
      double pl2Interest = getVal('personalLoan2InterestPaid');
      double pl2Outstanding = (pl2Principal - (pl2Paid - pl2Interest)).clamp(
        0,
        double.infinity,
      );

      // Total Outstanding (Sum of calculated)
      double totalOutstanding = hlOutstanding + pl1Outstanding + pl2Outstanding;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
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
                    ).withOpacity(0.1),
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

            // --- TIMELINE 1 CARD (KEPT AS REQUESTED) ---
            _buildTimelineAccordion(
              title: "Timeline 1: Pre-Possession",
              subtitle:
                  "Month 0 - ${breakdown['possessionMonths']} (Construction)",
              amount: _formatCurrency(breakdown['prePossessionTotal']),
              color: Colors.blue,
              icon: Icons.hourglass_top,
              context: context,
              content: Column(
                children: [
                  _buildRow(
                    "Personal Loan 1 EMI",
                    "${_formatCurrency(breakdown['personalLoan1EMI'])}/mo",
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  if ((breakdown['monthlyIDCEMI'] ?? 0) > 0)
                    _buildRow(
                      "Avg. IDC Interest",
                      "${_formatCurrency(breakdown['monthlyIDCEMI'])}/mo",
                      valueColor: Colors.orange,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  const SizedBox(height: 20),
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
                                  params: {
                                    'idcReport': breakdown['idcReport'],
                                    'pl1EMI': breakdown['personalLoan1EMI'],
                                    'interestRate':
                                        controller
                                            .propertyData['assumptions']['homeLoanRate'] ??
                                        9.0,
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MonthlyBreakdownPage(
                              params: {
                                'monthlyLedger': breakdown['monthlyLedger'],
                                'propertyName': "Property",
                                'homeLoanAmount': breakdown['homeLoanAmount'],
                                'homeLoanStartMode': safeStartMode,
                                'possessionMonths':
                                    breakdown['possessionMonths'],
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

            // --- TIMELINE 2 CARD (KEPT AS REQUESTED) ---
            Builder(
              builder: (context) {
                int postMonths =
                    (double.tryParse(
                              breakdown['postPossessionMonths'].toString(),
                            ) ??
                            0)
                        .toInt();
                if (postMonths > 0) {
                  return _buildTimelineAccordion(
                    title: "Timeline 2: Post-Possession",
                    subtitle:
                        "Month ${breakdown['possessionMonths'] + 1} - ${breakdown['totalHoldingMonths']}",
                    amount:
                        "${_formatCurrency(breakdown['postPossessionEMI'])}/mo",
                    color: Colors.green,
                    icon: Icons.check_circle_outline,
                    context: context,
                    content: Column(
                      children: [
                        _buildRow(
                          "Home Loan EMI",
                          _formatCurrency(breakdown['homeLoanEMI']),
                          textColor: textColor,
                          subTextColor: subTextColor,
                        ),
                        if ((breakdown['personalLoan1EMI'] ?? 0) > 0)
                          _buildRow(
                            "PL1 EMI",
                            _formatCurrency(breakdown['personalLoan1EMI']),
                            textColor: textColor,
                            subTextColor: subTextColor,
                          ),
                        if ((breakdown['personalLoan2EMI'] ?? 0) > 0)
                          _buildRow(
                            "PL2 EMI",
                            _formatCurrency(breakdown['personalLoan2EMI']),
                            textColor: textColor,
                            subTextColor: subTextColor,
                          ),
                        _buildRow(
                          "Total Cash Paid in Phase 2",
                          _formatCurrency(breakdown['postPossessionTotal']),
                          textColor: textColor,
                          subTextColor: subTextColor,
                        ),
                      ],
                    ),
                  );
                } else {
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
                      ],
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 30),

            // --- ⬇️ NEW SECTION: DETAILED COMPONENT BREAKDOWN (REPLACES OLD CARDS) ⬇️ ---

            // Header Label
            Row(
              children: [
                Text(
                  "FINANCIAL COMPONENTS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: subTextColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 1. IDC Component
            if ((breakdown['totalIDC'] ?? 0) > 0)
              _buildBreakdownCard(
                context,
                title: "IDC Component",
                subtitle: "Interest During Construction",
                icon: Icons.calculate,
                iconColor: Colors.amber,
                monthlyVal: _formatCurrency(breakdown['monthlyIDCEMI']),
                monthlyLabel: "Avg Monthly",
                totalVal: _formatLakhs(breakdown['totalIDC']),
                interestVal: "100%",
                balanceVal: _formatLakhs(
                  (breakdown['homeLoanAmount'] ?? 0) +
                      (breakdown['totalIDC'] ?? 0),
                ),
                balanceLabel: "Final Loan Bal",
              ),

            // 2. Home Loan
            _buildBreakdownCard(
              context,
              title: "Home Loan",
              subtitle: "Principal + Interest",
              icon: Icons.account_balance,
              iconColor: Colors.blue,
              monthlyVal: _formatCurrency(breakdown['homeLoanEMI']),
              monthlyLabel: "EMI",
              totalVal: _formatLakhs(hlPaid),
              interestVal: _formatLakhs(hlInterest),
              balanceVal: _formatLakhs(hlOutstanding),
              balanceLabel: "Outstanding",
            ),

            // 3. Personal Loan 1
            if ((breakdown['personalLoan1EMI'] ?? 0) > 0)
              _buildBreakdownCard(
                context,
                title: "Personal Loan 1",
                subtitle: "Secondary Funding",
                icon: Icons.money,
                iconColor: Colors.green,
                monthlyVal: _formatCurrency(breakdown['personalLoan1EMI']),
                monthlyLabel: "EMI",
                totalVal: _formatLakhs(breakdown['personalLoan1EMIPaid']),
                interestVal: _formatLakhs(
                  breakdown['personalLoan1InterestPaid'],
                ),
                balanceVal: _formatLakhs(pl1Outstanding),
                balanceLabel: "Outstanding",
              ),

            // 4. Personal Loan 2
            if ((breakdown['personalLoan2EMI'] ?? 0) > 0)
              _buildBreakdownCard(
                context,
                title: "Personal Loan 2",
                subtitle: "Additional Funding",
                icon: Icons.wallet,
                iconColor: Colors.orange,
                monthlyVal: _formatCurrency(breakdown['personalLoan2EMI']),
                monthlyLabel: "EMI",
                totalVal: _formatLakhs(breakdown['personalLoan2EMIPaid']),
                interestVal: _formatLakhs(
                  breakdown['personalLoan2InterestPaid'],
                ),
                balanceVal: _formatLakhs(pl2Outstanding),
                balanceLabel: "Outstanding",
              ),

            // 5. TOTAL SUMMARY (Highlighted)
            _buildBreakdownCard(
              context,
              title: "Total Summary",
              subtitle: "All Active Loans",
              icon: Icons.summarize,
              iconColor: Colors.white,
              iconBg: isDark ? Colors.white10 : Colors.black87,
              monthlyVal: _formatCurrency(breakdown['postPossessionEMI']),
              monthlyLabel: "Total Monthly",
              totalVal: _formatLakhs(breakdown['totalEMIPaid']),
              interestVal: _formatLakhs(breakdown['totalInterestPaid']),
              balanceVal: _formatLakhs(breakdown['totalLoanOutstanding']),
              balanceLabel: "To Clear",
              isTotal: true,
            ),

            const SizedBox(height: 20),

            // Net Profit Banner (Kept for final result context)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (breakdown['netGainLoss'] ?? 0) >= 0
                    ? Colors.green
                    : Colors.red,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        ((breakdown['netGainLoss'] ?? 0) >= 0
                                ? Colors.green
                                : Colors.red)
                            .withOpacity(0.3),
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
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatLakhs(breakdown['netGainLoss']),
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
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (breakdown['netGainLoss'] ?? 0) >= 0 ? "PROFIT" : "LOSS",
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

  // --- HELPERS ---

  // 1. New Helper: Detailed Breakdown Card (Table Row Replacement)
  Widget _buildBreakdownCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Color? iconBg,
    required String monthlyVal,
    required String monthlyLabel,
    required String totalVal,
    required String interestVal,
    required String balanceVal,
    required String balanceLabel,
    bool isTotal = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isTotal
            ? Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5)
            : Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Icon and Title
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg ?? iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      monthlyLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      monthlyVal,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.grey.shade100,
          ),

          // Bottom Row: 3 Column Stats
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactStat("Total Cash Paid", totalVal, isDark),
                _buildCompactStat(
                  "Interest",
                  interestVal,
                  isDark,
                  valueColor: Colors.orange.shade700,
                ),
                _buildCompactStat(
                  balanceLabel,
                  balanceVal,
                  isDark,
                  valueColor: Colors.red.shade400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }

  // 2. Existing Helpers
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
        ? color.withOpacity(0.5)
        : color.withOpacity(0.3);
    final expandedColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.grey.shade50;
    final shadowColor = Colors.black.withOpacity(isDark ? 0.3 : 0.05);

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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
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
                style: TextStyle(fontSize: 8, color: color.withOpacity(0.6)),
              ),
          ],
        ),
      ),
    );
  }
}
