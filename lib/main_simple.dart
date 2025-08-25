import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'presentation/widgets/avatar/anime_avatar_widget.dart';
import 'domain/entities/recovery_state.dart';
import 'domain/entities/enums.dart';

// Enums
enum MuscleGroupState { ready, warm, fatigued }

// Global state providers
final workoutDataProvider = StateNotifierProvider<WorkoutDataNotifier, WorkoutData>((ref) {
  return WorkoutDataNotifier();
});

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  return LanguageNotifier();
});

// Data models
class WorkoutData {
  final List<WorkoutSession> sessions;
  final double totalVolume;
  final int totalSets;
  final double avatarLevel;
  final Map<String, double> muscleGroupLevels;
  final Map<String, MuscleGroupState> muscleGroupStates;
  final Map<String, double> muscleGroupFatigue; // 疲労度 (0-100)
  final List<WorkoutTemplate> templates;

  const WorkoutData({
    this.sessions = const [],
    this.totalVolume = 0,
    this.totalSets = 0,
    this.avatarLevel = 1.0,
    this.muscleGroupLevels = const {
      'Chest': 1.0,
      'Back': 1.0,
      'Legs': 1.0,
      'Shoulders': 1.0,
      'Arms': 1.0,
    },
    this.muscleGroupStates = const {
      'Chest': MuscleGroupState.ready,
      'Back': MuscleGroupState.ready,
      'Legs': MuscleGroupState.ready,
      'Shoulders': MuscleGroupState.ready,
      'Arms': MuscleGroupState.ready,
    },
    this.muscleGroupFatigue = const {
      'Chest': 0.0,
      'Back': 0.0,
      'Legs': 0.0,
      'Shoulders': 0.0,
      'Arms': 0.0,
    },
    this.templates = const [],
  });

  WorkoutData copyWith({
    List<WorkoutSession>? sessions,
    double? totalVolume,
    int? totalSets,
    double? avatarLevel,
    Map<String, double>? muscleGroupLevels,
    Map<String, MuscleGroupState>? muscleGroupStates,
    Map<String, double>? muscleGroupFatigue,
    List<WorkoutTemplate>? templates,
  }) {
    return WorkoutData(
      sessions: sessions ?? this.sessions,
      totalVolume: totalVolume ?? this.totalVolume,
      totalSets: totalSets ?? this.totalSets,
      avatarLevel: avatarLevel ?? this.avatarLevel,
      muscleGroupLevels: muscleGroupLevels ?? this.muscleGroupLevels,
      muscleGroupStates: muscleGroupStates ?? this.muscleGroupStates,
      muscleGroupFatigue: muscleGroupFatigue ?? this.muscleGroupFatigue,
      templates: templates ?? this.templates,
    );
  }
}

class WorkoutSession {
  final String name;
  final List<WorkoutSet> sets;
  final DateTime date;
  final double volume;

  const WorkoutSession({
    required this.name,
    required this.sets,
    required this.date,
    required this.volume,
  });
}

class WorkoutSet {
  final double weight;
  final int reps;
  final int rpe;
  final DateTime time;

  const WorkoutSet({
    required this.weight,
    required this.reps,
    required this.rpe,
    required this.time,
  });
}

class WorkoutTemplate {
  final String name;
  final List<String> exercises;
  final Map<String, List<WorkoutSet>> suggestedSets;

  const WorkoutTemplate({
    required this.name,
    required this.exercises,
    required this.suggestedSets,
  });
}

// State notifiers
class WorkoutDataNotifier extends StateNotifier<WorkoutData> {
  WorkoutDataNotifier() : super(const WorkoutData()) {
    // Initialize with default templates
    _initializeTemplates();
    // Start recovery timer
    _startRecoveryTimer();
  }

  /// Convert current muscle group states to RecoveryState format for avatar
  Map<String, RecoveryState> getRecoveryStatesForAvatar() {
    final recoveryStates = <String, RecoveryState>{};
    
    // Map our muscle groups to avatar muscle groups
    final muscleGroupMapping = {
      'Chest': ['chest'],
      'Back': ['back'],
      'Legs': ['quadriceps', 'hamstrings', 'calves'],
      'Shoulders': ['shoulders'],
      'Arms': ['biceps', 'triceps'],
    };
    
    print('DEBUG: Converting fatigue states for avatar:');
    for (final entry in state.muscleGroupFatigue.entries) {
      final ourMuscleGroup = entry.key;
      final fatigueLevel = entry.value;
      final readinessLevel = ReadinessLevel.fromFatigueScore(fatigueLevel);
      
      print('DEBUG: $ourMuscleGroup - Fatigue: ${fatigueLevel.toStringAsFixed(1)}, Level: ${readinessLevel.name}');
      
      // Map to avatar muscle groups
      final avatarMuscleGroups = muscleGroupMapping[ourMuscleGroup] ?? [ourMuscleGroup.toLowerCase()];
      
      for (final avatarMuscleGroup in avatarMuscleGroups) {
        recoveryStates[avatarMuscleGroup] = RecoveryState(
          id: 'recovery_${avatarMuscleGroup}',
          muscleGroupId: avatarMuscleGroup,
          currentFatigue: fatigueLevel,
          lastUpdated: DateTime.now(),
          readinessLevel: readinessLevel,
          initialFatigue: 100.0, // Assume max fatigue for percentage calculation
        );
      }
    }
    
    print('DEBUG: Avatar recovery states: ${recoveryStates.keys.toList()}');
    return recoveryStates;
  }

