/// Multilingual data for exercises and muscle groups
library;

import '../../domain/entities/muscle_group.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/enums.dart';

/// Multilingual muscle group names
const Map<String, Map<String, String>> MUSCLE_GROUP_NAMES = {
  // Major muscle groups
  'chest': {
    'en': 'Chest',
    'ja': '胸筋',
  },
  'back': {
    'en': 'Back',
    'ja': '背筋',
  },
  'quadriceps': {
    'en': 'Quadriceps',
    'ja': '大腿四頭筋',
  },
  'hamstrings': {
    'en': 'Hamstrings',
    'ja': 'ハムストリング',
  },
  'glutes': {
    'en': 'Glutes',
    'ja': '臀筋',
  },
  
  // Shoulder complex
  'shoulders': {
    'en': 'Shoulders',
    'ja': '肩',
  },
  'delts_anterior': {
    'en': 'Front Delts',
    'ja': '前三角筋',
  },
  'delts_medial': {
    'en': 'Side Delts',
    'ja': '中三角筋',
  },
  'delts_posterior': {
    'en': 'Rear Delts',
    'ja': '後三角筋',
  },
  
  // Arms
  'biceps': {
    'en': 'Biceps',
    'ja': '上腕二頭筋',
  },
  'triceps': {
    'en': 'Triceps',
    'ja': '上腕三頭筋',
  },
  'forearms': {
    'en': 'Forearms',
    'ja': '前腕',
  },
  
  // Back subdivisions
  'lats': {
    'en': 'Lats',
    'ja': '広背筋',
  },
  'traps': {
    'en': 'Traps',
    'ja': '僧帽筋',
  },
  'rhomboids': {
    'en': 'Rhomboids',
    'ja': '菱形筋',
  },
  'rear_delts': {
    'en': 'Rear Delts',
    'ja': '後三角筋',
  },
  
  // Lower body
  'calves': {
    'en': 'Calves',
    'ja': 'ふくらはぎ',
  },
  'tibialis': {
    'en': 'Tibialis',
    'ja': '前脛骨筋',
  },
  
  // Core
  'abs': {
    'en': 'Abs',
    'ja': '腹筋',
  },
  'obliques': {
    'en': 'Obliques',
    'ja': '腹斜筋',
  },
  'lower_back': {
    'en': 'Lower Back',
    'ja': '腰',
  },
  
  // Additional muscle groups
  'serratus': {
    'en': 'Serratus',
    'ja': '前鋸筋',
  },
  'hip_flexors': {
    'en': 'Hip Flexors',
    'ja': '股関節屈筋',
  },
  'adductors': {
    'en': 'Adductors',
    'ja': '内転筋',
  },
  'abductors': {
    'en': 'Abductors',
    'ja': '外転筋',
  },
};

/// Body region names
const Map<String, Map<String, String>> BODY_REGION_NAMES = {
  'upper': {
    'en': 'Upper Body',
    'ja': '上半身',
  },
  'lower': {
    'en': 'Lower Body',
    'ja': '下半身',
  },
  'core': {
    'en': 'Core',
    'ja': 'コア',
  },
  'arms': {
    'en': 'Arms',
    'ja': '腕',
  },
  'shoulders': {
    'en': 'Shoulders',
    'ja': '肩',
  },
  'back': {
    'en': 'Back',
    'ja': '背中',
  },
  'chest': {
    'en': 'Chest',
    'ja': '胸',
  },
  'legs': {
    'en': 'Legs',
    'ja': '脚',
  },
};

