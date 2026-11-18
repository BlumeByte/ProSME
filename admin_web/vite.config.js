import { defineConfig, loadEnv } from 'vite';

function isPublicSupabaseKey(key) {
  if (/^sb_publishable_[A-Za-z0-9_-]+$/.test(key)) return true;

  // Legacy client keys are JWTs. Check their declared role to catch
  // configuration mistakes. Supabase still verifies the key itself.
  const parts = key.split('.');
  if (parts.length !== 3 || parts.some((part) => !/^[A-Za-z0-9_-]+$/.test(part))) {
    return false;
  }
  try {
    return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'))?.role === 'anon';
  } catch {
    return false;
  }
}

export default defineConfig(({ command, mode }) => {
  const { VITE_SUPABASE_PUBLISHABLE_KEY: key } = loadEnv(mode, process.cwd(), 'VITE_');
  if (command === 'build' && key && !isPublicSupabaseKey(key)) {
    throw new Error(
      'VITE_SUPABASE_PUBLISHABLE_KEY must contain a Supabase publishable key or legacy anon key.',
    );
  }
  return {};
});