  void _initializeTemplates() {
    final now = DateTime.now();
    final defaultTemplates = [
      WorkoutTemplate(
        name: 'Push Day',
        exercises: ['Bench Press', 'Overhead Press', 'Dip'],
        suggestedSets: {
          'Bench Press': [
            WorkoutSet(weight: 80, reps: 8, rpe: 8, time: now),
            WorkoutSet(weight: 80, reps: 8, rpe: 8, time: now),
            WorkoutSet(weight: 80, reps: 8, rpe: 9, time: now),
          ],
          'Overhead Press': [
            WorkoutSet(weight: 50, reps: 8, rpe: 8, time: now),
            WorkoutSet(weight: 50, reps: 8, rpe: 8, time: now),
            WorkoutSet(weight: 50, reps: 8, rpe: 9, time: now),
          ],
          'Dip': [
            WorkoutSet(weight: 0, reps: 12, rpe: 8, time: now),
            WorkoutSet(weight: 0, reps: 12, rpe: 8, time: now),
            WorkoutSet(weight: 0, reps: 12, rpe: 9, time: now),
          ],
        },
      ),
      WorkoutTemplate(
        name: 'Pull Day',
        exercises: ['Deadlift', 'Barbell Row', 'Pull-up'],
        suggestedSets: {
          'Deadlift': [
            WorkoutSet(weight: 120, reps: 5, rpe: 8, time: now),
            WorkoutSet(weight: 120, reps: 5, rpe: 8, time: now),
            WorkoutSet(weight: 120, reps: 5, rpe: 9, time: now),
          ],
          'Barbell Row': [
            WorkoutSet(weight: 70, reps: 8, rpe: 8, time: now),
            WorkoutSet(weight: 70, reps: 8, rpe: 8, time: now),
            WorkoutSet(weight: 70, reps: 8, rpe: 9, time: now),
          ],
          'Pull-up': [
            WorkoutSet(weight: 0, reps: 8, rpe: 8, time: now),
            WorkoutSet(weight: 0, reps: 8, rpe: 8, time: now),
            WorkoutSet(weight: 0, reps: 8, rpe: 9, time: now),
          ],
        },
      ),
      WorkoutTemplate(
        name: 'Leg Day',
        exercises: ['Squat', 'Lunges', 'Calf Raise'],
        suggestedSets: {
          'Squat': [
            WorkoutSet(weight: 100, reps: 8, rpe: 8, time: now),
            WorkoutSet(weight: 100, reps: 8, rpe: 8, time: now),
            WorkoutSet(weight: 100, reps: 8, rpe: 9, time: now),
          ],
          'Lunges': [
            WorkoutSet(weight: 40, reps: 12, rpe: 8, time: now),
            WorkoutSet(weight: 40, reps: 12, rpe: 8, time: now),
            WorkoutSet(weight: 40, reps: 12, rpe: 9, time: now),
          ],
          'Calf Raise': [
            WorkoutSet(weight: 60, reps: 15, rpe: 8, time: now),
            WorkoutSet(weight: 60, reps: 15, rpe: 8, time: now),
            WorkoutSet(weight: 60, reps: 15, rpe: 9, time: now),
          ],
        },
      ),
    ];
    
    state = state.copyWith(templates: defaultTemplates);
  }

  void _startRecoveryTimer() {
    // Update recovery every 30 seconds for demo purposes
    Future.delayed(const Duration(seconds: 30), () {
      _updateRecovery();
      _startRecoveryTimer();
    });
  }

  void _updateRecovery() {
    final newFatigue = Map<String, double>.from(state.muscleGroupFatigue);
    final newStates = Map<String, MuscleGroupState>.from(state.muscleGroupStates);
    bool hasChanges = false;

    // Recovery: reduce fatigue by 10 points every 30 seconds (slower recovery)
    for (final entry in newFatigue.entries) {
      final currentFatigue = entry.value;
      if (currentFatigue > 0) {
        final newFatigueValue = (currentFatigue - 10).clamp(0.0, 100.0);
        newFatigue[entry.key] = newFatigueValue;
        
        // Update state based on fatigue level (80% threshold for fatigued)
        if (newFatigueValue >= 80) {
          newStates[entry.key] = MuscleGroupState.fatigued;
        } else if (newFatigueValue >= 40) {
          newStates[entry.key] = MuscleGroupState.warm;
        } else {
          newStates[entry.key] = MuscleGroupState.ready;
        }
        hasChanges = true;
      }
    }

    if (hasChanges) {
      state = state.copyWith(
        muscleGroupFatigue: newFatigue,
        muscleGroupStates: newStates,
      );
      print('DEBUG: Recovery updated - Fatigue: ${newFatigue.map((k, v) => MapEntry(k, v.toStringAsFixed(0)))}');
      print('DEBUG: States: ${newStates.map((k, v) => MapEntry(k, v.name))}');
    }
  }

  void addWorkoutSession(String name, List<WorkoutSet> sets) {
    print('DEBUG: Adding workout session: $name with ${sets.length} sets');
    
    // Enhanced volume calculation with RPE weighting
    final totalVolume = _calculateTotalVolume(sets);
    final stimulusScore = _calculateStimulusScore(name, sets);
    
    final session = WorkoutSession(
      name: name,
      sets: sets,
      date: DateTime.now(),
      volume: totalVolume,
    );

    final newSessions = [...state.sessions, session];
    final newTotalVolume = state.totalVolume + totalVolume;
    final newTotalSets = state.totalSets + sets.length;
    
    // Enhanced avatar level progression based on stimulus
    final progressPoints = _calculateProgressPoints(sets, stimulusScore);
    final newAvatarLevel = state.avatarLevel + (progressPoints / 100);
    
    print('DEBUG: Volume: ${totalVolume.toStringAsFixed(1)}kg, Stimulus: ${stimulusScore.toStringAsFixed(1)}');
    print('DEBUG: New avatar level: $newAvatarLevel (was ${state.avatarLevel})');
    
    // Enhanced muscle group stimulation
    final newMuscleGroupLevels = _applyMuscleGroupStimulation(name, sets, state.muscleGroupLevels);
    
    // Apply fatigue based on stimulus intensity
    final fatigueResult = _applyMuscleGroupFatigue(name, sets, state.muscleGroupFatigue, state.muscleGroupStates);

    state = state.copyWith(
      sessions: newSessions,
      totalVolume: newTotalVolume,
      totalSets: newTotalSets,
      avatarLevel: newAvatarLevel,
      muscleGroupLevels: newMuscleGroupLevels,
      muscleGroupFatigue: fatigueResult['fatigue'] as Map<String, double>,
      muscleGroupStates: fatigueResult['states'] as Map<String, MuscleGroupState>,
    );
    
    print('DEBUG: State updated. Sessions count: ${state.sessions.length}');
  }