/// Common exercise names with multilingual support
const Map<String, Map<String, String>> EXERCISE_NAMES = {
  // Chest exercises
  'bench_press': {
    'en': 'Bench Press',
    'ja': 'ベンチプレス',
  },
  'incline_bench_press': {
    'en': 'Incline Bench Press',
    'ja': 'インクラインベンチプレス',
  },
  'decline_bench_press': {
    'en': 'Decline Bench Press',
    'ja': 'デクラインベンチプレス',
  },
  'dumbbell_press': {
    'en': 'Dumbbell Press',
    'ja': 'ダンベルプレス',
  },
  'push_ups': {
    'en': 'Push-ups',
    'ja': '腕立て伏せ',
  },
  'chest_fly': {
    'en': 'Chest Fly',
    'ja': 'チェストフライ',
  },
  'dips': {
    'en': 'Dips',
    'ja': 'ディップス',
  },
  
  // Back exercises
  'deadlift': {
    'en': 'Deadlift',
    'ja': 'デッドリフト',
  },
  'pull_ups': {
    'en': 'Pull-ups',
    'ja': '懸垂',
  },
  'chin_ups': {
    'en': 'Chin-ups',
    'ja': 'チンアップ',
  },
  'barbell_row': {
    'en': 'Barbell Row',
    'ja': 'バーベルロウ',
  },
  'dumbbell_row': {
    'en': 'Dumbbell Row',
    'ja': 'ダンベルロウ',
  },
  'lat_pulldown': {
    'en': 'Lat Pulldown',
    'ja': 'ラットプルダウン',
  },
  'seated_row': {
    'en': 'Seated Row',
    'ja': 'シーテッドロウ',
  },
  't_bar_row': {
    'en': 'T-Bar Row',
    'ja': 'Tバーロウ',
  },
  
  // Leg exercises
  'squat': {
    'en': 'Squat',
    'ja': 'スクワット',
  },
  'front_squat': {
    'en': 'Front Squat',
    'ja': 'フロントスクワット',
  },
  'leg_press': {
    'en': 'Leg Press',
    'ja': 'レッグプレス',
  },
  'lunges': {
    'en': 'Lunges',
    'ja': 'ランジ',
  },
  'leg_curl': {
    'en': 'Leg Curl',
    'ja': 'レッグカール',
  },
  'leg_extension': {
    'en': 'Leg Extension',
    'ja': 'レッグエクステンション',
  },
  'calf_raise': {
    'en': 'Calf Raise',
    'ja': 'カーフレイズ',
  },
  'romanian_deadlift': {
    'en': 'Romanian Deadlift',
    'ja': 'ルーマニアンデッドリフト',
  },
  
  // Shoulder exercises
  'overhead_press': {
    'en': 'Overhead Press',
    'ja': 'オーバーヘッドプレス',
  },
  'military_press': {
    'en': 'Military Press',
    'ja': 'ミリタリープレス',
  },
  'dumbbell_shoulder_press': {
    'en': 'Dumbbell Shoulder Press',
    'ja': 'ダンベルショルダープレス',
  },
  'lateral_raise': {
    'en': 'Lateral Raise',
    'ja': 'ラテラルレイズ',
  },
  'front_raise': {
    'en': 'Front Raise',
    'ja': 'フロントレイズ',
  },
  'rear_delt_fly': {
    'en': 'Rear Delt Fly',
    'ja': 'リアデルトフライ',
  },
  'upright_row': {
    'en': 'Upright Row',
    'ja': 'アップライトロウ',
  },
  'shrugs': {
    'en': 'Shrugs',
    'ja': 'シュラッグ',
  },
  
  // Arm exercises
  'bicep_curl': {
    'en': 'Bicep Curl',
    'ja': 'バイセップカール',
  },
  'hammer_curl': {
    'en': 'Hammer Curl',
    'ja': 'ハンマーカール',
  },
  'preacher_curl': {
    'en': 'Preacher Curl',
    'ja': 'プリーチャーカール',
  },
  'tricep_extension': {
    'en': 'Tricep Extension',
    'ja': 'トライセップエクステンション',
  },
  'close_grip_bench_press': {
    'en': 'Close Grip Bench Press',
    'ja': 'クローズグリップベンチプレス',
  },
  'tricep_dips': {
    'en': 'Tricep Dips',
    'ja': 'トライセップディップス',
  },
  
  // Core exercises
  'plank': {
    'en': 'Plank',
    'ja': 'プランク',
  },
  'crunches': {
    'en': 'Crunches',
    'ja': 'クランチ',
  },
  'sit_ups': {
    'en': 'Sit-ups',
    'ja': '腹筋',
  },
  'russian_twists': {
    'en': 'Russian Twists',
    'ja': 'ロシアンツイスト',
  },
  'leg_raises': {
    'en': 'Leg Raises',
    'ja': 'レッグレイズ',
  },
  'mountain_climbers': {
    'en': 'Mountain Climbers',
    'ja': 'マウンテンクライマー',
  },
};

