# 🎯 Daily Challenge - Pure Dart Edition

A beautiful, portable habit-tracking and daily challenge application built with Flutter. This project is a **Pure Dart** implementation, meaning it has zero native plugin dependencies, making it extremely lightweight and compatible with all platforms (Web, Windows, macOS, Linux, iOS, Android) without any system-level configuration.

## ✨ Features

- **Daily Challenges:** Automatically generates a new challenge every day to keep you motivated.
- **Random Discovery:** Feeling adventurous? Shuffle to find a new challenge instantly.
- **In-Memory Persistence:** Fast, lightweight state management that persists throughout your session.
- **Progress Tracking:** Interactive tap-to-log progress system with visual indicators.
- **XP & Leveling:** Earn experience points for every completed task and track your growth.
- **Premium UI/UX:**
  - Modern, minimalist design using the **Inter** typeface.
  - Smooth micro-animations powered by **flutter_animate**.
  - Dynamic color palettes for different challenge categories.
  - Glassmorphic elements and clean shadows.

## 🛠 Tech Stack

- **Core:** Flutter (Pure Dart Architecture)
- **Styling:** Custom Design System (Vanilla CSS principles in Flutter)
- **Typography:** Google Fonts (Inter)
- **Animations:** Flutter Animate
- **Utility:** UUID, Intl, Percent Indicator

## 🚀 Getting Started

Since this is a Pure Dart project, you don't need to worry about symlinks or platform-specific settings.

1. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run the App:**
   ```bash
   flutter run
   ```

## 📂 Project Structure

To maintain maximum simplicity and readability, the entire app is consolidated into a single, well-documented file:
- `lib/main.dart`: Contains Models, Services, UI Components, and all Screens.

## 🧪 Testing

A smoke test is included in `test/widget_test.dart` to verify the application lifecycle.

```bash
flutter test
```

