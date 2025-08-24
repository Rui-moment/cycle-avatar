import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/workout/workout_page.dart';
import '../../presentation/pages/avatar/avatar_page.dart';
import '../../presentation/pages/history/history_page.dart';
import '../../presentation/pages/settings/settings_page.dart';
import '../../presentation/pages/templates/template_list_page.dart';
import '../../presentation/pages/templates/template_detail_page.dart';
import '../../presentation/pages/templates/template_form_page.dart';
import '../../presentation/pages/settings/language_settings_page.dart';
import '../../presentation/pages/settings/notification_settings_page.dart';
import '../../presentation/pages/settings/accessibility_settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/workout',
        name: 'workout',
        builder: (context, state) => const WorkoutPage(),
      ),
      GoRoute(
        path: '/avatar',
        name: 'avatar',
        builder: (context, state) => const AvatarPage(),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
        routes: [
          GoRoute(
            path: '/language',
            name: 'language-settings',
            builder: (context, state) => const LanguageSettingsPage(),
          ),
          GoRoute(
            path: '/notifications',
            name: 'notification-settings',
            builder: (context, state) => const NotificationSettingsPage(),
          ),
          GoRoute(
            path: '/accessibility',
            name: 'accessibility-settings',
            builder: (context, state) => const AccessibilitySettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/templates',
        name: 'templates',
        builder: (context, state) => const TemplateListPage(),
        routes: [
          GoRoute(
            path: '/create',
            name: 'template-create',
            builder: (context, state) => const TemplateFormPage(),
          ),
          GoRoute(
            path: '/edit/:templateId',
            name: 'template-edit',
            builder: (context, state) {
              final templateId = state.pathParameters['templateId']!;
              return TemplateFormPage(templateId: templateId);
            },
          ),
          GoRoute(
            path: '/:templateId',
            name: 'template-detail',
            builder: (context, state) {
              final templateId = state.pathParameters['templateId']!;
              return TemplateDetailPage(templateId: templateId);
            },
          ),
        ],
      ),
    ],
  );
});