# 💊 Pilzy - Smart Medication Reminder

*Never miss a dose again.*

<!-- Add a banner image or app logo here -->
![Pilzy Banner](https://via.placeholder.com/800x200/4A90E2/FFFFFF?text=Pilzy+-+Smart+Medication+Reminder)

## 🌟 Overview

**Pilzy** is an intelligent medication reminder app built with Flutter that transforms how you manage your daily medications. With its beautiful glassmorphic design and smart tracking features, Pilzy ensures you stay on top of your health routine effortlessly.

### Why Pilzy?

- **Never forget again**: Reliable local notifications ensure you're always reminded
- **Visual tracking**: Interactive pill strip visualization shows your progress at a glance
- **Smart confirmations**: Prevent accidental dose logging with thoughtful confirmation dialogs
- **Offline-first**: All your data stays private and accessible without internet
- **Beautiful design**: Modern glassmorphic UI that's both functional and elegant

---

## ✨ Key Features

### 📋 Medication Management
- **Add, edit, and delete** medications with ease
- **Custom scheduling** for different dosing frequencies
- **Detailed medication profiles** with names, dosages, and notes

### 🔔 Smart Reminders
- **Local push notifications** that work reliably offline
- **Precise timing** using timezone-aware scheduling
- **Confirmation dialogs** to ensure accurate dose tracking

### 📊 Visual Tracking
- **Interactive pill strips** showing remaining doses
- **Progress visualization** to track adherence
- **Refill indicators** when supplies are running low

### 🎨 Modern Design
- **Glassmorphic UI** for a premium, modern feel
- **Intuitive navigation** designed for daily use
- **Custom animations** and toast notifications for smooth interactions

### 🔒 Privacy & Storage
- **100% offline** - your data never leaves your device
- **Fast local storage** powered by Hive database
- **No account required** - get started immediately

---

## 📱 Screenshots

<!-- Replace with actual screenshots -->
<div align="center">
  <img src="https://via.placeholder.com/250x450/4A90E2/FFFFFF?text=Home+Screen" alt="Home Screen" width="250">
  <img src="https://via.placeholder.com/250x450/4A90E2/FFFFFF?text=Pill+Strip+View" alt="Pill Strip View" width="250">
  <img src="https://via.placeholder.com/250x450/4A90E2/FFFFFF?text=Add+Medication" alt="Add Medication" width="250">
</div>

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| **Framework** | Flutter (Dart) |
| **State Management** | BLoC Pattern |
| **Local Database** | Hive |
| **Notifications** | Flutter Local Notifications |
| **Permissions** | Permission Handler |
| **Scheduling** | Timezone |
| **UI Design** | Custom Glassmorphism with BackdropFilter |

---

## 📦 Getting Started

### Prerequisites

Ensure you have the following installed:

- **Flutter SDK** (≥3.7.2) - [Installation Guide](https://docs.flutter.dev/get-started/install)
- **Android Studio** or **Xcode** (for iOS)
- **Git** for version control
- A physical device or emulator for testing

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/pilzy.git
   cd pilzy
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code (Hive adapters)**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### First Launch Setup

On first launch, Pilzy will:
- Request notification permissions
- Request exact alarm permissions (Android 12+)
- Initialize the local database
- Show you a quick onboarding tour

---

## ⚙️ Configuration

### 🔔 Notifications & Permissions

**Android Requirements:**
- **Notification Permission**: Required for all reminder notifications
- **Exact Alarm Permission**: Required on Android 12+ for precise timing
- **Battery Optimization**: Consider disabling for Pilzy to ensure reliable notifications

**iOS Requirements:**
- **Notification Permission**: Requested automatically on first use
- **Background App Refresh**: Enable for optimal performance

### 🎨 Customization

**App Icon & Splash Screen:**
Customize the app's appearance by modifying these files:
- App icon: Configure in `pubspec.yaml` under `flutter_launcher_icons`
- Splash screen: Configure in `pubspec.yaml` under `flutter_native_splash`

Then run:
```bash
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

---

## 🚀 Roadmap

### Upcoming Features
- [ ] **Enhanced iOS Support** - Improved notification handling for iOS
- [ ] **Time-based Categories** - Morning, afternoon, evening medication grouping
- [ ] **Smart Refill Reminders** - Alerts when pill supplies are running low
- [ ] **Export Functionality** - Download medication history as CSV or PDF
- [ ] **Cloud Backup** - Optional cloud sync for cross-device access
- [ ] **Medication Interactions** - Basic drug interaction warnings
- [ ] **Adherence Analytics** - Detailed reports on medication compliance

### Long-term Vision
- [ ] **Healthcare Provider Integration** - Share reports with doctors
- [ ] **Family Sharing** - Help manage medications for loved ones
- [ ] **Prescription Scanning** - Add medications by scanning bottles
- [ ] **Multiple Languages** - Internationalization support

---

## 🤝 Contributing

We welcome contributions from the community! Here's how you can help:

### How to Contribute

1. **Fork** the repository on GitHub
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Make** your changes and add tests if applicable
4. **Commit** your changes (`git commit -m 'Add amazing feature'`)
5. **Push** to your branch (`git push origin feature/amazing-feature`)
6. **Open** a Pull Request with a clear description

### Development Guidelines

- Follow Flutter/Dart best practices and style guidelines
- Write clear, descriptive commit messages
- Add tests for new features when possible
- Update documentation as needed
- Ensure your code works on both Android and iOS

### Areas Where We Need Help

- iOS notification improvements
- UI/UX enhancements
- Testing on different devices
- Translation to other languages
- Documentation improvements

---

## 📜 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for full details.

```
Copyright (c) 2025 Pilzy Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software")...
```

---

## 👨‍💻 Author & Support

**Built with ❤️ by Sayan**

- 🌐 **Website**: https://sayan-kabir-portfolio.vercel.app
- 📧 **Email**: sayan.kabir.official@gmail.com
- 💼 **LinkedIn**: https://linkedin.com/in/sayankabir


---

<div align="center">

**⭐ If Pilzy helps you stay healthy, consider giving us a star on GitHub! ⭐**

Made with 💊 and ❤️ for better health management

</div>