import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:property_analyzer_mobile/controller/property_controller.dart';
import '../service/portfolio_service.dart';
import 'dart:convert'; // For jsonEncode
import 'package:shared_preferences/shared_preferences.dart'; // For saving to disk

class SavedPropertiesScreen extends StatelessWidget {
  final PortfolioService _service = PortfolioService();

  SavedPropertiesScreen({super.key});

  // Helper to format currency (Indian Lakhs/Cr style)
  String formatCurrency(dynamic value) {
    if (value == null) return "₹0";
    double amount = double.tryParse(value.toString()) ?? 0;

    if (amount >= 10000000) {
      return "₹${(amount / 10000000).toStringAsFixed(2)} Cr";
    } else if (amount >= 100000) {
      return "₹${(amount / 100000).toStringAsFixed(2)} L";
    }
    return "₹${amount.toStringAsFixed(0)}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.grey.shade50;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final text = isDark ? Colors.white : Colors.black87;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text("Saved Properties", style: TextStyle(fontSize: 16)),
        backgroundColor: cardBg,
        foregroundColor: text,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getUserScenarios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: bg),
                  const SizedBox(height: 16),
                  const Text("No saved properties yet."),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // --- 1. EXTRACT DATA FOR CALCULATIONS ---
              // Try to find property size from the saved complex object
              double size = 0;
              try {
                // Accessing: data -> properties -> [0] -> size
                var propList = data['data']['properties'] as List;
                if (propList.isNotEmpty) {
                  size = double.tryParse(propList[0]['size'].toString()) ?? 0;
                }
              } catch (e) {
                size = 0;
              }

              // Get Rates
              double totalCost =
                  double.tryParse(data['metrics']['totalCost'].toString()) ?? 0;
              double exitRate =
                  double.tryParse(
                    data['selections']['selectedExitPrice'].toString(),
                  ) ??
                  0;

              // Logic: If size exists, Total Sell = Rate * Size. Else just Rate.
              double totalSellValue = size > 0 ? (exitRate * size) : exitRate;
              double netProfit =
                  double.tryParse(data['metrics']['netProfit'].toString()) ?? 0;
              double roi =
                  double.tryParse(data['metrics']['roi'].toString()) ?? 0;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? "Untitled",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${data['location']} ${size > 0 ? '• ${size.toInt()} sq.ft' : ''}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _service.deleteScenario(doc.id),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // --- BUY VS SELL ROW ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Buy Price",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  formatCurrency(totalCost),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 24, color: cardBg),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  "Sell Price",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  formatCurrency(totalSellValue),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // --- METRICS GRID ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricBox(
                              "ROI",
                              "${roi.toStringAsFixed(1)}%",
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricBox(
                              "Net Profit",
                              formatCurrency(netProfit),
                              netProfit >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // --- LOAD BUTTON ---
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text("Load Scenario"),
                          onPressed: () {
                            // 1. Show Confirmation Dialog
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Load Property?"),
                                content: Text(
                                  "This will replace your current inputs with '${data['name']}'.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Cancel"),
                                  ),
                                  // Inside the 'Load' button onPressed:
                                  ElevatedButton(
                                    onPressed: () async {
                                      // <--- Make this async
                                      // 1. Get Controller
                                      final controller =
                                          Get.find<PropertyController>();

                                      // 2. Update Memory (GetX Controller) - The "Immediate" Fix
                                      if (data['data'] != null) {
                                        controller.propertyData.value =
                                            data['data'];
                                      }
                                      if (data['selections'] != null) {
                                        controller.userSelections.value =
                                            data['selections'];
                                      }

                                      // 3. FORCE INPUTS TO REBUILD
                                      controller.formVersion.value++;

                                      // ---------------------------------------------------------
                                      // ✅ 4. PERSISTENCE STEP (The "Hot Restart" Fix)
                                      // We save this data to SharedPreferences so 'PropertyComparisonMobile' finds it on startup.
                                      // ---------------------------------------------------------
                                      final prefs =
                                          await SharedPreferences.getInstance();

                                      if (data['data'] != null) {
                                        await prefs.setString(
                                          'propertyData',
                                          jsonEncode(data['data']),
                                        );
                                      }
                                      if (data['selections'] != null) {
                                        await prefs.setString(
                                          'userSelections',
                                          jsonEncode(data['selections']),
                                        );
                                      }
                                      // ---------------------------------------------------------

                                      // 5. Refresh Logic & Navigate Back
                                      controller.propertyData.refresh();
                                      controller.userSelections.refresh();
                                      controller.calculate();

                                      if (context.mounted) {
                                        Navigator.pop(ctx); // Close Dialog
                                        Navigator.pop(context); // Close Screen
                                      }

                                      Get.snackbar(
                                        "Loaded & Saved",
                                        "Property details loaded and saved to local storage!",
                                        backgroundColor: Colors.green,
                                        colorText: Colors.white,
                                      );
                                    },
                                    child: const Text("Load"),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
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
