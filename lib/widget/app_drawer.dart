import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../pages/saved_properties.dart'; // Import your new screen

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          // 1. USER HEADER
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade900,
            ),
            accountName: Text(
              user?.displayName ?? "User",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(user?.email ?? "Not signed in"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Text(
                      (user?.email ?? "U")[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.blue.shade900,
                      ),
                    )
                  : null,
            ),
          ),

          // 2. MENU ITEMS
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // --- SAVED PROPERTIES ---
                ListTile(
                  leading: const Icon(
                    Icons.folder_special_outlined,
                    color: Colors.blue,
                  ),
                  title: const Text("Saved Properties"),
                  subtitle: const Text("View your cloud portfolio"),
                  onTap: () {
                    // Close drawer first
                    Navigator.pop(context);
                    // Navigate to Saved Screen
                    Get.to(() => SavedPropertiesScreen());
                  },
                ),

                const Divider(),

                // --- OPTIONAL: INPUTS TAB SHORTCUT ---
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text("Calculator"),
                  onTap: () {
                    Navigator.pop(context); // Just close drawer if already here
                  },
                ),
              ],
            ),
          ),

          // 3. BOTTOM ACTIONS (Sign Out)
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Sign Out", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context); // Close drawer
              Get.snackbar("Signed Out", "See you next time!");
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
