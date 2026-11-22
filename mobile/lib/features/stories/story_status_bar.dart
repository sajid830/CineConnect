import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/state/app_state.dart';

class StoryStatusBar extends StatelessWidget {
  final CineAppState state;

  const StoryStatusBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        itemCount: state.stories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final story = state.stories[index];
          final isYou = index == 0;

          return GestureDetector(
            onTap: () => state.openStory(story),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isYou
                            ? null
                            : const SweepGradient(
                                colors: [
                                  CineColors.gold,
                                  CineColors.goldLight,
                                  Color(0xFFF59E0B),
                                  CineColors.gold,
                                ],
                              ),
                        border: isYou
                            ? Border.all(color: CineColors.border, width: 1.5)
                            : null,
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: CineColors.surface,
                        ),
                        child: Center(
                          child: Text(
                            story.initials,
                            style: TextStyle(
                              fontSize: isYou ? 11 : 14,
                              fontWeight: FontWeight.w800,
                              color: isYou ? CineColors.textMuted : CineColors.gold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isYou)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: CineColors.gold,
                          ),
                          child: const Icon(Icons.add, size: 12, color: Colors.black),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 62,
                  child: Text(
                    isYou ? 'Your Story' : story.creatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isYou ? FontWeight.w500 : FontWeight.w700,
                      color: isYou ? CineColors.textMuted : CineColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
