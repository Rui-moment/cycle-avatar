# CycleAvatar 🏋️‍♂️

**Smart Workout Tracking App with Intelligent Fatigue & Recovery System**

CycleAvatar is a Flutter-based workout tracking application that uses advanced fatigue modeling and recovery algorithms to optimize your training schedule and prevent overtraining.

## ✨ Features

### 🎯 Core Functionality
- **Smart Fatigue Tracking**: Real-time muscle group fatigue calculation based on RPE, volume, and intensity
- **Recovery System**: Automatic recovery tracking with visual indicators (Ready/Warm/Fatigued)
- **Quick Workout Logging**: Fast set entry with RPE tracking and previous value auto-loading
- **Template System**: Pre-built workout templates (Push/Pull/Leg Day) for quick session starts
- **Avatar Progression**: Gamified leveling system based on training consistency and progression

### 📊 Advanced Analytics
- **Muscle Group Status**: Visual fatigue indicators with percentage-based recovery tracking
- **Workout History**: Comprehensive session tracking with volume and intensity metrics
- **Progress Visualization**: Circular progress bars showing real-time recovery status

### 🌍 User Experience
- **Multi-language Support**: English and Japanese localization
- **Responsive Design**: Optimized for mobile devices
- **Accessibility**: Screen reader support and keyboard navigation

## 🚀 Current Status

### ✅ Implemented Features
- [x] Basic workout logging with RPE tracking
- [x] Fatigue calculation system (80% threshold for "Fatigued" status)
- [x] Real-time recovery system (10 points per 30 seconds)
- [x] Template-based workouts
- [x] Multi-language support (EN/JP)
- [x] Avatar leveling system
- [x] Workout history tracking
- [x] Visual fatigue indicators with circular progress bars

### 🔄 In Development
- [ ] Enhanced recovery algorithms with muscle group-specific rates
- [ ] Notification system for recovery alerts
- [ ] Data export functionality
- [ ] Advanced workout analytics
- [ ] Cloud synchronization

## 🏗️ Architecture

### Tech Stack
- **Frontend**: Flutter (Dart)
- **State Management**: Riverpod
- **Local Storage**: SQLite
- **Backend**: FastAPI (Python) - *In Development*
- **Database**: PostgreSQL - *In Development*

### Project Structure
```
lib/
├── core/                 # Core utilities and services
├── data/                 # Data layer (repositories, services)
├── domain/               # Business logic and entities
├── presentation/         # UI layer (pages, widgets, providers)
└── main_simple.dart      # Current simplified implementation
```

## 🔧 Development Setup

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)

### Installation
```bash
# Clone the repository
git clone https://github.com/Rui-moment/cycle-avatar.git
cd cycle-avatar

# Install dependencies
flutter pub get

# Run the app
flutter run lib/main_simple.dart
```

## 📈 Fatigue & Recovery System

### Fatigue Calculation
```
Fatigue Intensity = Sets × (Average RPE ÷ 10) × 25
```

### Recovery Thresholds
- **Ready (Green)**: 0-39% fatigue
- **Warm (Orange)**: 40-79% fatigue  
- **Fatigued (Red)**: 80-100% fatigue

### Recovery Rate
- **Base Recovery**: 10 points per 30 seconds
- **Full Recovery Time**: ~5 minutes (100% → 0%)

## 🎮 Usage Example

1. **Start Workout**: Select a template or create custom workout
2. **Log Sets**: Enter weight, reps, and RPE for each set
3. **Track Fatigue**: Watch real-time fatigue accumulation
4. **Monitor Recovery**: Check muscle group status on home screen
5. **Plan Next Session**: Use recovery indicators to optimize training

## 🤝 Contributing

We welcome contributions! Please see our development workflow:

1. **Main Branch**: Stable releases
2. **Feature Branches**: New development (e.g., `feature/enhanced-recovery-system`)
3. **Pull Requests**: All changes go through PR review

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔮 Roadmap

### Phase 1: Core Enhancement (Current)
- Enhanced recovery algorithms
- Notification system
- Data export/import

### Phase 2: Advanced Features
- Cloud synchronization
- Social features
- Advanced analytics dashboard

### Phase 3: AI Integration
- Personalized training recommendations
- Injury prevention algorithms
- Adaptive recovery modeling

---

**Built with ❤️ for the fitness community**

[Report Issues](https://github.com/Rui-moment/cycle-avatar/issues) | [Feature Requests](https://github.com/Rui-moment/cycle-avatar/discussions)