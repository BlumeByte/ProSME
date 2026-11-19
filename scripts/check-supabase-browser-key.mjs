import { parseArgs } from 'node:util';
import { readFileSync } from 'node:fs';
import { isPublicSupabaseKey } from '../admin_web/supabase-browser-key.mjs';

try {
  const { values } = parseArgs({
    options: {
      config: { type: 'string' },
      'allow-missing': { type: 'boolean' },
    },
  });
  const key = values.config
    ? JSON.parse(readFileSync(values.config, 'utf8')).SUPABASE_ANON_KEY
    : process.env.SUPABASE_ANON_KEY;
  if (!(typeof key === 'string' && isPublicSupabaseKey(key)) &&
      !(values['allow-missing'] && (key == null || key === ''))) {
    throw new Error('Invalid browser key');
  }
} catch {
  // Parsed input and parser errors can contain credentials.
  console.error('SUPABASE_ANON_KEY must contain a Supabase publishable key or legacy anon key.');
  process.exitCode = 1;
}
