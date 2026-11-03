import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.appleexpert.app',
  appName: 'Apple Expert',
  webDir: 'out',
  plugins: {
    // iOS: the keyboard shrinks the whole web view, so fixed sheets and the
    // focused field stay above it instead of behind it. Android already resizes
    // through Capacitor's SystemBars insets (edge-to-edge kept), which this
    // setting does not touch; resizeOnFullScreen stays off for that reason.
    Keyboard: {
      resize: 'native',
    },
  },
};

export default config;
