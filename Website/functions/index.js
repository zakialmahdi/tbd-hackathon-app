const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();
const adminRegistrationKey = defineSecret('ADMIN_REGISTRATION_KEY');

exports.registerAdmin = onCall({ region: 'asia-southeast1', secrets: [adminRegistrationKey], maxInstances: 5 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in before registering as an admin.');

  const suppliedKey = typeof request.data?.adminKey === 'string' ? request.data.adminKey : '';
  if (!suppliedKey || suppliedKey !== adminRegistrationKey.value()) {
    throw new HttpsError('permission-denied', 'The admin registration key is incorrect.');
  }

  const uid = request.auth.uid;
  await getFirestore().doc(`admins/${uid}`).set({
    enabled: true,
    email: request.auth.token.email || null,
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ok: true };
});