/// Exercise instructions in multiple languages
const Map<String, Map<String, String>> EXERCISE_INSTRUCTIONS = {
  'squat': {
    'en': 'Stand with feet shoulder-width apart. Lower your body by bending your knees and hips. Keep your chest up and knees aligned with your toes. Return to starting position.',
    'ja': '足を肩幅に開いて立ちます。膝と股関節を曲げて体を下げます。胸を張り、膝をつま先の方向に向けます。開始位置に戻ります。',
  },
  'bench_press': {
    'en': 'Lie on bench with feet flat on floor. Grip bar slightly wider than shoulder-width. Lower bar to chest, then press up to full arm extension.',
    'ja': 'ベンチに仰向けになり、足を床にしっかりつけます。肩幅よりやや広くバーを握ります。バーを胸まで下げ、腕を完全に伸ばして押し上げます。',
  },
  'deadlift': {
    'en': 'Stand with feet hip-width apart, bar over mid-foot. Bend at hips and knees to grip bar. Keep back straight, lift by extending hips and knees.',
    'ja': '足を腰幅に開き、バーを足の中央に置きます。股関節と膝を曲げてバーを握ります。背中をまっすぐに保ち、股関節と膝を伸ばして持ち上げます。',
  },
  'pull_ups': {
    'en': 'Hang from bar with arms fully extended. Pull your body up until chin clears the bar. Lower with control to starting position.',
    'ja': 'バーにぶら下がり、腕を完全に伸ばします。あごがバーを越えるまで体を引き上げます。コントロールしながら開始位置まで下げます。',
  },
  'overhead_press': {
    'en': 'Stand with feet shoulder-width apart. Hold bar at shoulder level. Press bar straight up overhead until arms are fully extended.',
    'ja': '足を肩幅に開いて立ちます。バーを肩の高さで持ちます。腕が完全に伸びるまでバーを頭上に押し上げます。',
  },
};

/// Exercise categories in multiple languages
const Map<String, Map<String, String>> EXERCISE_CATEGORIES = {
  'compound': {
    'en': 'Compound',
    'ja': 'コンパウンド',
  },
  'isolation': {
    'en': 'Isolation',
    'ja': 'アイソレーション',
  },
  'cardio': {
    'en': 'Cardio',
    'ja': '有酸素',
  },
  'strength': {
    'en': 'Strength',
    'ja': '筋力',
  },
  'hypertrophy': {
    'en': 'Hypertrophy',
    'ja': '筋肥大',
  },
  'endurance': {
    'en': 'Endurance',
    'ja': '持久力',
  },
};

/// Equipment types in multiple languages
const Map<EquipmentType, Map<String, String>> EQUIPMENT_NAMES = {
  EquipmentType.barbell: {
    'en': 'Barbell',
    'ja': 'バーベル',
  },
  EquipmentType.dumbbell: {
    'en': 'Dumbbell',
    'ja': 'ダンベル',
  },
  EquipmentType.machine: {
    'en': 'Machine',
    'ja': 'マシン',
  },
  EquipmentType.cable: {
    'en': 'Cable',
    'ja': 'ケーブル',
  },
  EquipmentType.bodyweight: {
    'en': 'Bodyweight',
    'ja': '自重',
  },
  EquipmentType.kettlebell: {
    'en': 'Kettlebell',
    'ja': 'ケトルベル',
  },
  EquipmentType.resistance_band: {
    'en': 'Resistance Band',
    'ja': 'レジスタンスバンド',
  },
  EquipmentType.other: {
    'en': 'Other',
    'ja': 'その他',
  },
};

/// Utility class for multilingual data access
class MultilingualData {
  /// Get localized muscle group name
  static String getMuscleGroupName(String muscleGroupId, String locale) {
    final names = MUSCLE_GROUP_NAMES[muscleGroupId];
    if (names == null) return muscleGroupId;
    return names[locale] ?? names['en'] ?? muscleGroupId;
  }
  
