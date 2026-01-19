# VittaraFinOS

A modern, high-performance personal finance operating system built with Flutter.

## Features

- **Dashboard:** Financial overview with futuristic 3D visualizations.
- **Manage:** Central hub for managing financial entities.
  - **Banks:** Add/Edit banks, manage Sender IDs for SMS parsing.
  - **Accounts:** (In Progress) Track specific bank accounts and wallets.
- **Settings:**
  - **Security:** Biometric Authentication, Auto-Lock on Minimize with customizable timeout.
  - **Appearance:** Light, Dark, and System themes (True AMOLED Dark Mode).
  - **Data:** Local and Cloud Backup options.

## Tech Stack

- **Flutter:** UI Framework.
- **Provider:** State Management.
- **Shared Preferences:** Local persistence for settings.
- **Local Auth:** Biometric security.
- **Google Fonts:** Inter typography.

## Architecture

- **Logic:** `lib/logic/` (SettingsController, etc.)
- **UI:** `lib/ui/` (Screens, Widgets, Styles)
  - **Styles:** Centralized `AppStyles` for consistent theming.
  - **Widgets:** Reusable animations (`FadeScalePageRoute`, `BouncyButton`) and loader.

## Setup

1.  `flutter pub get`
2.  `flutter run`