import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/enums.dart';

class ExerciseSeeder {
  static List<Exercise> getSampleExercises() {
    return [
      // Chest exercises
      Exercise(
        id: 'bench_press',
        names: {
          'en': 'Bench Press',
          'ja': 'ベンチプレス',
        },
        category: 'chest',
        equipment: EquipmentType.barbell,
        instructions: {
          'en': 'Lie on bench, grip bar with hands wider than shoulders, lower to chest, press up.',
          'ja': 'ベンチに横になり、肩幅より広く握り、胸まで下ろして押し上げる。',
        },
        primaryMuscleGroups: ['chest'],
        secondaryMuscleGroups: ['triceps', 'shoulders'],
        isCompound: true,
        createdAt: DateTime.now(),
      ),
      
      Exercise(
        id: 'incline_dumbbell_press',
        names: {
          'en': 'Incline Dumbbell Press',
          'ja': 'インクラインダンベルプレス',
        },
        category: 'chest',
        equipment: EquipmentType.dumbbell,
        instructions: {
          'en': 'Set bench to 30-45 degrees, press dumbbells from chest level.',
          'ja': 'ベンチを30-45度に設定し、胸の高さからダンベルを押し上げる。',
        },
        primaryMuscleGroups: ['chest'],
        secondaryMuscleGroups: ['triceps', 'shoulders'],
        isCompound: true,
        createdAt: DateTime.now(),
      ),
      
      // Back exercises
      Exercise(
        id: 'deadlift',
        names: {
          'en': 'Deadlift',
          'ja': 'デッドリフト',
        },
        category: 'back',
        equipment: EquipmentType.barbell,
        instructions: {
          'en': 'Stand with feet hip-width apart, grip bar, lift by extending hips and knees.',
          'ja': '足を腰幅に開き、バーを握り、腰と膝を伸ばして持ち上げる。',
        },
        primaryMuscleGroups: ['back', 'hamstrings', 'glutes'],
        secondaryMuscleGroups: ['quadriceps', 'traps'],
        isCompound: true,
        createdAt: DateTime.now(),
      ),
      
      Exercise(
        id: 'pull_ups',
        names: {
          'en': 'Pull-ups',
          'ja': '懸垂',
        },
        category: 'back',
        equipment: EquipmentType.bodyweight,
        instructions: {
          'en': 'Hang from bar with overhand grip, pull body up until chin over bar.',
          'ja': 'バーにオーバーハンドで掴まり、顎がバーを越えるまで体を引き上げる。',
        },
        primaryMuscleGroups: ['back'],
        secondaryMuscleGroups: ['biceps'],
        isCompound: true,
        createdAt: DateTime.now(),
      ),
      
      // Leg exercises
      Exercise(
        id: 'squat',
        names: {
          'en': 'Squat',
          'ja': 'スクワット',
        },
        category: 'legs',
        equipment: EquipmentType.barbell,
        instructions: {
          'en': 'Stand with feet shoulder-width apart, lower hips back and down, return to standing.',
          'ja': '足を肩幅に開き、腰を後ろに下げて下がり、立ち上がる。',
        },
        primaryMuscleGroups: ['quadriceps', 'glutes'],
        secondaryMuscleGroups: ['hamstrings', 'calves'],
        isCompound: true,
        createdAt: DateTime.now(),
      ),
      
      Exercise(
        id: 'leg_press',
        names: {
          'en': 'Leg Press',
          'ja': 'レッグプレス',
        },
        category: 'legs',
        equipment: EquipmentType.machine,
        instructions: {
          'en': 'Sit in machine, place feet on platform, press weight by extending legs.',
          'ja': 'マシンに座り、足をプラットフォームに置き、脚を伸ばして重量を押す。',
        },
        primaryMuscleGroups: ['quadriceps', 'glutes'],
        secondaryMuscleGroups: ['hamstrings'],
        isCompound: true,
        createdAt: DateTime.now(),
      ),
      
      // Shoulder exercises
      Exercise(
        id: 'overhead_press',
        names: {
          'en': 'Overhead Press',
          'ja': 'オーバーヘッドプレス',
        },
        category: 'shoulders',
        equipment: EquipmentType.barbell,
        instructions: {
          'en': 'Stand with feet hip-width apart, press bar from shoulders overhead.',
          'ja': '足を腰幅に開いて立ち、肩からバーを頭上に押し上げる。',
        },
        primaryMuscleGroups: ['shoulders'],
        secondaryMuscleGroups: ['triceps'],
        isCompound: true,
        createdAt: DateTime.now(),
      ),
      
      Exercise(
        id: 'lateral_raises',
        names: {
          'en': 'Lateral Raises',
          'ja': 'ラテラルレイズ',
        },
        category: 'shoulders',
        equipment: EquipmentType.dumbbell,
        instructions: {
          'en': 'Hold dumbbells at sides, raise arms out to shoulder height.',
          'ja': 'ダンベルを体の横に持ち、腕を肩の高さまで上げる。',
        },
        primaryMuscleGroups: ['shoulders'],
        secondaryMuscleGroups: [],
        isCompound: false,
        createdAt: DateTime.now(),
      ),
      
      // Arm exercises
      Exercise(
        id: 'bicep_curls',
        names: {
          'en': 'Bicep Curls',
          'ja': 'バイセップカール',
        },
        category: 'arms',
        equipment: EquipmentType.dumbbell,
        instructions: {
          'en': 'Hold dumbbells at sides, curl weights up by flexing biceps.',
          'ja': 'ダンベルを体の横に持ち、上腕二頭筋を曲げて重量を上げる。',
        },
        primaryMuscleGroups: ['biceps'],
        secondaryMuscleGroups: [],
        isCompound: false,
        createdAt: DateTime.now(),
      ),
      
      Exercise(
        id: 'tricep_dips',
        names: {
          'en': 'Tricep Dips',
          'ja': 'トライセップディップス',
        },
        category: 'arms',
        equipment: EquipmentType.bodyweight,
        instructions: {
          'en': 'Support body on parallel bars or bench, lower and raise body using triceps.',
          'ja': '平行棒やベンチで体を支え、上腕三頭筋を使って体を上下させる。',
        },
        primaryMuscleGroups: ['triceps'],
        secondaryMuscleGroups: ['shoulders', 'chest'],
        isCompound: false,
        createdAt: DateTime.now(),
      ),
    ];
  }
}