  // Enhanced volume calculation with RPE weighting
  double _calculateTotalVolume(List<WorkoutSet> sets) {
    return sets.fold<double>(0, (sum, set) {
      final baseVolume = set.weight * set.reps;
      final rpeMultiplier = _getRPEMultiplier(set.rpe);
      return sum + (baseVolume * rpeMultiplier);
    });
  }

  // RPE-based intensity multiplier
  double _getRPEMultiplier(int rpe) {
    // RPE 6-10 mapped to multipliers 0.6-1.4
    return (rpe.clamp(6, 10) - 5) * 0.2 + 0.4;
  }

  // Calculate stimulus score for muscle growth
  double _calculateStimulusScore(String exerciseName, List<WorkoutSet> sets) {
    final exerciseLower = exerciseName.toLowerCase();
    double baseStimulus = 0;
    
    // Exercise-specific stimulus multipliers
    if (exerciseLower.contains('squat') || exerciseLower.contains('deadlift')) {
      baseStimulus = 1.5; // Compound movements = higher stimulus
    } else if (exerciseLower.contains('bench') || exerciseLower.contains('pull')) {
      baseStimulus = 1.3;
    } else if (exerciseLower.contains('curl') || exerciseLower.contains('extension')) {
      baseStimulus = 0.8; // Isolation movements = lower stimulus
    } else {
      baseStimulus = 1.0;
    }
    
    // Volume and intensity contribution
    final totalSets = sets.length;
    final avgRPE = sets.fold<double>(0, (sum, set) => sum + set.rpe) / sets.length;
    
    return baseStimulus * totalSets * (avgRPE / 10);
  }

  // Calculate progress points based on volume and stimulus
  double _calculateProgressPoints(List<WorkoutSet> sets, double stimulusScore) {
    final setPoints = sets.length * 30; // Base points per set
    final stimulusPoints = stimulusScore * 20; // Stimulus bonus
    final volumePoints = sets.fold<double>(0, (sum, set) => sum + set.weight * set.reps) / 20;
    
    return setPoints + stimulusPoints + volumePoints;
  }

  // Enhanced muscle group stimulation with detailed mapping
  Map<String, double> _applyMuscleGroupStimulation(
    String exerciseName, 
    List<WorkoutSet> sets, 
    Map<String, double> currentLevels
  ) {
    final newLevels = Map<String, double>.from(currentLevels);
    final exerciseLower = exerciseName.toLowerCase();
    final stimulusIntensity = _calculateStimulusScore(exerciseName, sets) / 10;
    
    // Primary muscle group stimulation (main target)
    if (exerciseLower.contains('squat') || exerciseLower.contains('lunges')) {
      newLevels['Legs'] = (newLevels['Legs']! + stimulusIntensity * 0.8).clamp(1.0, 10.0);
      newLevels['Back'] = (newLevels['Back']! + stimulusIntensity * 0.2).clamp(1.0, 10.0); // Secondary
    } else if (exerciseLower.contains('deadlift')) {
      newLevels['Back'] = (newLevels['Back']! + stimulusIntensity * 0.6).clamp(1.0, 10.0);
      newLevels['Legs'] = (newLevels['Legs']! + stimulusIntensity * 0.4).clamp(1.0, 10.0);
    } else if (exerciseLower.contains('bench') || exerciseLower.contains('push')) {
      newLevels['Chest'] = (newLevels['Chest']! + stimulusIntensity * 0.7).clamp(1.0, 10.0);
      newLevels['Shoulders'] = (newLevels['Shoulders']! + stimulusIntensity * 0.2).clamp(1.0, 10.0);
      newLevels['Arms'] = (newLevels['Arms']! + stimulusIntensity * 0.1).clamp(1.0, 10.0);
    } else if (exerciseLower.contains('pull') || exerciseLower.contains('row') || exerciseLower.contains('chin')) {
      newLevels['Back'] = (newLevels['Back']! + stimulusIntensity * 0.7).clamp(1.0, 10.0);
      newLevels['Arms'] = (newLevels['Arms']! + stimulusIntensity * 0.3).clamp(1.0, 10.0);
    } else if (exerciseLower.contains('press') && exerciseLower.contains('shoulder')) {
      newLevels['Shoulders'] = (newLevels['Shoulders']! + stimulusIntensity * 0.8).clamp(1.0, 10.0);
      newLevels['Arms'] = (newLevels['Arms']! + stimulusIntensity * 0.2).clamp(1.0, 10.0);
    } else if (exerciseLower.contains('curl')) {
      newLevels['Arms'] = (newLevels['Arms']! + stimulusIntensity * 0.9).clamp(1.0, 10.0);
    } else if (exerciseLower.contains('extension') || exerciseLower.contains('tricep')) {
      newLevels['Arms'] = (newLevels['Arms']! + stimulusIntensity * 0.8).clamp(1.0, 10.0);
    } else if (exerciseLower.contains('leg') || exerciseLower.contains('calf')) {
      newLevels['Legs'] = (newLevels['Legs']! + stimulusIntensity * 0.9).clamp(1.0, 10.0);
    } else if (exerciseLower.contains('dip')) {
      newLevels['Chest'] = (newLevels['Chest']! + stimulusIntensity * 0.5).clamp(1.0, 10.0);
      newLevels['Shoulders'] = (newLevels['Shoulders']! + stimulusIntensity * 0.3).clamp(1.0, 10.0);
      newLevels['Arms'] = (newLevels['Arms']! + stimulusIntensity * 0.2).clamp(1.0, 10.0);
    } else {
      // Default: small general progression
      newLevels.updateAll((key, value) => (value + stimulusIntensity * 0.1).clamp(1.0, 10.0));
    }
    
    // Log the stimulation details
    print('DEBUG: Exercise: $exerciseName, Stimulus: ${stimulusIntensity.toStringAsFixed(2)}');
    print('DEBUG: Muscle progression: ${newLevels.map((k, v) => MapEntry(k, v.toStringAsFixed(1)))}');
    
    return newLevels;
  }

