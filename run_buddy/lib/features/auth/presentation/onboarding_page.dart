import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/route_names.dart';
import '../../../app/theme/colors.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'title': 'NEVER RUN ALONE.',
      'subtitle': 'Run, talk, and stay motivated with someone anywhere in the world. Two runners, one shared synchronized pace.',
      'image': 'assets/images/running_duo.jpg',
      'tag': 'REMOTE SOCIAL RUNNING',
    },
    {
      'title': 'LIVE PROXIMITY & MAPS',
      'subtitle': 'Feel like you are on the same track with live meter-by-meter delta markers, companion route overlays, and instant encouragement.',
      'image': 'assets/images/running_dark_hero.jpg',
      'tag': 'REAL-TIME TELEMETRY',
    },
    {
      'title': 'CRYSTAL VOICE CHAT',
      'subtitle': 'Integrated managed WebRTC audio keeps your breath and pace connected naturally. No awkward group calls or dropouts.',
      'image': 'assets/images/running_track_night.jpg',
      'tag': 'NATURAL AUDIO PRESENCE',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background PageView with photography
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _slides[index]['image']!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.midnightNavy.withValues(alpha: 0.35),
                          AppColors.midnightNavy.withValues(alpha: 0.70),
                          AppColors.midnightNavy.withValues(alpha: 0.98),
                        ],
                        stops: const [0.0, 0.5, 0.85],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Content Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row: Brand & Skip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.electricLime,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bolt_rounded, size: 18, color: AppColors.midnightNavy),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'RUN BUDDY',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => context.go(RouteNames.login),
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Tag Pill
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.electricLime.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.electricLime.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        _slides[_currentPage]['tag']!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.electricLime,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Slide Title
                  Text(
                    _slides[_currentPage]['title']!,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Slide Subtitle
                  Text(
                    _slides[_currentPage]['subtitle']!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Page Indicator Dots
                  Row(
                    children: List.generate(_slides.length, (idx) {
                      final isActive = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 6,
                        width: isActive ? 28 : 8,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.electricLime : AppColors.borderNavy,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push(RouteNames.register),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.borderNavy, width: 1.5),
                            backgroundColor: AppColors.surfaceNavy.withValues(alpha: 0.6),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          child: const Text(
                            'JOIN NOW',
                            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.go(RouteNames.login),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.electricLime,
                            foregroundColor: AppColors.midnightNavy,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            elevation: 4,
                            shadowColor: AppColors.electricLime.withValues(alpha: 0.4),
                          ),
                          child: const Text(
                            'SIGN IN',
                            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
