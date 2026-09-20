import { initializeApp } from 'firebase/app';
import { getMessaging, getToken, onMessage } from 'firebase/messaging';

// Firebase config - replace with your actual project config
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || '',
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || '',
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || '',
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || '',
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || '',
  appId: import.meta.env.VITE_FIREBASE_APP_ID || '',
};

let messaging = null;

export const initFirebase = () => {
  try {
    if (firebaseConfig.apiKey) {
      const app = initializeApp(firebaseConfig);
      messaging = getMessaging(app);
      console.log('Firebase initialized');
      return true;
    }
    console.log('Firebase not configured - using browser notifications as fallback');
    return false;
  } catch (error) {
    console.error('Firebase init error:', error);
    return false;
  }
};

export const requestNotificationPermission = async () => {
  try {
    const permission = await Notification.requestPermission();
    if (permission === 'granted') {
      console.log('Notification permission granted');

      if (messaging) {
        const token = await getToken(messaging, {
          vapidKey: import.meta.env.VITE_FIREBASE_VAPID_KEY || '',
        });
        console.log('FCM Token:', token);
        return token;
      }

      return 'browser-notifications-only';
    }
    console.log('Notification permission denied');
    return null;
  } catch (error) {
    console.error('Error requesting notification permission:', error);
    return null;
  }
};

export const onFCMMessage = (callback) => {
  if (messaging) {
    return onMessage(messaging, (payload) => {
      console.log('FCM message received:', payload);
      callback(payload);
    });
  }
  return null;
};

// Fallback browser notification
export const showBrowserNotification = (title, body, icon = '/alert-icon.png') => {
  if ('Notification' in window && Notification.permission === 'granted') {
    new Notification(title, { body, icon, badge: '/badge-icon.png' });
  }
};
