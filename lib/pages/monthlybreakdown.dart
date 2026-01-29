import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For currency formatting
import '../main.dart'; // For AppColors

class MonthlyBreakdownPage extends StatefulWidget {
  final Map<String, dynamic> params;

  const MonthlyBreakdownPage({super.key, required this.params});

  @override
  State<MonthlyBreakdownPage> createState() => _MonthlyBreakdownPageState();
}

class _MonthlyBreakdownPageState extends State<MonthlyBreakdownPage> {
  List<Map<String, dynamic>> _monthlyData = [];
  double _grandTotalOutflow = 0;
  double _minOutflow = 0;
  double _maxOutflow = 0;
  double _fullHomeLoanEMI = 0;

  @override
  void initState() {
    super.initState();
    _calculateLedger();
  }

  String _formatCurrency(double val) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(val);
  }

  // ✅ HELPER 1: Safe Int Parsing (for inputs)
  int _safeInt(dynamic val) {
    if (val == null) return 0;
    return (double.tryParse(val.toString()) ?? 0).toInt();
  }

  // ✅ HELPER 2: Safe Double Parsing (Prevents crash when casting int to double)
  double _safeDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is int) return val.toDouble();
    if (val is double) return val;
    return double.tryParse(val.toString()) ?? 0.0;
  }

  void _calculateLedger() {
    // 1. Extract Params safely
    final List idcSchedule = widget.params['idcSchedule'] ?? [];
    final double pl1EMI = _safeDouble(widget.params['pl1EMI']);

    final int possessionMonths = _safeInt(widget.params['possessionMonths']) > 0
        ? _safeInt(widget.params['possessionMonths'])
        : 24;

    final double homeLoanAmount = _safeDouble(widget.params['homeLoanAmount']);
    // Fallback to 9.0 if 0 is passed accidentally
    double interestRate = _safeDouble(widget.params['interestRate']);
    if (interestRate == 0) interestRate = 9.0;
    final int homeLoanTerm = _safeInt(widget.params['homeLoanTerm']);

    final String homeLoanStartMode =
        widget.params['homeLoanStartMode'] ?? 'default';
    final int? manualStartMonth = widget.params['manualStartMonth'] != null
        ? _safeInt(widget.params['manualStartMonth'])
        : null;

    final int lastBankDisbursementMonth = _safeInt(
      widget.params['lastBankDisbursementMonth'],
    );

    // 2. Calculate Full EMI
    double monthlyRate = interestRate / 12 / 100;
    int months = homeLoanTerm > 0 ? homeLoanTerm * 12 : 240;

    if (monthlyRate == 0) {
      _fullHomeLoanEMI = months > 0 ? homeLoanAmount / months : 0;
    } else {
      _fullHomeLoanEMI =
          (homeLoanAmount * monthlyRate * pow(1 + monthlyRate, months)) /
          (pow(1 + monthlyRate, months) - 1);
    }

    // 3. Setup Timelines
    int derivedLastMonth = idcSchedule.isNotEmpty
        ? idcSchedule.map((s) => _safeInt(s['releaseMonth'])).reduce(max)
        : possessionMonths;

    int fundingEndMonth = lastBankDisbursementMonth > 0
        ? lastBankDisbursementMonth
        : derivedLastMonth;

    int actualHLStartMonth;
    if (homeLoanStartMode == 'manual') {
      actualHLStartMonth = manualStartMonth ?? 0;
    } else {
      actualHLStartMonth = fundingEndMonth + 1;
    }

    // 4. Generate Data Loop
    List<Map<String, dynamic>> data = [];
    double slabAmount = idcSchedule.isNotEmpty
        ? homeLoanAmount / idcSchedule.length
        : 0;

    double cumulativeDisbursement = 0;
    double outstandingBalance = 0;
    int activeSlabs = 0;

    for (int m = 0; m <= possessionMonths; m++) {
      double currentDisbursement = 0;
      double interestForThisMonth = 0;
      double principalRepaidThisMonth = 0;

      // A. Disbursement Logic
      if (m <= fundingEndMonth) {
        bool isScheduleMonth = idcSchedule.any(
          (s) => _safeInt(s['releaseMonth']) == m,
        );

        if (isScheduleMonth && cumulativeDisbursement < (homeLoanAmount - 10)) {
          currentDisbursement = slabAmount;
          cumulativeDisbursement += slabAmount;

          if (homeLoanStartMode == 'manual') {
            outstandingBalance += slabAmount;
          } else {
            outstandingBalance = cumulativeDisbursement;
          }
          activeSlabs++;
        }
      }

      // B. Interest Logic
      if (outstandingBalance > 0) {
        interestForThisMonth = (outstandingBalance * (interestRate / 100)) / 12;
      }

      // C. Payment Logic
      double hlPayment = 0;
      bool isFullEMI = false;

      if (m >= actualHLStartMonth) {
        // Full EMI Phase
        hlPayment = _fullHomeLoanEMI;
        isFullEMI = true;
        if (outstandingBalance > 0) {
          principalRepaidThisMonth = max(0, hlPayment - interestForThisMonth);
          outstandingBalance -= principalRepaidThisMonth;
        }
      } else {
        // Pre-EMI Phase
        if (homeLoanStartMode == 'manual') {
          hlPayment = 0;
        } else {
          // Standard: Pay exactly the interest
          hlPayment = interestForThisMonth;
          principalRepaidThisMonth = 0;
        }
      }

      double currentPL1 = (m == 0) ? 0 : pl1EMI;

      data.add({
        'month': m,
        'disbursement': currentDisbursement,
        'activeSlabs': m > fundingEndMonth ? 'Max' : activeSlabs,
        'cumulativeDisbursement': cumulativeDisbursement,
        'outstandingBalance': max(0, outstandingBalance),
        'hlComponent': hlPayment,
        'interestPart': interestForThisMonth,
        'principalPart': principalRepaidThisMonth,
        'isFullEMI': isFullEMI,
        'pl1': currentPL1,
        'totalOutflow': hlPayment + currentPL1,
      });
    }

    // 5. Calculate Stats (CRASH PROOF)
    double totalOut = data.fold(
      0.0,
      (sum, item) => sum + _safeDouble(item['totalOutflow']),
    );
    List<double> outflows = data
        .map((e) => _safeDouble(e['totalOutflow']))
        .where((v) => v > 0)
        .toList();

    setState(() {
      _monthlyData = data;
      _grandTotalOutflow = totalOut;
      _minOutflow = outflows.isNotEmpty ? outflows.reduce(min) : 0;
      _maxOutflow = outflows.isNotEmpty ? outflows.reduce(max) : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final text = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Monthly Cashflow Ledger",
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- SUMMARY CARDS ---
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    "Total Outflow",
                    _grandTotalOutflow,
                    Icons.layers,
                    Colors.amber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    "Min Monthly",
                    _minOutflow,
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
                    "Max Monthly",
                    _maxOutflow,
                    Icons.arrow_upward,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    "Fixed PL1 EMI",
                    _safeDouble(widget.params['pl1EMI']),
                    Icons.account_balance_wallet,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- THE TABLE ---
            Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                  columnSpacing: 20,
                  columns: _buildColumns(isDark),
                  rows: _monthlyData.map((row) {
                    // ✅ CRASH FIX: Use _safeDouble() here instead of (val as double)
                    final isDisb = _safeDouble(row['disbursement']) > 0;

                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (isDisb) return Colors.blue.withOpacity(0.05);
                        return null; // default
                      }),
                      cells: _buildCells(row, isDark),
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

  Widget _buildSummaryCard(
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
                  style: TextStyle(
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

  List<DataColumn> _buildColumns(bool isDark) {
    final isManual = widget.params['homeLoanStartMode'] == 'manual';
    TextStyle headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: isDark ? Colors.white70 : Colors.black87,
    );

    if (isManual) {
      return [
        DataColumn(label: Text("Mo", style: headerStyle)),
        DataColumn(label: Text("Disbursement", style: headerStyle)),
        DataColumn(label: Text("Loan Bal", style: headerStyle)), // Cyan
        DataColumn(label: Text("Interest", style: headerStyle)), // Yellow
        DataColumn(label: Text("HL Paid", style: headerStyle)),
        DataColumn(label: Text("PL1", style: headerStyle)),
        DataColumn(label: Text("Total", style: headerStyle)), // Brand Color
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

  List<DataCell> _buildCells(Map<String, dynamic> row, bool isDark) {
    final isManual = widget.params['homeLoanStartMode'] == 'manual';
    TextStyle cellStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white70 : Colors.black87,
    );
    TextStyle boldStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black,
    );

    // ✅ SAFE VALUES FOR CELLS
    double disbursement = _safeDouble(row['disbursement']);
    double outstanding = _safeDouble(row['outstandingBalance']);
    double interest = _safeDouble(row['interestPart']);
    double hlComp = _safeDouble(row['hlComponent']);
    double pl1 = _safeDouble(row['pl1']);
    double total = _safeDouble(row['totalOutflow']);
    double cumDisb = _safeDouble(row['cumulativeDisbursement']);

    if (isManual) {
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
              color: (row['isFullEMI'] == true) ? Colors.green : null,
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
                  color: (row['isFullEMI'] == true)
                      ? Colors.green
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              if (row['isFullEMI'] == true)
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