  // Apply fatigue based on workout intensity
  Map<String, dynamic> _applyMuscleGroupFatigue(
    String exerciseName,
    List<WorkoutSet> sets,
    Map<String, double> currentFatigue,
    Map<String, MuscleGroupState> currentStates,
  ) {
    final newFatigue = Map<String, double>.from(currentFatigue);
    final newStates = Map<String, MuscleGroupState>.from(currentStates);
    final exerciseLower = exerciseName.toLowerCase();
    
    // Calculate fatigue based on volume and intensity
    final totalSets = sets.length;
    final avgRPE = sets.fold<double>(0, (sum, set) => sum + set.rpe) / sets.length;
    final fatigueIntensity = totalSets * (avgRPE / 10) * 25; // Increased base fatigue per workout
    
    // Apply fatigue to specific muscle groups
    if (exerciseLower.contains('squat') || exerciseLower.contains('lunges')) {
      newFatigue['Legs'] = (newFatigue['Legs']! + fatigueIntensity * 0.8).clamp(0.0, 100.0);
      newFatigue['Back'] = (newFatigue['Back']! + fatigueIntensity * 0.2).clamp(0.0, 100.0);
    } else if (exerciseLower.contains('deadlift')) {
      newFatigue['Back'] = (newFatigue['Back']! + fatigueIntensity * 0.6).clamp(0.0, 100.0);
      newFatigue['Legs'] = (newFatigue['Legs']! + fatigueIntensity * 0.4).clamp(0.0, 100.0);
    } else if (exerciseLower.contains('bench') || exerciseLower.contains('push')) {
      newFatigue['Chest'] = (newFatigue['Chest']! + fatigueIntensity * 0.7).clamp(0.0, 100.0);
      newFatigue['Shoulders'] = (newFatigue['Shoulders']! + fatigueIntensity * 0.2).clamp(0.0, 100.0);
      newFatigue['Arms'] = (newFatigue['Arms']! + fatigueIntensity * 0.1).clamp(0.0, 100.0);
    } else if (exerciseLower.contains('pull') || exerciseLower.contains('row') || exerciseLower.contains('chin')) {
      newFatigue['Back'] = (newFatigue['Back']! + fatigueIntensity * 0.7).clamp(0.0, 100.0);
      newFatigue['Arms'] = (newFatigue['Arms']! + fatigueIntensity * 0.3).clamp(0.0, 100.0);
    } else if (exerciseLower.contains('press') && exerciseLower.contains('shoulder')) {
      newFatigue['Shoulders'] = (newFatigue['Shoulders']! + fatigueIntensity * 0.8).clamp(0.0, 100.0);
      newFatigue['Arms'] = (newFatigue['Arms']! + fatigueIntensity * 0.2).clamp(0.0, 100.0);
    } else if (exerciseLower.contains('curl')) {
      newFatigue['Arms'] = (newFatigue['Arms']! + fatigueIntensity * 0.9).clamp(0.0, 100.0);
    } else if (exerciseLower.contains('extension') || exerciseLower.contains('tricep')) {
      newFatigue['Arms'] = (newFatigue['Arms']! + fatigueIntensity * 0.8).clamp(0.0, 100.0);
    } else if (exerciseLower.contains('leg') || exerciseLower.contains('calf')) {
      newFatigue['Legs'] = (newFatigue['Legs']! + fatigueIntensity * 0.9).clamp(0.0, 100.0);
    } else if (exerciseLower.contains('dip')) {
      newFatigue['Chest'] = (newFatigue['Chest']! + fatigueIntensity * 0.5).clamp(0.0, 100.0);
      newFatigue['Shoulders'] = (newFatigue['Shoulders']! + fatigueIntensity * 0.3).clamp(0.0, 100.0);
      newFatigue['Arms'] = (newFatigue['Arms']! + fatigueIntensity * 0.2).clamp(0.0, 100.0);
    }
    
    // Update states based on new fatigue levels (80% threshold for fatigued)
    for (final entry in newFatigue.entries) {
      final fatigueLevel = entry.value;
      if (fatigueLevel >= 80) {
        newStates[entry.key] = MuscleGroupState.fatigued;
      } else if (fatigueLevel >= 40) {
        newStates[entry.key] = MuscleGroupState.warm;
      } else {
        newStates[entry.key] = MuscleGroupState.ready;
      }
    }
    
    print('DEBUG: Post-workout fatigue: ${newFatigue.map((k, v) => MapEntry(k, v.toStringAsFixed(0)))}');
    print('DEBUG: Muscle states: ${newStates.map((k, v) => MapEntry(k, v.name))}');
    
    return {
      'fatigue': newFatigue,
      'states': newStates,
    };
  }
}

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(const Locale('en'));

  void setLanguage(String languageCode) {
    state = Locale(languageCode);
  }
}

