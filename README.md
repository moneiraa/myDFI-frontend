# MyDFI Frontend (Flutter)

This is the Flutter mobile app for MyDFI.  
It connects to the backend API to:
- View user medications
- Add new medications with autocomplete support
- Show daily notifications

-------------------------------------

## Tech Stack
- Framework: Flutter
- Language: Dart
- Backend: FastAPI
- Database: MongoDB Atlas (via backend)



## How to Run

1. Clone repository
   git clone https://github.com/<your-username>/myDFI-frontend.git
   cd myDFI-frontend

2. Install packages
   flutter pub get

3. Run app
   Connect a device or start an emulator, then:
   flutter run



## API URL
By default, the app connects to:
https://mydfi.onrender.com



## Notifications
The app uses flutter_local_notifications to send daily reminders.
