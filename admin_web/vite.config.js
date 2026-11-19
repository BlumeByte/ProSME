import { defineConfig, loadEnv } from 'vite';

import { isPublicSupabaseKey } from './supabase-browser-key.mjs';

export default defineConfig(({ command, mode }) => {
  const { VITE_SUPABASE_PUBLISHABLE_KEY: key } = loadEnv(mode, process.cwd(), 'VITE_');
  if (command === 'build' && key && !isPublicSupabaseKey(key)) {
    throw new Error(
      'VITE_SUPABASE_PUBLISHABLE_KEY must contain a Supabase publishable key or legacy anon key.',
    );
  }
  return {};
});
