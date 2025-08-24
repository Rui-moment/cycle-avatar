/// Core enums used throughout the domain layer
library;

/// Training goal types that determine workout recommendations
enum TrainingGoal {
  hypertrophy,
  strength,
  general;

  String getLocalizedName(String locale) {
    switch (this) {
      case TrainingGoal.hypertrophy:
        return locale == 'ja' ? '筋肥大' : 'Hypertrophy';
      case TrainingGoal.strength:
        return locale == 'ja' ? '筋力' : 'Strength';
      case TrainingGoal.general:
        return locale == 'ja' ? '一般' : 'General';
    }
  }
}

/// Readiness level indicating recovery status of muscle groups
enum ReadinessLevel {
  ready,
  warm,
  fatigued;

  String getLocalizedName(String locale) {
    switch (this) {
      case ReadinessLevel.ready:
        return locale == 'ja' ? '準備完了' : 'Ready';
      case ReadinessLevel.warm:
        return locale == 'ja' ? 'ウォーミング' : 'Warm';
      case ReadinessLevel.fatigued:
        return locale == 'ja' ? '疲労' : 'Fatigued';
    }
  }

  /// Get readiness level from fatigue score
  static ReadinessLevel fromFatigueScore(double fatigueScore) {
    if (fatigueScore < 30) return ReadinessLevel.ready;
    if (fatigueScore < 70) return ReadinessLevel.warm;
    return ReadinessLevel.fatigued;
  }
}

/// Session types for categorizing workouts
enum SessionType {
  strength,
  hypertrophy,
  endurance,
  deload,
  template,
  custom;

  String getLocalizedName(String locale) {
    switch (this) {
      case SessionType.strength:
        return locale == 'ja' ? '筋力' : 'Strength';
      case SessionType.hypertrophy:
        return locale == 'ja' ? '筋肥大' : 'Hypertrophy';
      case SessionType.endurance:
        return locale == 'ja' ? '持久力' : 'Endurance';
      case SessionType.deload:
        return locale == 'ja' ? 'デロード' : 'Deload';
      case SessionType.template:
        return locale == 'ja' ? 'テンプレート' : 'Template';
      case SessionType.custom:
        return locale == 'ja' ? 'カスタム' : 'Custom';
    }
  }
}

/// Equipment types for exercises
enum EquipmentType {
  barbell,
  dumbbell,
  machine,
  cable,
  bodyweight,
  kettlebell,
  resistance_band,
  other;

  String getLocalizedName(String locale) {
    switch (this) {
      case EquipmentType.barbell:
        return locale == 'ja' ? 'バーベル' : 'Barbell';
      case EquipmentType.dumbbell:
        return locale == 'ja' ? 'ダンベル' : 'Dumbbell';
      case EquipmentType.machine:
        return locale == 'ja' ? 'マシン' : 'Machine';
      case EquipmentType.cable:
        return locale == 'ja' ? 'ケーブル' : 'Cable';
      case EquipmentType.bodyweight:
        return locale == 'ja' ? '自重' : 'Bodyweight';
      case EquipmentType.kettlebell:
        return locale == 'ja' ? 'ケトルベル' : 'Kettlebell';
      case EquipmentType.resistance_band:
        return locale == 'ja' ? 'レジスタンスバンド' : 'Resistance Band';
      case EquipmentType.other:
        return locale == 'ja' ? 'その他' : 'Other';
    }
  }
}