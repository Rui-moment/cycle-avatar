"""
FatigueModel: A muscle fatigue calculation system for a fitness tracking app.

Implements:
- Training volume load and intensity-based fatigue accumulation per exercise
- Distribution of fatigue to muscle groups by exercise mapping
- Exponential recovery (time decay) per muscle group with configurable half-lives
- Normalization to daily fatigue cap and capping at 100%

Python 3.10+
"""
from __future__ import annotations

from dataclasses import dataclass, field
from math import exp, log
from typing import Dict, Mapping, Optional


# ------------------------------
# Constants and defaults
# ------------------------------
DAILY_FATIGUE_CAP: float = 10_000.0  # normalization cap (units of raw fatigue)
LN2: float = log(2.0)

# Default half-life (in hours) per muscle group.
# Large: legs, chest, back (and lats) ~42h (range 36–48)
# Small: shoulders, arms (biceps/triceps/forearms), calves ~24h
# Core is not specified; we set an intermediate default of 30h.
DEFAULT_HALF_LIVES: Dict[str, float] = {
    "legs": 42.0,
    "chest": 42.0,
    "back": 42.0,
    "lats": 42.0,
    "shoulders": 24.0,
    "arms": 24.0,
    "biceps": 24.0,
    "triceps": 24.0,
    "forearms": 24.0,
    "calves": 24.0,
    "core": 30.0,
}

# Exercise library: per-exercise muscle distribution and base coefficient.
# Coefficient ranges:
# - Compound lifts (squat, deadlift, bench, overhead press) ~ 1.5–2.0
# - Isolation (calf raise, curls, etc.) ~ 0.5–0.8
EXERCISE_LIBRARY: Dict[str, Dict[str, object]] = {
    # Bench Press
    "bench_press": {
        "distribution": {"chest": 0.5, "triceps": 0.3, "shoulders": 0.2},
        "coefficient": 1.7,
    },
    # Overhead Press (OHP)
    "overhead_press": {
        "distribution": {"shoulders": 0.6, "triceps": 0.3, "chest": 0.1},
        "coefficient": 1.6,
    },
    # Dips
    "dips": {
        "distribution": {"chest": 0.4, "triceps": 0.4, "shoulders": 0.2},
        "coefficient": 1.4,
    },
    # Deadlift
    "deadlift": {
        "distribution": {"back": 0.5, "legs": 0.4, "forearms": 0.1},
        "coefficient": 1.9,
    },
    # Barbell Row
    "barbell_row": {
        "distribution": {"back": 0.6, "biceps": 0.3, "forearms": 0.1},
        "coefficient": 1.5,
    },
    # Pull-up
    "pull_up": {
        "distribution": {"lats": 0.5, "biceps": 0.4, "forearms": 0.1},
        "coefficient": 1.5,
    },
    # Squat
    "squat": {
        "distribution": {"legs": 0.7, "back": 0.2, "core": 0.1},
        "coefficient": 1.9,
    },
    # Lunge
    "lunge": {
        "distribution": {"legs": 0.8, "core": 0.2},
        "coefficient": 1.2,
    },
    # Calf Raise
    "calf_raise": {
        "distribution": {"calves": 1.0},
        "coefficient": 0.6,
    },
}


