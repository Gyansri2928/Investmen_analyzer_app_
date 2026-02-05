import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart'; // For AppColors

class MonthlyBreakdownPage extends StatelessWidget {
  final Map<String, dynamic> params;

  const MonthlyBreakdownPage({super.key, required this.params});

  // --- HELPERS ---
  String _formatCurrency(dynamic val) {
    if (val == null) return '₹0';
    double v = double.tryParse(val.toString()) ?? 0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(v);
  }

  double _safeDouble(dynamic val) {
    if (val == null) return 0.0;
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // 1. EXTRACT DATA DIRECTLY FROM BACKEND (No local math!)
    final List<dynamic> monthlyLedger = params['monthlyLedger'] ?? [];

    // Context Params (Visual/Summary only)
    final String propertyName = params['propertyName'] ?? "Property";
    final int possessionMonths =
        int.tryParse(params['possessionMonths'].toString()) ?? 24;
    final String homeLoanStartMode = params['homeLoanStartMode'] ?? 'default';
    // For summary card if needed

    // 2. CALCULATE SUMMARIES (From the list we received)
    double grandTotalOutflow = 0;
    double minOutflow = 0;
    double maxOutflow = 0;
    double displayedPl1EMI = _safeDouble(params['pl1EMI']);

    if (monthlyLedger.isNotEmpty) {
      grandTotalOutflow = monthlyLedger.fold(
        0.0,
        (sum, row) => sum + _safeDouble(row['totalOutflow']),
      );

      // Get list of non-zero outflows for min/max
      final outflows = monthlyLedger
          .map((row) => _safeDouble(row['totalOutflow']))
          .where((val) => val > 0)
          .toList();

      if (outflows.isNotEmpty) {
        minOutflow = outflows.reduce(min);
        maxOutflow = outflows.reduce(max);
      }
      if (displayedPl1EMI == 0) {
        final pl1Values = monthlyLedger
            .map((row) => _safeDouble(row['pl1'])) // Looking for key 'pl1'
            .where((val) => val > 0)
            .toList();

        if (pl1Values.isNotEmpty) {
          displayedPl1EMI = pl1Values.reduce(
            max,
          ); // Use the actual EMI found in data
        }
      }
    }

    // 3. UI SETUP
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.grey.shade100;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final text = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          "Monthly Cashflow Ledger",
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: cardBg,
        foregroundColor: text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Text(
              "Breakdown for $propertyName (Month 0 - $possessionMonths)",
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    "Total Outflow",
                    grandTotalOutflow,
                    Icons.layers,
                    Colors.amber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    "Min Monthly",
                    minOutflow,
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    "Max Monthly",
                    maxOutflow,
                    Icons.arrow_upward,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                // We use the PL1 from the first row of ledger if available, else 0
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    "Fixed PL1 EMI",
                    displayedPl1EMI,
                    Icons.account_balance_wallet,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // The Table
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                  columnSpacing: 20,
                  columns: _buildColumns(isDark, homeLoanStartMode),
                  rows: monthlyLedger.map<DataRow>((row) {
                    // ✅ READ VALUES SAFELY
                    final disbursement = _safeDouble(row['disbursement']);
                    final isDisb = disbursement > 0;

                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (isDisb) return Colors.blue.withOpacity(0.05);
                        return null;
                      }),
                      cells: _buildCells(row, isDark, homeLoanStartMode),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns(bool isDark, String startMode) {
    TextStyle headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: isDark ? Colors.white70 : Colors.black87,
    );

    if (startMode == 'manual') {
      return [
        DataColumn(label: Text("Mo", style: headerStyle)),
        DataColumn(label: Text("Disbursement", style: headerStyle)),
        DataColumn(label: Text("Loan Bal", style: headerStyle)),
        DataColumn(label: Text("Interest", style: headerStyle)),
        DataColumn(label: Text("HL Paid", style: headerStyle)),
        DataColumn(label: Text("PL1", style: headerStyle)),
        DataColumn(label: Text("Total", style: headerStyle)),
      ];
    } else {
      return [
        DataColumn(label: Text("Mo", style: headerStyle)),
        DataColumn(label: Text("Disbursed", style: headerStyle)),
        DataColumn(label: Text("Slabs", style: headerStyle)),
        DataColumn(label: Text("Cum. Loan", style: headerStyle)),
        DataColumn(label: Text("EMI/IDC", style: headerStyle)),
        DataColumn(label: Text("PL1", style: headerStyle)),
        DataColumn(label: Text("Total", style: headerStyle)),
      ];
    }
  }

  List<DataCell> _buildCells(dynamic row, bool isDark, String startMode) {
    TextStyle cellStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white70 : Colors.black87,
    );
    TextStyle boldStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black,
    );

    // Extract values directly
    double disbursement = _safeDouble(row['disbursement']);
    double outstanding = _safeDouble(row['outstandingBalance']);
    double interest = _safeDouble(row['interestPart']);
    double hlComp = _safeDouble(row['hlComponent']);
    double pl1 = _safeDouble(row['pl1']);
    double total = _safeDouble(row['totalOutflow']);
    double cumDisb = _safeDouble(row['cumulativeDisbursement']);
    bool isFullEMI = row['isFullEMI'] == true;

    if (startMode == 'manual') {
      return [
        DataCell(Text(row['month'].toString(), style: boldStyle)),
        DataCell(
          Text(
            (disbursement > 0) ? _formatCurrency(disbursement) : '-',
            style: const TextStyle(color: Colors.blue, fontSize: 12),
          ),
        ),
        DataCell(
          Text(
            _formatCurrency(outstanding),
            style: const TextStyle(color: Colors.cyan, fontSize: 12),
          ),
        ),
        DataCell(
          Text(
            interest > 0 ? _formatCurrency(interest) : '-',
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ),
        DataCell(
          Text(
            _formatCurrency(hlComp),
            style: TextStyle(
              fontSize: 12,
              color: isFullEMI ? Colors.green : null,
            ),
          ),
        ),
        DataCell(Text(_formatCurrency(pl1), style: cellStyle)),
        DataCell(
          Text(
            _formatCurrency(total),
            style: const TextStyle(
              color: AppColors.headerLightEnd,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ];
    } else {
      return [
        DataCell(Text(row['month'].toString(), style: boldStyle)),
        DataCell(
          Text(
            (disbursement > 0) ? _formatCurrency(disbursement) : '-',
            style: const TextStyle(color: Colors.blue, fontSize: 12),
          ),
        ),
        DataCell(Text(row['activeSlabs'].toString(), style: cellStyle)),
        DataCell(
          Text(
            _formatCurrency(cumDisb),
            style: const TextStyle(color: Colors.cyan, fontSize: 12),
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatCurrency(hlComp),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isFullEMI
                      ? Colors.green
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              if (isFullEMI)
                const Text(
                  "Full EMI",
                  style: TextStyle(fontSize: 8, color: Colors.green),
                ),
            ],
          ),
        ),
        DataCell(Text(_formatCurrency(pl1), style: cellStyle)),
        DataCell(
          Text(
            _formatCurrency(total),
            style: const TextStyle(
              color: AppColors.headerLightEnd,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ];
    }
  }
}
