import { createClient } from '@supabase/supabase-js';
import fs from 'node:fs';

const bucketIds = ['avatars', 'listing-images', 'artisan-verification'];
const localConfigPath = new URL('../supabase.local.json', import.meta.url);
const localConfig = fs.existsSync(localConfigPath)
  ? JSON.parse(fs.readFileSync(localConfigPath, 'utf8'))
  : {};

const supabaseUrl = process.env.SUPABASE_URL || localConfig.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl) {
  throw new Error('SUPABASE_URL is required.');
}
if (!serviceRoleKey) {
  throw new Error('SUPABASE_SERVICE_ROLE_KEY is required for storage cleanup.');
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const listAllObjectPaths = async (bucketId, prefix = '') => {
  const paths = [];
  let offset = 0;
  const limit = 100;

  while (true) {
    const { data, error } = await supabase.storage
      .from(bucketId)
      .list(prefix, {
        limit,
        offset,
        sortBy: { column: 'name', order: 'asc' },
      });

    if (error) throw new Error(`${bucketId}/${prefix}: ${error.message}`);
    if (!data?.length) break;

    for (const item of data) {
      const itemPath = prefix ? `${prefix}/${item.name}` : item.name;
      if (item.id === null) {
        paths.push(...(await listAllObjectPaths(bucketId, itemPath)));
      } else {
        paths.push(itemPath);
      }
    }

    if (data.length < limit) break;
    offset += limit;
  }

  return paths;
};

for (const bucketId of bucketIds) {
  const paths = await listAllObjectPaths(bucketId);
  let removed = 0;

  for (let index = 0; index < paths.length; index += 100) {
    const batch = paths.slice(index, index + 100);
    const { data, error } = await supabase.storage.from(bucketId).remove(batch);
    if (error) throw new Error(`${bucketId}: ${error.message}`);
    removed += data?.length || batch.length;
  }

  console.log(`${bucketId}: removed ${removed} object(s).`);
}
