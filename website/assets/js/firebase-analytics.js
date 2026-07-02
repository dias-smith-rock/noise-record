import { initializeApp } from 'https://www.gstatic.com/firebasejs/12.15.0/firebase-app.js';
import { getAnalytics } from 'https://www.gstatic.com/firebasejs/12.15.0/firebase-analytics.js';

const firebaseConfig = {
  apiKey: 'AIzaSyBjMIURHAtpZ07D4jbdvfSFkslKsT9DDnA',
  authDomain: 'website-decibelmeter.firebaseapp.com',
  projectId: 'website-decibelmeter',
  storageBucket: 'website-decibelmeter.firebasestorage.app',
  messagingSenderId: '873774535374',
  appId: '1:873774535374:web:aa64d382aa890cd33f769f',
  measurementId: 'G-WG20DNR6DY',
};

const app = initializeApp(firebaseConfig);
getAnalytics(app);
