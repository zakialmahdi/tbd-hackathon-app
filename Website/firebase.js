export const firebaseConfig = {
  apiKey: "AIzaSyDQn3NwF3dTwE9W1l8W8v3fhpxwkuO82m0",
  authDomain: "tbd-hackathon-app.firebaseapp.com",
  projectId: "tbd-hackathon-app",
  storageBucket: "tbd-hackathon-app.firebasestorage.app",
  messagingSenderId: "635460486045",
  appId: "1:635460486045:web:0493384ea9ef935a9fa574"
};

export const LIVE = Boolean(firebaseConfig.projectId);
export const [{ initializeApp }, fs, au, fn] = await Promise.all([
  import('https://www.gstatic.com/firebasejs/13.0.0/firebase-app.js'),
  import('https://www.gstatic.com/firebasejs/13.0.0/firebase-firestore.js'),
  import('https://www.gstatic.com/firebasejs/13.0.0/firebase-auth.js'),
  import('https://www.gstatic.com/firebasejs/13.0.0/firebase-functions.js')
]);

export const app = initializeApp(firebaseConfig);
export const auth = au.getAuth(app);
export const db = fs.getFirestore(app);
export const functions = fn.getFunctions(app, 'asia-southeast1');