  /// Get localized exercise name
  static String getExerciseName(String exerciseId, String locale) {
    final names = EXERCISE_NAMES[exerciseId];
    if (names == null) return exerciseId;
    return names[locale] ?? names['en'] ?? exerciseId;
  }
  
  /// Get localized exercise instructions
  static String getExerciseInstructions(String exerciseId, String locale) {
    final instructions = EXERCISE_INSTRUCTIONS[exerciseId];
    if (instructions == null) return '';
    return instructions[locale] ?? instructions['en'] ?? '';
  }
  
  /// Get localized equipment name
  static String getEquipmentName(EquipmentType equipment, String locale) {
    final names = EQUIPMENT_NAMES[equipment];
    if (names == null) return equipment.toString();
    return names[locale] ?? names['en'] ?? equipment.toString();
  }
  
  /// Get localized body region name
  static String getBodyRegionName(String regionId, String locale) {
    final names = BODY_REGION_NAMES[regionId];
    if (names == null) return regionId;
    return names[locale] ?? names['en'] ?? regionId;
  }
  
  /// Get localized exercise category name
  static String getExerciseCategoryName(String categoryId, String locale) {
    final names = EXERCISE_CATEGORIES[categoryId];
    if (names == null) return categoryId;
    return names[locale] ?? names['en'] ?? categoryId;
  }
  
  /// Create a list of default muscle groups with multilingual names
  static List<MuscleGroup> createDefaultMuscleGroups() {
    return MUSCLE_GROUP_NAMES.entries.map((entry) {
      final id = entry.key;
      final names = entry.value;
      
      // Determine body region based on muscle group
      String bodyRegion = 'upper';
      if (['quadriceps', 'hamstrings', 'glutes', 'calves', 'tibialis', 'adductors', 'abductors'].contains(id)) {
        bodyRegion = 'lower';
      } else if (['abs', 'obliques', 'lower_back'].contains(id)) {
        bodyRegion = 'core';
      }
      
      return MuscleGroup.withDefaults(
        id: id,
        names: names,
        bodyRegion: bodyRegion,
      );
    }).toList();
  }
  
  /// Create a list of default exercises with multilingual names
  static List<Exercise> createDefaultExercises() {
    final exercises = <Exercise>[];
    
    // Add some common exercises with their muscle group mappings
    final exerciseData = {
      'squat': {
        'category': 'compound',
        'equipment': EquipmentType.barbell,
        'primary': ['quadriceps', 'glutes'],
        'secondary': ['hamstrings', 'lower_back'],
        'isCompound': true,
      },
      'bench_press': {
        'category': 'compound',
        'equipment': EquipmentType.barbell,
        'primary': ['chest'],
        'secondary': ['triceps', 'delts_anterior'],
        'isCompound': true,
      },
      'deadlift': {
        'category': 'compound',
        'equipment': EquipmentType.barbell,
        'primary': ['back', 'hamstrings', 'glutes'],
        'secondary': ['quadriceps', 'traps'],
        'isCompound': true,
      },
      'pull_ups': {
        'category': 'compound',
        'equipment': EquipmentType.bodyweight,
        'primary': ['lats', 'back'],
        'secondary': ['biceps', 'rear_delts'],
        'isCompound': true,
      },
      'overhead_press': {
        'category': 'compound',
        'equipment': EquipmentType.barbell,
        'primary': ['shoulders', 'delts_anterior'],
        'secondary': ['triceps', 'upper_chest'],
        'isCompound': true,
      },
    };
    
    for (final entry in exerciseData.entries) {
      final exerciseId = entry.key;
      final data = entry.value;
      final names = EXERCISE_NAMES[exerciseId] ?? {exerciseId: exerciseId};
      final instructions = EXERCISE_INSTRUCTIONS[exerciseId] ?? <String, String>{};
      
      exercises.add(Exercise(
        id: exerciseId,
        names: names,
        category: data['category'] as String,
        equipment: data['equipment'] as EquipmentType,
        instructions: instructions,
        primaryMuscleGroups: List<String>.from(data['primary'] as List),
        secondaryMuscleGroups: List<String>.from(data['secondary'] as List),
        isCompound: data['isCompound'] as bool,
        createdAt: DateTime.now(),
      ));
    }
    
    return exercises;
  }
}