// Localization helper
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String get welcome => locale.languageCode == 'ja' ? 'CycleAvatarへようこそ！' : 'Welcome to CycleAvatar!';
  String get todaysRecommendation => locale.languageCode == 'ja' ? '今日のおすすめ' : 'Today\'s Recommendation';
  String get readyToTrain => locale.languageCode == 'ja' ? 'トレーニング準備完了！すべての筋肉群が回復しました。' : 'Ready to train! All muscle groups have recovered.';
  String get muscleGroupRecovery => locale.languageCode == 'ja' ? '筋肉群の回復状況' : 'Muscle Group Recovery';
  String get home => locale.languageCode == 'ja' ? 'ホーム' : 'Home';
  String get workout => locale.languageCode == 'ja' ? 'ワークアウト' : 'Workout';
  String get avatar => locale.languageCode == 'ja' ? 'アバター' : 'Avatar';
  String get history => locale.languageCode == 'ja' ? '履歴' : 'History';
  String get settings => locale.languageCode == 'ja' ? '設定' : 'Settings';
  String get startWorkout => locale.languageCode == 'ja' ? 'ワークアウト開始' : 'Start Workout';
  String get endWorkout => locale.languageCode == 'ja' ? 'ワークアウト終了' : 'End Workout';
  String get activeWorkout => locale.languageCode == 'ja' ? 'アクティブワークアウト' : 'Active Workout';
  String get addSet => locale.languageCode == 'ja' ? 'セット追加' : 'Add Set';
  String get setsLogged => locale.languageCode == 'ja' ? 'ログされたセット' : 'Sets Logged';
  String get level => locale.languageCode == 'ja' ? 'レベル' : 'Level';
  String get muscleGroupLevels => locale.languageCode == 'ja' ? '筋肉群レベル' : 'Muscle Group Levels';
  String get language => locale.languageCode == 'ja' ? '言語' : 'Language';
  String get notifications => locale.languageCode == 'ja' ? '通知' : 'Notifications';
  String get accessibility => locale.languageCode == 'ja' ? 'アクセシビリティ' : 'Accessibility';
  String get exportData => locale.languageCode == 'ja' ? 'データエクスポート' : 'Export Data';
  String get english => locale.languageCode == 'ja' ? '英語' : 'English';
  String get japanese => locale.languageCode == 'ja' ? '日本語' : 'Japanese';
  String get chest => locale.languageCode == 'ja' ? '胸' : 'Chest';
  String get back => locale.languageCode == 'ja' ? '背中' : 'Back';
  String get legs => locale.languageCode == 'ja' ? '脚' : 'Legs';
  String get shoulders => locale.languageCode == 'ja' ? '肩' : 'Shoulders';
  String get arms => locale.languageCode == 'ja' ? '腕' : 'Arms';
  String get ready => locale.languageCode == 'ja' ? '準備完了' : 'Ready';
  String get warm => locale.languageCode == 'ja' ? 'ウォーム' : 'Warm';
  String get fatigued => locale.languageCode == 'ja' ? '疲労' : 'Fatigued';
  String get weight => locale.languageCode == 'ja' ? '重量 (kg)' : 'Weight (kg)';
  String get reps => locale.languageCode == 'ja' ? '回数' : 'Reps';
  String get rpe => locale.languageCode == 'ja' ? 'RPE' : 'RPE';
  String get exercise => locale.languageCode == 'ja' ? 'エクササイズ' : 'Exercise';
  String get squat => locale.languageCode == 'ja' ? 'スクワット' : 'Squat';
  String get benchPress => locale.languageCode == 'ja' ? 'ベンチプレス' : 'Bench Press';
  String get deadlift => locale.languageCode == 'ja' ? 'デッドリフト' : 'Deadlift';
  String get overheadPress => locale.languageCode == 'ja' ? 'オーバーヘッドプレス' : 'Overhead Press';
  String get barbellRow => locale.languageCode == 'ja' ? 'バーベルロウ' : 'Barbell Row';
  String get pullUp => locale.languageCode == 'ja' ? 'プルアップ' : 'Pull-up';
  String get dip => locale.languageCode == 'ja' ? 'ディップ' : 'Dip';
  String get lunges => locale.languageCode == 'ja' ? 'ランジ' : 'Lunges';
  String get bicepCurl => locale.languageCode == 'ja' ? 'バイセップカール' : 'Bicep Curl';
  String get tricepExtension => locale.languageCode == 'ja' ? 'トライセップエクステンション' : 'Tricep Extension';
  String get lateralRaise => locale.languageCode == 'ja' ? 'ラテラルレイズ' : 'Lateral Raise';
  String get legPress => locale.languageCode == 'ja' ? 'レッグプレス' : 'Leg Press';
  String get legCurl => locale.languageCode == 'ja' ? 'レッグカール' : 'Leg Curl';
  String get calfRaise => locale.languageCode == 'ja' ? 'カーフレイズ' : 'Calf Raise';
  String get plank => locale.languageCode == 'ja' ? 'プランク' : 'Plank';
  String get pushUp => locale.languageCode == 'ja' ? 'プッシュアップ' : 'Push-up';
  String get chinUp => locale.languageCode == 'ja' ? 'チンアップ' : 'Chin-up';
  String get shoulderPress => locale.languageCode == 'ja' ? 'ショルダープレス' : 'Shoulder Press';
  String get inclineBenchPress => locale.languageCode == 'ja' ? 'インクラインベンチプレス' : 'Incline Bench Press';
  String get declineBenchPress => locale.languageCode == 'ja' ? 'デクラインベンチプレス' : 'Decline Bench Press';
  String get set => locale.languageCode == 'ja' ? 'セット' : 'Set';
  String get ago => locale.languageCode == 'ja' ? '前' : 'ago';
  String get minutes => locale.languageCode == 'ja' ? '分' : 'm';
  String get exercises => locale.languageCode == 'ja' ? 'エクササイズ' : 'exercises';
  String get sets => locale.languageCode == 'ja' ? 'セット' : 'sets';
  String get volume => locale.languageCode == 'ja' ? 'ボリューム' : 'volume';
  String get today => locale.languageCode == 'ja' ? '今日' : 'Today';
  String get daysAgo => locale.languageCode == 'ja' ? '日前' : 'days ago';
  String get recoveryAlerts => locale.languageCode == 'ja' ? '回復アラート、PR祝福' : 'Recovery alerts, PR celebrations';
  String get screenReaderVoiceInput => locale.languageCode == 'ja' ? 'スクリーンリーダー、音声入力' : 'Screen reader, voice input';
  String get downloadTrainingData => locale.languageCode == 'ja' ? 'トレーニングデータをダウンロード' : 'Download your training data';
  String get templates => locale.languageCode == 'ja' ? 'テンプレート' : 'Templates';
  String get clearTemplate => locale.languageCode == 'ja' ? 'テンプレートをクリア' : 'Clear Template';
  String get template => locale.languageCode == 'ja' ? 'テンプレート' : 'Template';
  String get pushDay => locale.languageCode == 'ja' ? 'プッシュデー' : 'Push Day';
  String get pullDay => locale.languageCode == 'ja' ? 'プルデー' : 'Pull Day';
  String get legDay => locale.languageCode == 'ja' ? 'レッグデー' : 'Leg Day';
  
  // Exercise list helper
  List<String> get exerciseList => [
    squat, benchPress, deadlift, overheadPress, barbellRow, pullUp, dip, lunges,
    bicepCurl, tricepExtension, lateralRaise, legPress, legCurl, calfRaise,
    plank, pushUp, chinUp, shoulderPress, inclineBenchPress, declineBenchPress,
  ];
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ja'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

