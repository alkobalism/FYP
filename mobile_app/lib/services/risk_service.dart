class RiskService {
  // Constant for average e-scooter wheel diameter in inches
  static const double wheelDiameter = 8.5;
  // Assumed maximum speed for micro-mobility in km/h
  static const double vMax = 40.0;
  // Calibration multiplier to scale the raw math output to a clean 0-100% UI value
  static const double calibrationConstant = 180.0;

  // Calculate risk level based on the physics formula from Chapter 2.2.2
  static Map<String, dynamic> calculateRisk(double area, double speedKmh) {
    
    // Safety check to prevent division by zero or negative speeds
    double vCurrent = speedKmh < 0 ? 0 : speedKmh;
    
    // The Physics Formula: Risk = (Area / Wheel) * (V_current / V_max)^2 * 100 * Calibration
    double velocityRatio = vCurrent / vMax;
    double kineticEnergyFactor = velocityRatio * velocityRatio; // V^2
    
    double dimensionRatio = area / wheelDiameter;
    
    double rawRisk = dimensionRatio * kineticEnergyFactor * 100 * calibrationConstant;
    
    // Clamp to 100% maximum
    int percentage = rawRisk.round().clamp(0, 100);

    String level = 'LOW';
    if (percentage >= 75) {
      level = 'HIGH';
    } else if (percentage >= 40) {
      level = 'MEDIUM';
    }

    return {
      'percentage': percentage,
      'level': level
    };
  }

  static double calculateArea(double w, double h) {
    return w * h;
  }
}
