import 'package:flutter/material.dart';

import 'car_models_screen.dart';

class CarSectionsScreen extends StatelessWidget {
  const CarSectionsScreen({
    super.key,
    required this.brandId,
    required this.brandName,
  });

  final String brandId;
  final String brandName;

  @override
  Widget build(BuildContext context) {
    return CarModelsScreen(
      brandId: brandId,
      brandName: brandName,
    );
  }
}

