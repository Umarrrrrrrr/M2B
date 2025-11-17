import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();
const db = admin.firestore();

export const expireSubscriptions = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await db
      .collection('subscriptions')
      .where('status', '==', 'active')
      .where('endDate', '<=', now)
      .get();

    if (snapshot.empty) {
      console.log('No subscriptions to expire at this time.');
      return null;
    }

    const batch = db.batch();

    snapshot.forEach((doc) => {
      const data = doc.data();
      const patientId = data.patientId as string;
      const doctorId = data.doctorId as string;

      batch.update(doc.ref, { status: 'expired' });

      batch.update(
        db
          .collection('patients')
          .doc(patientId)
          .collection('subscriptions')
          .doc(doc.id),
        { status: 'expired' }
      );

      batch.update(
        db
          .collection('doctors')
          .doc(doctorId)
          .collection('patients')
          .doc(patientId),
        { status: 'expired' }
      );
    });

    await batch.commit();
    console.log(`Expired ${snapshot.size} subscriptions.`);
    return null;
  });
