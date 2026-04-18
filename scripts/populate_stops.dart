import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:enjaz7/firebase_options.dart'; // تأكد من المسار الصحيح

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final stopsCollection = FirebaseFirestore.instance
      .collection('bus_lines')
      .doc('line1')
      .collection('stops');

  await stopsCollection.add({'name': 'Tahrir Square', 'lat': 30.0444, 'lng': 31.2357});
  await stopsCollection.add({'name': 'Zamalek', 'lat': 30.0626, 'lng': 31.2130});
  await stopsCollection.add({'name': 'Heliopolis', 'lat': 30.0850, 'lng': 31.3250});

  print('Sample stops added successfully!');
}
