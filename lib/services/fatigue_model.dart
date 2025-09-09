import 'dart:math' as math;

import '../main.dart';

class FatigueService {
  // Normalization cap to convert raw fatigue score into % per day
  static const double dailyCap = 10000.0;
  // Global multiplier to make accumulation feel faster (tuning knob)
  static const double accumulationBias = 1.5; // 1.0 = baseline, >1.0 accumulates faster
  static const double ln2 = 0.6931471805599453;

  // Half-life (hours) for the 5 groups the UI tracks
  // Large muscles ~42h, small ~24h
  static const Map<String, double> halfLivesHours = {
    'Legs': 42.0,
    'Chest': 42.0,
    'Back': 42.0,
    'Shoulders': 24.0,
    'Arms': 24.0,
  };

  // Exercise library (distribution + coefficient)
  static const Map<String, Map<String, dynamic>> exerciseLib = {
    'bench_press': {
      'distribution': {'chest': 0.5, 'triceps': 0.3, 'shoulders': 0.2},
      'coefficient': 1.7,
    },
    'overhead_press': {
      'distribution': {'shoulders': 0.6, 'triceps': 0.3, 'chest': 0.1},
      'coefficient': 1.6,
    },
    'dips': {
      'distribution': {'chest': 0.4, 'triceps': 0.4, 'shoulders': 0.2},
      'coefficient': 1.4,
    },
    'deadlift': {
      'distribution': {'back': 0.5, 'legs': 0.4, 'forearms': 0.1},
      'coefficient': 1.9,
    },
    'barbell_row': {
      'distribution': {'back': 0.6, 'biceps': 0.3, 'forearms': 0.1},
      'coefficient': 1.5,
    },
    'pull_up': {
      'distribution': {'lats': 0.5, 'biceps': 0.4, 'forearms': 0.1},
      'coefficient': 1.5,
    },
    'squat': {
      'distribution': {'legs': 0.7, 'back': 0.2, 'core': 0.1},
      'coefficient': 1.9,
    },
    'lunge': {
      'distribution': {'legs': 0.8, 'core': 0.2},
      'coefficient': 1.2,
    },
    'calf_raise': {
      'distribution': {'calves': 1.0},
      'coefficient': 0.6,
    },
  };

  // Canonicalize exercise name from English/Japanese labels
  static String canonicalize(String name) {
    final n = name.trim().toLowerCase();
    if (n.contains('bench')) return 'bench_press';
    if (n.contains('overhead') || (n.contains('shoulder') && n.contains('press'))) return 'overhead_press';
    if (n.contains('dip')) return 'dips';
    if (n.contains('deadlift') || n.contains('dead lift')) return 'deadlift';
    if (n.contains('row')) return 'barbell_row';
    if (n.contains('pull') || n.contains('chin')) return 'pull_up';
    if (n.contains('squat')) return 'squat';
    if (n.contains('lunge')) return 'lunge';
    if (n.contains('calf')) return 'calf_raise';
    // Japanese common names
    if (n.contains('ベンチ')) return 'bench_press';
    if (n.contains('オーバーヘッド') || n.contains('ショルダープレス')) return 'overhead_press';
    if (n.contains('ディップ')) return 'dips';
    if (n.contains('デッド')) return 'deadlift';
    if (n.contains('ロウ') || n.contains('ロー')) return 'barbell_row';
    if (n.contains('プル') || n.contains('懸垂') || n.contains('チン')) return 'pull_up';
    if (n.contains('スクワット')) return 'squat';
    if (n.contains('ランジ')) return 'lunge';
    if (n.contains('カーフ')) return 'calf_raise';
    return 'generic_isolation';
  }

  static Map<String, double> _distToFive(Map<String, double> dist) {
    // Map detailed groups to 5 groups
    final Map<String, double> out = {
      'Chest': 0,
      'Back': 0,
      'Legs': 0,
      'Shoulders': 0,
      'Arms': 0,
    };
    dist.forEach((k, v) {
      switch (k) {
        case 'chest':
          out['Chest'] = (out['Chest']! + v);
          break;
        case 'back':
        case 'lats':
        case 'core': // aggregate core into Back for now
          out['Back'] = (out['Back']! + v);
          break;
        case 'legs':
        case 'calves': // aggregate calves into Legs
          out['Legs'] = (out['Legs']! + v);
          break;
        case 'shoulders':
          out['Shoulders'] = (out['Shoulders']! + v);
          break;
        case 'biceps':
        case 'triceps':
        case 'forearms':
        default:
          out['Arms'] = (out['Arms']! + v);
      }
    });
    final total = out.values.fold<double>(0, (s, x) => s + x);
    if (total <= 0) {
      out['Arms'] = 1.0; // default all to Arms
      return out;
    }
    // Normalize to sum 1.0
    out.updateAll((key, value) => value / total);
    return out;
  }

  // Compute fatigue delta (%) per 5 groups from a list of sets for an exercise name
  static Map<String, double> computeFatigueDelta(String exerciseName, List<WorkoutSet> sets) {
    if (sets.isEmpty) {
      return {'Chest': 0, 'Back': 0, 'Legs': 0, 'Shoulders': 0, 'Arms': 0};
    }
    final key = canonicalize(exerciseName);
    Map<String, double> dist;
    double coeff;
    if (exerciseLib.containsKey(key)) {
      final m = exerciseLib[key]!;
      dist = (m['distribution'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      coeff = (m['coefficient'] as num).toDouble();
    } else {
      dist = {'arms': 1.0};
      coeff = 0.7;
    }
    final dist5 = _distToFive(dist);

    // Sum fatigue score across sets using Epley-based IF per set
    double totalScore = 0.0;
    for (final s in sets) {
      final w = s.weight;
      final r = s.reps;
      if (w <= 0 || r <= 0) continue;
      final vl = w * r; // per set volume
      final oneRm = w * (1.0 + r / 30.0);
      final ifac = w / oneRm; // = 1/(1+r/30)
      totalScore += vl * ifac; // omit multiplying sets: this loop is per set
    }
    totalScore *= coeff;

    // Convert to % and distribute
    final Map<String, double> delta = {};
    dist5.forEach((g, p) {
      final addedRaw = totalScore * p;
      final addedPct = (addedRaw / dailyCap) * 100.0 * accumulationBias;
      delta[g] = addedPct;
    });
    return delta;
  }

  // Apply exponential decay over hours for the 5 groups
  static Map<String, double> decay(Map<String, double> current, double hours) {
    if (hours <= 0) return Map<String, double>.from(current);
    final Map<String, double> out = {};
    current.forEach((g, v) {
      final hl = halfLivesHours[g] ?? 30.0;
      final lam = ln2 / hl;
      final decayed = v * math.exp(-lam * hours);
      out[g] = decayed < 0.01 ? 0.0 : decayed;
    });
    return out;
  }
}