@dataclass
class FatigueModel:
    """Muscle fatigue model with accumulation and exponential recovery.

    Internal state stores fatigue in percentage (0–100) for each muscle group.
    New workouts add fatigue based on volume-load and intensity, distributed across muscle groups.
    Recovery decays existing fatigue exponentially based on muscle-specific half-lives.

    Attributes:
        half_lives: per-group half-life in hours; defaults provided can be overridden.
        fatigue: current fatigue percentage per group (0–100).
    """

    half_lives: Dict[str, float] = field(default_factory=lambda: DEFAULT_HALF_LIVES.copy())
    fatigue: Dict[str, float] = field(default_factory=dict)

    # ------------------------------
    # Public API
    # ------------------------------
    def add_workout(
        self,
        *,
        weight: float,
        reps: int,
        sets: int,
        exercise_type: str,
        one_rm: Optional[float] = None,
        coefficient: Optional[float] = None,
        distribution: Optional[Mapping[str, float]] = None,
    ) -> Dict[str, float]:
        """Add a workout and update per-group fatigue.

        Args:
            weight: working weight in kg.
            reps: repetitions per set (integer).
            sets: number of sets (integer).
            exercise_type: canonical key (e.g., 'bench_press', 'deadlift').
            one_rm: estimated 1RM (kg). If None, computed by Epley: 1RM = w * (1 + reps/30).
            coefficient: optional override for exercise coefficient.
            distribution: optional override for muscle group distribution (must sum to 1.0).

        Returns:
            Updated fatigue dictionary (percentages 0–100) per muscle group.
        """
        self._validate_positive(weight, "weight")
        self._validate_positive_int(reps, "reps")
        self._validate_positive_int(sets, "sets")

        # Resolve exercise mapping
        lib = EXERCISE_LIBRARY.get(exercise_type, None)
        base_dist: Mapping[str, float]
        base_coeff: float
        if lib is None:
            # Fallback if unknown: treat as generic isolation to 'arms' if not provided
            base_dist = {"arms": 1.0}
            base_coeff = 0.7
        else:
            base_dist = lib["distribution"]  # type: ignore[index]
            base_coeff = float(lib["coefficient"])  # type: ignore[index]

        dist = dict(distribution) if distribution is not None else dict(base_dist)
        self._normalize_distribution(dist)
        coeff = float(coefficient) if coefficient is not None else base_coeff

        # Core calculations
        # Volume Load (VL)
        vl = float(weight) * float(reps) * float(sets)
        # 1RM (Epley) if not given. Safeguard reps for formula use.
        rm = float(one_rm) if one_rm is not None else float(weight) * (1.0 + float(reps) / 30.0)
        # Intensity Factor (IF)
        if rm <= 0:
            raise ValueError("1RM must be > 0 after estimation")
        intensity_factor = float(weight) / rm
        # Fatigue Score (raw units before normalization)
        fatigue_score = vl * intensity_factor * coeff

        # Distribute to muscle groups and update percentages
        for group, pct in dist.items():
            added_raw = fatigue_score * pct
            added_percent = (added_raw / DAILY_FATIGUE_CAP) * 100.0
            current = self.fatigue.get(group, 0.0)
            new_value = min(100.0, max(0.0, current + added_percent))
            self.fatigue[group] = new_value

        return self.get_fatigue()

    def decay_fatigue(self, hours: float) -> Dict[str, float]:
        """Apply exponential decay (recovery) over a time interval in hours.

        fatigue(t) = fatigue_initial * exp(-λ * Δt),  λ = ln(2) / half_life

        Args:
            hours: elapsed time in hours (>= 0)

        Returns:
            Updated fatigue dictionary after decay.
        """
        if hours < 0:
            raise ValueError("hours must be >= 0")

        for group, value in list(self.fatigue.items()):
            hl = self._resolve_half_life(group)
            lam = LN2 / hl  # decay constant
            decayed = value * exp(-lam * hours)
            # Clean small values to 0
            self.fatigue[group] = 0.0 if decayed < 0.01 else decayed
        return self.get_fatigue()

    def get_fatigue(self) -> Dict[str, float]:
        """Get current fatigue percentages per muscle group (0–100), rounded to 1 decimal.

        Returns:
            Copy of internal fatigue state.
        """
        return {k: round(min(100.0, max(0.0, v)), 1) for k, v in self.fatigue.items()}

    # ------------------------------
    # Helpers
    # ------------------------------
    def _resolve_half_life(self, group: str) -> float:
        # Map synonyms if necessary (e.g., biceps/triceps->arms if not specified)
        if group not in self.half_lives:
            if group in ("biceps", "triceps", "forearms"):
                return self.half_lives.get("arms", 24.0)
            if group == "lats":
                return self.half_lives.get("back", 42.0)
        return self.half_lives.get(group, 30.0)

    @staticmethod
    def _validate_positive(val: float, name: str) -> None:
        if not isinstance(val, (int, float)) or val <= 0:
            raise ValueError(f"{name} must be > 0")

    @staticmethod
    def _validate_positive_int(val: int, name: str) -> None:
        if not isinstance(val, int) or val <= 0:
            raise ValueError(f"{name} must be positive int")

    @staticmethod
    def _normalize_distribution(dist: Dict[str, float]) -> None:
        total = float(sum(dist.values()))
        if total <= 0:
            raise ValueError("distribution must have positive sum")
        # Normalize exactly to sum 1.0
        for k in list(dist.keys()):
            dist[k] = float(dist[k]) / total


if __name__ == "__main__":
    # Example usage
    model = FatigueModel()

    # Add a bench press session (e.g., 80kg x 8 reps x 4 sets)
    model.add_workout(weight=80, reps=8, sets=4, exercise_type="bench_press")
    print("After bench press:", model.get_fatigue())

    # Decay 24 hours
    model.decay_fatigue(24)
    print("After 24h decay:", model.get_fatigue())

    # Add squat session (120kg x 5 x 5), custom 1RM provided
    model.add_workout(weight=120, reps=5, sets=5, exercise_type="squat", one_rm=180)
    print("After squat:", model.get_fatigue())

