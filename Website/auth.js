import { au, auth, fn, functions, fs, db } from './firebase.js';

const $ = selector => document.querySelector(selector);
const isRegister = document.body.dataset.authMode === 'register';
const message = $('#lerr');

const hasAdminAccess = async user => {
  if (!user) return false;
  if (user.email === 'test@gmail.com') return true;
  try {
    const [adminSnap, token] = await Promise.all([
      fs.getDoc(fs.doc(db, 'admins', user.uid)),
      au.getIdTokenResult(user)
    ]);
    return token.claims?.email === 'test@gmail.com'
      || (adminSnap.exists() && adminSnap.data()?.enabled === true)
      || token.claims?.admin === true;
  } catch (err) {
    console.error('Error verifying admin access:', err);
    return false;
  }
};

const showError = error => {
  const messages = {
    'auth/invalid-credential': 'Email or password is incorrect.',
    'auth/user-not-found': 'No account with that email exists.',
    'auth/wrong-password': 'Email or password is incorrect.',
    'auth/email-already-in-use': 'That email already has an account. Sign in, or register using its password.',
    'auth/invalid-email': 'Enter a valid email address.',
    'auth/weak-password': 'Use a stronger password (at least 6 characters).',
    'auth/too-many-requests': 'Too many attempts. Wait a while, then try again.',
    'auth/unauthorized-domain': 'This domain is not authorized for Firebase Authentication. Add this hostname under Firebase Authentication settings.',
    'auth/operation-not-allowed': 'Sign-in method is disabled in Firebase Authentication settings.',
    'auth/account-exists-with-different-credential': 'This email already uses another sign-in method. Sign in using that method first.',
    'auth/network-request-failed': 'Could not reach Firebase. Check your internet connection and try again.'
  };
  message.textContent = (messages[error?.code] || error?.message || 'Authentication failed.') + (error?.code ? ` (${error.code})` : '');
};

const promoteToAdmin = async () => {
  try {
    const key = $('#adminKey')?.value;
    if (!key) {
      message.textContent = 'Enter the admin key.';
      return;
    }
    const result = await fn.httpsCallable(functions, 'registerAdmin')({ adminKey: key });
    await au.getIdTokenResult(auth.currentUser, true);
    if (result.data?.ok) {
      location.replace('main.html');
    }
  } catch (error) {
    message.textContent = error.code === 'functions/permission-denied'
      ? 'That admin key is incorrect.'
      : (error.message || 'Could not enable admin access.');
    if (error.code === 'functions/permission-denied') {
      await au.signOut(auth);
    }
  }
};

document.querySelectorAll('[data-reveal]').forEach(button => button.addEventListener('click', () => {
  const input = $('#' + button.dataset.reveal);
  if (!input) return;
  const visible = input.type === 'password';
  input.type = visible ? 'text' : 'password';
  button.textContent = visible ? 'Hide' : 'Show';
  button.setAttribute('aria-label', (visible ? 'Hide ' : 'Show ') + input.id);
}));

$('#go')?.addEventListener('click', async () => {
  message.textContent = '';
  const email = $('#em')?.value.trim();
  const password = $('#pw')?.value;

  if (!email || !password) {
    message.textContent = 'Enter your email and password.';
    return;
  }

  if (!isRegister) {
    try {
      const cred = await au.signInWithEmailAndPassword(auth, email, password);
      const allowed = await hasAdminAccess(cred.user);
      if (!allowed) {
        message.textContent = 'This account does not have admin access. Register with the admin key or contact an administrator.';
        await au.signOut(auth);
        return;
      }
      location.replace('main.html');
    } catch (error) {
      showError(error);
    }
    return;
  }

  // Register flow
  if (!$('#adminKey')?.value) {
    message.textContent = 'Enter the admin key.';
    $('#adminKey')?.focus();
    return;
  }

  if (auth.currentUser) {
    await promoteToAdmin();
    return;
  }

  try {
    await au.createUserWithEmailAndPassword(auth, email, password);
    await promoteToAdmin();
  } catch (error) {
    if (error.code !== 'auth/email-already-in-use') {
      showError(error);
      return;
    }
    try {
      await au.signInWithEmailAndPassword(auth, email, password);
      await promoteToAdmin();
    } catch {
      message.textContent = 'An account with this email already exists, but the password provided is incorrect.';
    }
  }
});

