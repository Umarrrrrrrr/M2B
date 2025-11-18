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

export const notifyExpiringSubscriptions = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const now = Date.now();
    const soon = now + 3 * 24 * 60 * 60 * 1000;

    const snapshot = await db
      .collection('subscriptions')
      .where('status', '==', 'active')
      .get();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const end = (data.endDate as admin.firestore.Timestamp | undefined)
        ?.toDate();
      if (!end) {
        continue;
      }
      const time = end.getTime();
      if (time >= now && time <= soon) {
        console.log(
          `Subscription ${doc.id} for patient ${data.patientId} expires soon.`
        );
        const patientId = data.patientId as string;
        const doctorId = data.doctorId as string;
        const daysLeft = Math.max(
          0,
          Math.ceil((time - now) / (1000 * 60 * 60 * 24))
        );
        const title = 'Subscription expiring soon';
        const body = `Your subscription will expire in ${daysLeft} day(s).`;
        await sendNotification(patientId, title, body, {
          subscriptionId: doc.id,
          type: 'subscription-expiring',
        });
        await sendNotification(
          doctorId,
          'Patient subscription expiring',
          `Patient ${patientId} subscription expires in ${daysLeft} day(s).`,
          {
            subscriptionId: doc.id,
            patientId,
            type: 'subscription-expiring',
          }
        );
      }
    }

    return null;
  });

export const onSubscriptionApproved = functions.firestore
  .document('subscriptions/{id}')
  .onUpdate(async (change, context) => {
    const beforeStatus = change.before.get('status');
    const afterStatus = change.after.get('status');
    if (beforeStatus === 'active' || afterStatus !== 'active') {
      return null;
    }

    const data = change.after.data();
    const patientId = data.patientId as string;
    const doctorId = data.doctorId as string;
    const patientTitle = 'Subscription approved';
    const patientBody =
      'Your doctor has approved your subscription. You can now chat and share data.';
    const doctorTitle = 'New patient activated';
    const doctorBody =
      `Patient ${patientId} is now active. Check their dashboard for updates.`;

    await Promise.all([
      sendNotification(patientId, patientTitle, patientBody, {
        subscriptionId: context.params.id,
        type: 'subscription-approved',
      }),
      sendNotification(doctorId, doctorTitle, doctorBody, {
        subscriptionId: context.params.id,
        patientId,
        type: 'subscription-approved',
      }),
    ]);

    return null;
  });

export const onNewChatMessage = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const chatRef = db.collection('chats').doc(context.params.chatId);
    const chat = await chatRef.get();
    if (!chat.exists) return null;

    const chatData = chat.data();
    const patientId = chatData?.patientId as string;
    const doctorId = chatData?.doctorId as string;
    const senderId = data.senderId as string;
    const recipients: string[] = [];
    if (patientId && patientId !== senderId) recipients.push(patientId);
    if (doctorId && doctorId !== senderId) recipients.push(doctorId);
    if (!recipients.length) return null;

    await Promise.all(
      recipients.map((uid) =>
        sendNotification(
          uid,
          'New chat message',
          (data.text as string) ?? 'Tap to open the conversation.',
          {
            type: 'chat-message',
            chatId: context.params.chatId,
          }
        )
      )
    );

    return null;
  });

export const mockPaySubscription = functions.https.onCall(
  async (data, context) => {
    const subscriptionId = data.subscriptionId as string;
    if (!subscriptionId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'subscriptionId is required'
      );
    }

    const subRef = db.collection('subscriptions').doc(subscriptionId);
    const snap = await subRef.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Subscription missing');
    }
    const subData = snap.data()!;
    if (subData.paymentStatus === 'paid') {
      return { message: 'Already paid' };
    }

    const reference = `MOCK-${Date.now()}`;
    await subRef.update({
      paymentStatus: 'paid',
      paymentReference: reference,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { message: 'Payment recorded', reference };
  }
);
async function getDeviceTokens(userId: string): Promise<string[]> {
  const snapshot = await db
    .collection('users')
    .doc(userId)
    .collection('devices')
    .get();
  return snapshot.docs
    .map((doc) => (doc.get('token') as string) ?? doc.id)
    .filter((token) => !!token);
}

async function sendNotification(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
) {
  const tokens = await getDeviceTokens(userId);
  if (!tokens.length) {
    console.log(`No device tokens for ${userId}`);
    return;
  }

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });
}
export const onNewHealthRecord = functions.firestore
  .document('patients/{patientId}/healthRecords/{recordId}')
  .onCreate(async (snapshot, context) => {
    const patientId = context.params.patientId as string;
    const record = snapshot.data();

    const subscriptions = await db
      .collection('subscriptions')
      .where('patientId', '==', patientId)
      .where('status', '==', 'active')
      .limit(5)
      .get();

    if (subscriptions.empty) return null;

    const message =
      record.notes || 'New health data has been shared by the patient.';
    await Promise.all(
      subscriptions.docs.map((doc) => {
        const doctorId = doc.data().doctorId as string;
        return sendNotification(
          doctorId,
          'New patient update',
          message,
          {
            type: 'health-record',
            patientId,
            recordId: context.params.recordId,
          }
        );
      })
    );

    return null;
  });
