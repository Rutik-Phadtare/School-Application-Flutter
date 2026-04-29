# School Management App

A comprehensive school management application built with Flutter and Firebase, designed to streamline educational administration and enhance communication between administrators, teachers, students, and parents.

## Features

### Admin Dashboard
- Complete control over all school operations
- Manage teachers, classes, and student data
- Configure feature access permissions
- Bulk student data entry
- Timetable management
- Results management per semester/internal/unit tests
- Send announcements to specific classes

### Teacher Portal
- Online attendance marking with face recognition
- View and manage assigned classes
- Access student information
- Submit and view results
- Receive notifications and announcements

### Student Portal
- View personal profile and attendance
- Check results and grades
- Access timetable
- Receive notifications

### Parent Portal
- Monitor child's attendance and performance
- View results and announcements
- Limited access based on admin permissions

## Technology Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Firestore, Auth, Storage, Messaging)
- **ML**: Google ML Kit for face recognition
- **State Management**: Provider
- **Notifications**: Firebase Cloud Messaging + Local notifications

## Getting Started

### Prerequisites
- Flutter SDK (^3.5.0)
- Firebase project setup
- Android Studio / VS Code with Flutter extensions

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Rutik-Phadtare/School-Application-Flutter.git
   cd School-Application-Flutter
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Add your `google-services.json` to `android/app/`
   - Add your `GoogleService-Info.plist` to `ios/Runner/`
   - Update `lib/firebase_options.dart` with your Firebase config

4. Run the app:
   ```bash
   flutter run
   ```

## Permissions

The app requires the following permissions:
- Camera: For face recognition attendance
- Storage: For profile pictures and documents
- Notifications: For announcements and alerts

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
