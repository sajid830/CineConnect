import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';

class InitialsAvatar extends StatelessWidget {
  final String initials;
  final double radius;

  const InitialsAvatar({super.key, required this.initials, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.gold,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.black,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}