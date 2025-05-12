class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY',
      defaultValue: 'AIzaSyA_9SV39BIwuOQULX_mUp0w3c2KdEU5oJ8');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID',
      defaultValue: '1:13701743979:android:1b0281e61059ce0eb0b82e');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID',
      defaultValue: 'flutter-expense-tracker-a6400');
  static const messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '13701743979');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
      defaultValue: 'flutter-expense-tracker-a6400.firebasestorage.app');
}
