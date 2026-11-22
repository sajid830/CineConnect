import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/company_profile.dart';

class CompanyLogo extends StatelessWidget {
  final CompanyProfile profile;
  final double size;

  const CompanyLogo({super.key, required this.profile, this.size = 92});

  Widget get _initialsTile => Container(
        alignment: Alignment.center,
        color: AppColors.gold,
        child: Text(
          profile.initials,
          style: TextStyle(
            fontSize: size * 0.33,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
        ),
      );

  Widget _image(String url) {
    if (url.startsWith('data:')) {
      try {
        final bytes = UriData.parse(url).contentAsBytes();
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsTile,
        );
      } catch (_) {
        return _initialsTile;
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _initialsTile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = profile.logoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null ? _initialsTile : _image(url),
      ),
    );
  }
}