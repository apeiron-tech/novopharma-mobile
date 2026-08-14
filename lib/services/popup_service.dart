import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/models/popup_model.dart';
import 'package:flutter/material.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/screens/goal_details_screen.dart';
import 'package:novopharma/screens/actualite_details_screen.dart';
import 'package:novopharma/screens/goals_screen.dart';
import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/screens/badges_screen.dart';
import 'package:novopharma/screens/sales_history_screen.dart';
import 'package:novopharma/screens/actualites_screen.dart';
import 'package:novopharma/screens/formation_details_screen.dart';
import 'package:novopharma/screens/formations_screen.dart';
import 'package:novopharma/models/blog_post.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:novopharma/services/chottu_link_service.dart';
import 'package:novopharma/navigation.dart';
import 'package:novopharma/screens/custom_page_screen.dart';

class PopupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<PopupModel>> checkAndGetActivePopups(UserModel? user) async {
    if (user == null) {
      debugPrint('[POPUP] User is null');
      return [];
    }
    final now = DateTime.now();
    debugPrint('[POPUP] Checking for active popups at $now');

    List<PopupModel> validPopups = [];

    // Fetch user's category from pharmacy
    String userCategory = '';
    try {
      if (user.pharmacyId.isNotEmpty) {
        final pharmacyDoc = await _firestore.collection('pharmacies').doc(user.pharmacyId).get();
        if (pharmacyDoc.exists) {
          userCategory = pharmacyDoc.data()?['clientCategory'] ?? '';
        }
      }
      debugPrint('[POPUP] User category: "$userCategory"');

      // Simplified query to avoid index requirement for combined where
      final snapshot = await _firestore
          .collection('popups')
          .where('status', isEqualTo: 'active')
          .get();

      debugPrint('[POPUP] Found ${snapshot.docs.length} active popups in database');

      if (snapshot.docs.isEmpty) return [];

      for (var doc in snapshot.docs) {
        final popup = PopupModel.fromFirestore(doc);

        // Check if dates are valid
        if (popup.endDate.isBefore(now)) {
          debugPrint('[POPUP] Skipping "${popup.title}": Expired at ${popup.endDate}');
          continue;
        }
        if (popup.startDate.isAfter(now)) {
          debugPrint('[POPUP] Skipping "${popup.title}": Starts at ${popup.startDate}');
          continue;
        }

        // Filtering logic:
        final popupCategories = popup.clientCategory;
        bool shouldShow = false;

        if (user.role == 'Dermo-conseiller') {
          if (popupCategories.isEmpty || popupCategories.contains('Dermo-conseiller')) {
            shouldShow = true;
          }
        } else {
          if (popupCategories.isEmpty || 
              (popupCategories.contains("Pharmacie") && popupCategories.contains("Para-Pharmacie"))) {
            shouldShow = true;
          } else if (popupCategories.contains("Pharmacie")) {
            if (userCategory == "Pharmacie" || userCategory.isEmpty) {
              shouldShow = true;
            }
          } else if (popupCategories.contains("Para-Pharmacie")) {
            if (userCategory == "Para-Pharmacie") {
              shouldShow = true;
            }
          }
        }

        if (shouldShow) {
          // Additional filter for "test dev" popups
          final isTestDevPopup = popup.title.toLowerCase().contains("test dev");
          if (isTestDevPopup && !user.email.toLowerCase().contains("testdev")) {
            debugPrint('[POPUP] Skipping "${popup.title}": Test Dev popup and user is not test dev');
            shouldShow = false;
          }
        }

        if (shouldShow) {
          debugPrint('[POPUP] Match found: "${popup.title}" (order: ${popup.order})');
          validPopups.add(popup);
        } else {
          debugPrint('[POPUP] Skipping "${popup.title}": filter active');
        }
      }
    } catch (e) {
      debugPrint('Error fetching popups: $e');
    }

    // Sort by order ascending
    validPopups.sort((a, b) => a.order.compareTo(b.order));
    
    return validPopups;
  }

  static void handleRedirection(BuildContext? context, String link) async {
    if (link.isEmpty) return;
    
    debugPrint('[POPUP] Handling redirection for link: $link');

    // Use global navigator context if provided context is unreliable
    final navContext = appNavigatorKey.currentContext ?? context;
    if (navContext == null) {
      debugPrint('[POPUP] Navigation context is null');
      return;
    }

    if (link.startsWith("https://novopharma.chottu.link/")) {
      ChottuLinkService().handleDeepLink(link);
      return;
    }

    // goal/{id} or badge/{id} or formation/{id} or actualite/{id}
    final parts = link.split('/');
    final String type = parts[0];
    final String? id = parts.length > 1 ? parts[1] : null;

    switch (type) {
      case 'goal':
        if (id != null) {
          navigateToGoal(navContext, id);
        } else {
          Navigator.push(
            navContext,
            MaterialPageRoute(builder: (context) => const GoalsScreen()),
          );
        }
        break;
      case 'badge':
        Navigator.push(
          navContext,
          MaterialPageRoute(builder: (context) => const BadgesScreen()),
        );
        break;
      case 'actualite':
        if (id != null) {
          navigateToActualite(navContext, id);
        } else {
          Navigator.push(
            navContext,
            MaterialPageRoute(builder: (context) => const ActualitesScreen()),
          );
        }
        break;
      case 'formation':
        if (id != null) {
          navigateToFormation(navContext, id);
        } else {
          Navigator.pushAndRemoveUntil(
            navContext,
            MaterialPageRoute(builder: (context) => const FormationsScreen()),
            (route) => false,
          );
        }
        break;
      case 'product':
        if (id != null) {
          Navigator.push(
            navContext,
            MaterialPageRoute(builder: (context) => ProductScreen(id: id)),
          );
        }
        break;
      case 'customPage':
        if (id != null) {
          Navigator.push(
            navContext,
            MaterialPageRoute(
              builder: (context) => CustomPageScreen(customPageId: id),
            ),
          );
        }
        break;
      case 'history':
        Navigator.pushAndRemoveUntil(
          navContext,
          MaterialPageRoute(builder: (context) => const SalesHistoryScreen()),
          (route) => false,
        );
        break;
      default:
        // Try to launch as URL if it looks like one
        if (link.startsWith('http') && await canLaunchUrlString(link)) {
          await launchUrlString(link, mode: LaunchMode.externalApplication);
        }
    }
  }

  static void navigateToGoal(BuildContext context, String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('goals').doc(id).get();
      if (doc.exists && context.mounted) {
        final goal = Goal.fromFirestore(doc);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GoalDetailsScreen(goal: goal)),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to goal: $e');
    }
  }

  static void navigateToActualite(BuildContext context, String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('blogPosts').doc(id).get();
      if (doc.exists && context.mounted) {
        final post = BlogPost.fromFirestore(doc);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ActualiteDetailsScreen(actualite: post)),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to actualite: $e');
    }
  }

  static void navigateToFormation(BuildContext context, String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('blogPosts').doc(id).get();
      if (doc.exists && context.mounted) {
        final formation = BlogPost.fromFirestore(doc);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FormationDetailsScreen(formation: formation)),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to formation: $e');
    }
  }
}
