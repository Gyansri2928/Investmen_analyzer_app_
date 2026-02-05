import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart'; // For AppColors

class IdcSchedulePage extends StatelessWidget {
  final Map<String, dynamic> params;

  const IdcSchedulePage({super.key, required this.params});

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

  int _safeInt(dynamic val) {
    if (val == null) return 0;
    return (double.tryParse(val.toString()) ?? 0).toInt();
  }

  @override
  Widget build(BuildContext context) {
    // 1. EXTRACT DATA DIRECTLY FROM BACKEND REPORT
    // We no longer calculate interest here. We trust the server.
    final Map<String, dynamic> report = params['idcReport'] ?? {};
    final List schedule = report['schedule'] ?? [];

    // Summary Metrics from Backend
    final double grandTotalInterest = _safeDouble(report['grandTotalInterest']);
    final double minMonthlyInterest = _safeDouble(report['minMonthlyInterest']);
    final double maxMonthlyInterest = _safeDouble(report['maxMonthlyInterest']);
    final int cutoffMonth = _safeInt(
      report['cutoffMonth'],
    ); // Interest End Month

    // Context Data (passed for UI context, not calculation)
    final double pl1EMI = _safeDouble(params['pl1EMI']);
    final double interestRate = _safeDouble(params['interestRate']);

    // 2. FILTERING (Visual only)
    // The backend sends all slabs. We filter to show only relevant ones up to cutoff.
    // (Optional: You can show all if you want, but hiding future ones is cleaner)
    final visualSchedule = schedule
        .where(
          (row) =>
              _safeInt(row['releaseMonth']) <=
              (cutoffMonth > 0 ? cutoffMonth : 999),
        )
        .toList();

    // If no cutoff (e.g. 0), show everything
    final displayList = visualSchedule.isNotEmpty ? visualSchedule : schedule;

    // 3. UI SETUP
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.grey.shade50;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final text = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          "Construction Schedule",
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
            Text(
              "Breakdown up to Month ${cutoffMonth > 0 ? cutoffMonth : 'Possession'}",
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    "Total Interest Cost",
                    grandTotalInterest,
                    Icons.layers,
                    Colors.amber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    "Min Monthly IDC",
                    minMonthlyInterest,
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
                    "Max Monthly IDC",
                    maxMonthlyInterest,
                    Icons.arrow_upward,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    "Fixed PL1 EMI",
                    pl1EMI,
                    Icons.account_balance_wallet,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Data Table
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
                  columnSpacing: 24,
                  columns: [
                    DataColumn(
                      label: Text(
                        "Pay #",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: text,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Month",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: text,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Disbursement",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: text,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Rate",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: text,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Int.\nDur.",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: text,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Monthly Int.",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Total IDC",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.headerLightEnd,
                        ),
                      ),
                    ),
                  ],
                  rows: displayList.map<DataRow>((row) {
                    // ✅ READ DIRECTLY FROM BACKEND (No Math Here!)
                    int slabNo = _safeInt(row['slabNo']);
                    int releaseMonth = _safeInt(row['releaseMonth']);
                    double amount = _safeDouble(row['amount']);
                    int duration = _safeInt(row['duration']);
                    double monthlyInt = _safeDouble(
                      row['cumulativeMonthlyInterest'],
                    ); // The cumulated value for this month
                    double totalCost = _safeDouble(row['totalCostForSlab']);

                    return DataRow(
                      color: duration <= 0
                          ? WidgetStateProperty.all(
                              isDark ? Colors.white10 : Colors.grey.shade200,
                            )
                          : null,
                      cells: [
                        DataCell(
                          Text(
                            slabNo.toString(),
                            style: TextStyle(fontSize: 12, color: text),
                          ),
                        ),
                        DataCell(
                          Text(
                            releaseMonth.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: text,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatCurrency(amount),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            "${interestRate.toStringAsFixed(2)}%",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                          ),
                        ),
                        // Interest Duration
                        DataCell(
                          Center(
                            child: Text(
                              duration > 0 ? duration.toString() : "-",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: duration > 0 ? text : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        // Monthly Interest (Visual Check)
                        DataCell(
                          duration > 0
                              ? Text(
                                  _formatCurrency(monthlyInt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                )
                              : const Text(
                                  "-",
                                  style: TextStyle(color: Colors.grey),
                                ),
                        ),
                        // Total Cost for Slab
                        DataCell(
                          Text(
                            _formatCurrency(totalCost),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.headerLightEnd,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Footer Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Understanding Outflow",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "The 'Monthly Interest' shown is variable. Add PL1 EMI (${_formatCurrency(pl1EMI)}) to calculate your total monthly check.",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

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
}
