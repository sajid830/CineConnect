import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';

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