void main() {
  runApp(const ProviderScope(child: SimpleCycleAvatarApp()));
}

class SimpleCycleAvatarApp extends ConsumerWidget {
  const SimpleCycleAvatarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    
    return MaterialApp(
      title: 'CycleAvatar - Simple Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ja'),
      ],
      home: const SimpleHomePage(),
    );
  }
}

class SimpleHomePage extends ConsumerStatefulWidget {
  const SimpleHomePage({super.key});

  @override
  ConsumerState<SimpleHomePage> createState() => _SimpleHomePageState();
}

class _SimpleHomePageState extends ConsumerState<SimpleHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    final List<Widget> pages = [
      const HomeTab(),
      const WorkoutTab(),
      const AvatarTab(),
      const HistoryTab(),
      const SettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CycleAvatar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: l10n.home),
          BottomNavigationBarItem(icon: const Icon(Icons.fitness_center), label: l10n.workout),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: l10n.avatar),
          BottomNavigationBarItem(icon: const Icon(Icons.history), label: l10n.history),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: l10n.settings),
        ],
      ),
    );
  }
}

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  String _getStatusText(MuscleGroupState state, AppLocalizations l10n) {
    switch (state) {
      case MuscleGroupState.ready:
        return l10n.ready;
      case MuscleGroupState.warm:
        return l10n.warm;
      case MuscleGroupState.fatigued:
        return l10n.fatigued;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workoutData = ref.watch(workoutDataProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.welcome,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.todaysRecommendation,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.readyToTrain),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // アニメアバター表示カード
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Your Avatar',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  // アニメアバターウィジェット
                  SizedBox(
                    height: 200,
                    child: AnimeAvatarWidget(
                      recoveryStates: ref.read(workoutDataProvider.notifier).getRecoveryStatesForAvatar(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Level ${workoutData.avatarLevel.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.muscleGroupRecovery,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      MuscleGroupIndicator(
                        name: l10n.chest, 
                        status: _getStatusText(workoutData.muscleGroupStates['Chest']!, l10n),
                        fatigueLevel: workoutData.muscleGroupFatigue['Chest']!,
                      ),
                      MuscleGroupIndicator(
                        name: l10n.back, 
                        status: _getStatusText(workoutData.muscleGroupStates['Back']!, l10n),
                        fatigueLevel: workoutData.muscleGroupFatigue['Back']!,
                      ),
                      MuscleGroupIndicator(
                        name: l10n.legs, 
                        status: _getStatusText(workoutData.muscleGroupStates['Legs']!, l10n),
                        fatigueLevel: workoutData.muscleGroupFatigue['Legs']!,
                      ),
                      MuscleGroupIndicator(
                        name: l10n.arms, 
                        status: _getStatusText(workoutData.muscleGroupStates['Arms']!, l10n),
                        fatigueLevel: workoutData.muscleGroupFatigue['Arms']!,
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

class MuscleGroupIndicator extends StatelessWidget {
  final String name;
  final String status;
  final double fatigueLevel;

  const MuscleGroupIndicator({
    super.key,
    required this.name,
    required this.status,
    required this.fatigueLevel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // Color based on fatigue level directly
    Color color;
    if (fatigueLevel >= 80) {
      color = Colors.red; // Fatigued
    } else if (fatigueLevel >= 40) {
      color = Colors.orange; // Warm
    } else {
      color = Colors.green; // Ready
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: fatigueLevel / 100,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 3,
              ),
            ),
            Icon(Icons.fitness_center, color: color, size: 20),
          ],
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 12)),
        Text(status, style: TextStyle(fontSize: 10, color: color)),
        Text('${fatigueLevel.toInt()}%', style: TextStyle(fontSize: 8, color: Colors.grey[600])),
      ],
    );
  }
}

class WorkoutTab extends ConsumerStatefulWidget {
  const WorkoutTab({super.key});

  @override
  ConsumerState<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends ConsumerState<WorkoutTab> {
  bool _isWorkoutActive = false;
  final List<WorkoutSet> _currentSets = [];
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _rpeController = TextEditingController();
  String _selectedExercise = 'Squat';
  WorkoutTemplate? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _loadPreviousValues();
  }

  void _loadPreviousValues() {
    final workoutData = ref.read(workoutDataProvider);
    final previousSessions = workoutData.sessions
        .where((session) => session.name == _selectedExercise)
        .toList();
    
    if (previousSessions.isNotEmpty) {
      final lastSession = previousSessions.last;
      if (lastSession.sets.isNotEmpty) {
        final lastSet = lastSession.sets.last;
        _weightController.text = lastSet.weight.toString();
        _repsController.text = lastSet.reps.toString();
        _rpeController.text = lastSet.rpe.toString();
      }
    }
  }

  void _onExerciseChanged(String? newExercise) {
    if (newExercise != null) {
      setState(() {
        _selectedExercise = newExercise;
      });
      if (_selectedTemplate != null) {
        _loadTemplateValues();
      } else {
        _loadPreviousValues();
      }
    }
  }

  void _loadTemplateValues() {
    if (_selectedTemplate != null && _selectedTemplate!.suggestedSets.containsKey(_selectedExercise)) {
      final suggestedSets = _selectedTemplate!.suggestedSets[_selectedExercise]!;
      if (suggestedSets.isNotEmpty) {
        final firstSet = suggestedSets.first;
        _weightController.text = firstSet.weight.toString();
        _repsController.text = firstSet.reps.toString();
        _rpeController.text = firstSet.rpe.toString();
      }
    }
  }

  String _getLocalizedExerciseName(String exerciseName, AppLocalizations l10n) {
    switch (exerciseName) {
      case 'Squat': return l10n.squat;
      case 'Bench Press': return l10n.benchPress;
      case 'Deadlift': return l10n.deadlift;
      case 'Overhead Press': return l10n.overheadPress;
      case 'Barbell Row': return l10n.barbellRow;
      case 'Pull-up': return l10n.pullUp;
      case 'Dip': return l10n.dip;
      case 'Lunges': return l10n.lunges;
      case 'Bicep Curl': return l10n.bicepCurl;
      case 'Tricep Extension': return l10n.tricepExtension;
      case 'Lateral Raise': return l10n.lateralRaise;
      case 'Leg Press': return l10n.legPress;
      case 'Leg Curl': return l10n.legCurl;
      case 'Calf Raise': return l10n.calfRaise;
      case 'Plank': return l10n.plank;
      case 'Push-up': return l10n.pushUp;
      case 'Chin-up': return l10n.chinUp;
      case 'Shoulder Press': return l10n.shoulderPress;
      case 'Incline Bench Press': return l10n.inclineBenchPress;
      case 'Decline Bench Press': return l10n.declineBenchPress;
      default: return exerciseName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exerciseOptions = _selectedTemplate?.exercises ?? [
      'Squat', 'Bench Press', 'Deadlift', 'Overhead Press', 'Barbell Row',
      'Pull-up', 'Dip', 'Lunges', 'Bicep Curl', 'Tricep Extension',
      'Lateral Raise', 'Leg Press', 'Leg Curl', 'Calf Raise', 'Plank',
      'Push-up', 'Chin-up', 'Shoulder Press', 'Incline Bench Press', 'Decline Bench Press',
    ];
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.workout,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (!_isWorkoutActive) ...[
            // Template selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.templates,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, child) {
                        final workoutData = ref.watch(workoutDataProvider);
                        return Wrap(
                          spacing: 8,
                          children: workoutData.templates.map((template) {
                            return ActionChip(
                              label: Text(template.name),
                              onPressed: () {
                                setState(() {
                                  _selectedTemplate = template;
                                  _selectedExercise = template.exercises.first;
                                  _isWorkoutActive = true;
                                });
                                _loadTemplateValues();
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _isWorkoutActive = true),
              child: Text(l10n.startWorkout),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.activeWorkout,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            if (_selectedTemplate != null)
                              Text(
                                '${l10n.template}: ${_selectedTemplate!.name}',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            if (_selectedTemplate != null)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTemplate = null;
                                  });
                                },
                                child: Text(l10n.clearTemplate),
                              ),
                            ElevatedButton(
                              onPressed: () {
                                if (_currentSets.isNotEmpty) {
                                  // Save workout session
                                  ref.read(workoutDataProvider.notifier).addWorkoutSession(
                                    _getLocalizedExerciseName(_selectedExercise, l10n),
                                    _currentSets,
                                  );
                                }
                                setState(() {
                                  _isWorkoutActive = false;
                                  _currentSets.clear();
                                  _selectedTemplate = null;
                                });
                              },
                              child: Text(l10n.endWorkout),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('${l10n.exercise}: '),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _selectedExercise,
                            isExpanded: true,
                            items: exerciseOptions.map((String exercise) {
                              return DropdownMenuItem<String>(
                                value: exercise,
                                child: Text(_getLocalizedExerciseName(exercise, l10n)),
                              );
                            }).toList(),
                            onChanged: _onExerciseChanged,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Previous values display
                    Consumer(
                      builder: (context, ref, child) {
                        final workoutData = ref.watch(workoutDataProvider);
                        final previousSessions = workoutData.sessions
                            .where((session) => session.name == _getLocalizedExerciseName(_selectedExercise, l10n))
                            .toList();
                        
                        if (previousSessions.isNotEmpty) {
                          final lastSession = previousSessions.last;
                          if (lastSession.sets.isNotEmpty) {
                            final lastSet = lastSession.sets.last;
                            final daysSince = DateTime.now().difference(lastSession.date).inDays;
                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                'Last: ${lastSet.weight}kg × ${lastSet.reps} @ RPE ${lastSet.rpe} (${daysSince == 0 ? l10n.today : '$daysSince ${l10n.daysAgo}'})',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            decoration: InputDecoration(
                              labelText: l10n.weight,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _repsController,
                            decoration: InputDecoration(
                              labelText: l10n.reps,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _rpeController,
                            decoration: InputDecoration(
                              labelText: l10n.rpe,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        final weight = double.tryParse(_weightController.text) ?? 100;
                        final reps = int.tryParse(_repsController.text) ?? 8;
                        final rpe = int.tryParse(_rpeController.text) ?? 7;
                        
                        setState(() {
                          _currentSets.add(WorkoutSet(
                            weight: weight,
                            reps: reps,
                            rpe: rpe,
                            time: DateTime.now(),
                          ));
                        });
                        
                        // Clear inputs and reload previous values for next set
                        _weightController.clear();
                        _repsController.clear();
                        _rpeController.clear();
                        
                        // Set suggested values for next set (slightly progressive)
                        if (_currentSets.isNotEmpty) {
                          final lastSet = _currentSets.last;
                          _weightController.text = lastSet.weight.toString();
                          _repsController.text = lastSet.reps.toString();
                          _rpeController.text = lastSet.rpe.toString();
                        }
                      },
                      child: Text(l10n.addSet),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_currentSets.isNotEmpty) ...[
              Text(
                l10n.setsLogged,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _currentSets.length,
                  itemBuilder: (context, index) {
                    final set = _currentSets[index];
                    return Card(
                      child: ListTile(
                        title: Text('${l10n.set} ${index + 1}'),
                        subtitle: Text('${set.weight}kg × ${set.reps} @ RPE ${set.rpe}'),
                        trailing: Text('${DateTime.now().difference(set.time).inMinutes}${l10n.minutes} ${l10n.ago}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class AvatarTab extends ConsumerWidget {
  const AvatarTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workoutData = ref.watch(workoutDataProvider);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.avatar,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  '${l10n.level} ${workoutData.avatarLevel.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text('${(workoutData.avatarLevel * 100).toInt()} / ${((workoutData.avatarLevel.floor() + 1) * 100).toInt()} XP'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: workoutData.avatarLevel % 1,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.muscleGroupLevels,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...workoutData.muscleGroupLevels.entries.map((entry) {
            final localizedName = _getLocalizedMuscleGroupName(entry.key, l10n);
            return MuscleGroupLevel(name: localizedName, level: entry.value);
          }).toList(),
        ],
      ),
    );
  }

  String _getLocalizedMuscleGroupName(String key, AppLocalizations l10n) {
    switch (key) {
      case 'Chest': return l10n.chest;
      case 'Back': return l10n.back;
      case 'Legs': return l10n.legs;
      case 'Shoulders': return l10n.shoulders;
      case 'Arms': return l10n.arms;
      default: return key;
    }
  }
}

class MuscleGroupLevel extends StatelessWidget {
  final String name;
  final double level;

  const MuscleGroupLevel({
    super.key,
    required this.name,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(name),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: (level % 1),
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
          const SizedBox(width: 8),
          Text('Lv ${level.toStringAsFixed(1)}'),
        ],
      ),
    );
  }
}

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workoutData = ref.watch(workoutDataProvider);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.history,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (workoutData.sessions.isEmpty) ...[
            const Center(
              child: Text('No workouts yet. Start your first workout!'),
            ),
          ] else ...[
            Expanded(
              child: ListView.builder(
                itemCount: workoutData.sessions.length,
                itemBuilder: (context, index) {
                  final session = workoutData.sessions.reversed.toList()[index];
                  final daysDiff = DateTime.now().difference(session.date).inDays;
                  final timeText = daysDiff == 0 
                      ? l10n.today 
                      : '$daysDiff ${l10n.daysAgo}';
                  
                  // Calculate additional metrics
                  final avgRPE = session.sets.isNotEmpty 
                      ? session.sets.fold<double>(0, (sum, set) => sum + set.rpe) / session.sets.length
                      : 0.0;
                  final maxWeight = session.sets.isNotEmpty
                      ? session.sets.map((set) => set.weight).reduce((a, b) => a > b ? a : b)
                      : 0.0;
                  
                  return Card(
                    child: ListTile(
                      title: Text(session.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${session.sets.length} ${l10n.sets} • ${session.volume.toStringAsFixed(0)}kg ${l10n.volume}'),
                          Text(
                            'Max: ${maxWeight.toStringAsFixed(1)}kg • Avg RPE: ${avgRPE.toStringAsFixed(1)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      trailing: Text(timeText),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(languageProvider);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settings,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              subtitle: Text(currentLocale.languageCode == 'ja' ? l10n.japanese : l10n.english),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.language),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text(l10n.english),
                          leading: Radio<String>(
                            value: 'en',
                            groupValue: currentLocale.languageCode,
                            onChanged: (value) {
                              if (value != null) {
                                ref.read(languageProvider.notifier).setLanguage(value);
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                        ListTile(
                          title: Text(l10n.japanese),
                          leading: Radio<String>(
                            value: 'ja',
                            groupValue: currentLocale.languageCode,
                            onChanged: (value) {
                              if (value != null) {
                                ref.read(languageProvider.notifier).setLanguage(value);
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(l10n.notifications),
              subtitle: Text(l10n.recoveryAlerts),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.accessibility),
              title: Text(l10n.accessibility),
              subtitle: Text(l10n.screenReaderVoiceInput),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download),
              title: Text(l10n.exportData),
              subtitle: Text(l10n.downloadTrainingData),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }
}