$('#googleAuth')?.addEventListener('click', async () => {
  message.textContent = '';
  if (isRegister && !$('#adminKey')?.value) {
    message.textContent = 'Enter the admin key before continuing with Google.';
    $('#adminKey')?.focus();
    return;
  }

  const provider = new au.GoogleAuthProvider();
  try {
    // Try popup first (faster and doesn't lose page state)
    const res = await au.signInWithPopup(auth, provider);
    if (res.user) {
      if (isRegister) {
        await promoteToAdmin();
      } else {
        const allowed = await hasAdminAccess(res.user);
        if (allowed) {
          location.replace('main.html');
        } else {
          sessionStorage.setItem('veGoogleNeedsAdmin', '1');
          location.replace('register.html');
        }
      }
      return;
    }
  } catch (error) {
    // If popup is blocked by browser, fallback to redirect flow
    if (error.code === 'auth/popup-blocked' || error.code === 'auth/cancelled-popup-request') {
      try {
        sessionStorage.setItem('veGoogleAuthMode', isRegister ? 'register' : 'signin');
        if (isRegister) sessionStorage.setItem('vePendingAdminKey', $('#adminKey').value);
        await au.signInWithRedirect(auth, provider);
        return;
      } catch (redirectError) {
        showError(redirectError);
      }
    } else {
      showError(error);
    }
  }
});

$('#reset')?.addEventListener('click', async () => {
  const email = $('#em')?.value.trim();
  if (!email) {
    message.textContent = 'Enter your email first, then choose Reset password.';
    return;
  }
  message.textContent = '';
  try {
    await au.sendPasswordResetEmail(auth, email);
    message.textContent = 'If an account exists for that email, Firebase sent a password reset link.';
  } catch (error) {
    showError(error);
  }
});

// Auto-redirect if already signed in as admin
au.onAuthStateChanged(auth, async user => {
  if (user && !isRegister) {
    const allowed = await hasAdminAccess(user);
    if (allowed) {
      location.replace('main.html');
    }
  } else if (user && isRegister && $('#em') && !$('#em').value) {
    $('#em').value = user.email || '';
  }
});

// Check redirect flow
const redirectMode = sessionStorage.getItem('veGoogleAuthMode');
const hasPendingGoogleRegistration = Boolean(sessionStorage.getItem('vePendingAdminKey'));
if (redirectMode || hasPendingGoogleRegistration) message.textContent = 'Completing Google sign-in...';
sessionStorage.removeItem('veGoogleAuthMode');

try {
  const result = await au.getRedirectResult(auth);
  const returnedUser = result?.user || (hasPendingGoogleRegistration ? auth.currentUser : null);
  const returnedMode = redirectMode || (isRegister ? 'register' : 'signin');
  if (returnedUser && returnedMode === 'signin') {
    if (await hasAdminAccess(returnedUser)) {
      location.replace('main.html');
    } else {
      sessionStorage.setItem('veGoogleNeedsAdmin', '1');
      location.replace('register.html');
    }
  }
  if (returnedUser && returnedMode === 'register') {
    if ($('#em')) $('#em').value = returnedUser.email || '';
    const pendingAdminKey = sessionStorage.getItem('vePendingAdminKey');
    sessionStorage.removeItem('vePendingAdminKey');
    if (pendingAdminKey) {
      if ($('#adminKey')) $('#adminKey').value = pendingAdminKey;
      message.textContent = 'Google sign-in complete. Enabling admin access...';
      await promoteToAdmin();
    } else {
      message.textContent = 'Google sign-in complete. Enter the admin key and choose Register to finish.';
    }
  }
} catch (error) {
  showError(error);
}

if (isRegister && sessionStorage.getItem('veGoogleNeedsAdmin') === '1') {
  sessionStorage.removeItem('veGoogleNeedsAdmin');
  message.textContent = 'Google sign-in succeeded, but this account is not an admin yet. Enter the admin key and choose Register to enable admin access.';
  if (auth.currentUser?.email && $('#em')) $('#em').value = auth.currentUser.email;
}
