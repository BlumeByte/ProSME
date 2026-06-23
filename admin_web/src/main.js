import { createClient } from '@supabase/supabase-js';
import readXlsxFile from 'read-excel-file/browser';
import './styles.css';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
const app = document.querySelector('#app');

const emptyData = () => ({
  profiles: [],
  listings: [],
  jobs: [],
  bids: [],
  walletTransactions: [],
  threads: [],
  messages: [],
  ratings: [],
  notifications: [],
  reports: [],
});

const state = {
  session: null,
  profile: null,
  recoveringPassword:
    window.location.pathname === '/reset-password' ||
    window.location.hash.includes('type=recovery'),
  tab: 'overview',
  loading: true,
  checkingAccess: false,
  busy: false,
  error: '',
  notice: '',
  filters: { q: '', role: 'all', status: 'all', sort: 'newest' },
  data: emptyData(),
  tableErrors: {},
};

const hasConfig = Boolean(supabaseUrl && supabaseKey);
const supabase = hasConfig
  ? createClient(supabaseUrl, supabaseKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null;

const tabs = [
  ['overview', 'Overview'],
  ['users', 'Users'],
  ['verifications', 'Verifications'],
  ['reports', 'Reports'],
  ['bidTracking', 'Bids Tracking'],
  ['jobs', 'Jobs'],
  ['listings', 'Listings'],
  ['settings', 'Settings'],
];

const esc = (value) =>
  String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');

const normalize = (value) => String(value ?? '').trim();
const lower = (value) => normalize(value).toLowerCase();
const validEmail = (value) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(normalize(value));
const generateStrongPassword = () => {
  const lowercase = 'abcdefghijkmnopqrstuvwxyz';
  const uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const numbers = '23456789';
  const symbols = '!@#$%^&*';
  const all = lowercase + uppercase + numbers + symbols;
  const pick = (chars) => chars[crypto.getRandomValues(new Uint32Array(1))[0] % chars.length];
  return [
    pick(lowercase),
    pick(uppercase),
    pick(numbers),
    pick(symbols),
    ...Array.from({ length: 10 }, () => pick(all)),
  ]
    .sort(() => crypto.getRandomValues(new Uint32Array(1))[0] - 2147483648)
    .join('');
};

const money = (value) =>
  Number(value || 0).toLocaleString('en-GH', {
    style: 'currency',
    currency: 'GHS',
    maximumFractionDigits: 0,
  });

const dateText = (value) => {
  if (!value) return 'Unknown';
  return new Date(value).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

const roleBadge = (role) => {
  const displayRole = role === 'admin' ? 'admin' : role;
  const map = {
    admin: 'badge badge-purple',
    admin: 'badge badge-purple',
    artisan: 'badge badge-teal',
    customer: 'badge',
  };
  return `<span class="${map[role] || 'badge'}">${esc(displayRole || 'customer')}</span>`;
};

const statusBadge = (status) => {
  const map = {
    verified: 'badge badge-green',
    pending: 'badge badge-orange',
    rejected: 'badge badge-red',
    active: 'badge badge-green',
    completed: 'badge badge-blue',
    in_progress: 'badge badge-blue',
    cancelled: 'badge badge-red',
    accepted: 'badge badge-green',
    resolved: 'badge badge-green',
    reviewing: 'badge badge-blue',
    open: 'badge badge-orange',
  };
  return `<span class="${map[status] || 'badge'}">${esc(status || 'unknown')}</span>`;
};

function setNotice(message) {
  state.notice = message;
  setTimeout(() => {
    if (state.notice === message) {
      state.notice = '';
      render();
    }
  }, 4000);
}

async function safeSelect(name, query) {
  const result = await query;
  if (result.error) {
    state.tableErrors[name] = result.error.message;
    return [];
  }
  delete state.tableErrors[name];
  return result.data || [];
}

async function init() {
  if (!hasConfig) {
    state.loading = false;
    state.error = 'Add VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY in Vercel.';
    render();
    return;
  }

  const { data } = await supabase.auth.getSession();
  state.session = data.session;

  supabase.auth.onAuthStateChange((event, session) => {
    state.session = session;
    if (event === 'PASSWORD_RECOVERY') state.recoveringPassword = true;
    if (state.recoveringPassword) {
      state.loading = false;
      render();
      return;
    }
    if (!session) {
      state.profile = null;
      state.data = emptyData();
      state.loading = false;
      render();
      return;
    }
    loadDashboard();
  });

  if (state.recoveringPassword) {
    state.loading = false;
    render();
  } else if (state.session) {
    await loadDashboard();
  } else {
    state.loading = false;
    render();
  }
}

async function loadDashboard() {
  if (!state.session?.user) {
    state.loading = false;
    state.checkingAccess = false;
    render();
    return;
  }

  state.loading = true;
  state.checkingAccess = true;
  state.error = '';

  const userId = state.session.user.id;
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('id,full_name,email,role,verification_status,tenant_id,created_at')
    .eq('id', userId)
    .maybeSingle();

  if (profileError) {
    await supabase.auth.signOut({ scope: 'local' });
    state.session = null;
    state.profile = null;
    state.data = emptyData();
    state.error = `Could not verify admin access: ${profileError.message}`;
    state.loading = false;
    state.checkingAccess = false;
    render();
    return;
  }

  state.profile = profile;

  if (profile?.role !== 'admin') {
    await supabase.auth.signOut({ scope: 'local' });
    state.session = null;
    state.profile = null;
    state.error = 'Only admin accounts can open this dashboard.';
    state.loading = false;
    state.checkingAccess = false;
    render();
    return;
  }

  await refreshData();
  state.loading = false;
  state.checkingAccess = false;
  render();
}

async function refreshData() {
  state.tableErrors = {};

  const [
    profiles,
    listings,
    jobs,
    bids,
    walletTransactions,
    threads,
    messages,
    ratings,
    notifications,
    reports,
  ] = await Promise.all([
    safeSelect(
      'profiles',
      supabase
        .from('profiles')
        .select(
          'id,full_name,email,phone,role,verification_status,tenant_id,country,location,categories,description,bio,rating_summary,national_id_front_url,national_id_back_url,business_certificate_urls,verification_notes,verification_submitted_at,verification_reviewed_at,created_at'
        )
        .order('created_at', { ascending: false })
        .limit(500)
    ),
    safeSelect(
      'listings',
      supabase
        .from('listings')
        .select('id,title,description,category,location,price_min,price_max,artisan_id,tenant_id,created_at')
        .order('created_at', { ascending: false })
        .limit(500)
    ),
    safeSelect(
      'jobs',
      supabase
        .from('jobs')
        .select('id,title,description,location,budget,status,created_by,tenant_id,created_at')
        .order('created_at', { ascending: false })
        .limit(500)
    ),
    safeSelect(
      'job_bids',
      supabase
        .from('job_bids')
        .select('id,job_id,artisan_id,amount,message,status,created_at,updated_at')
        .order('created_at', { ascending: false })
        .limit(500)
    ),
    safeSelect(
      'wallet_transactions',
      supabase
        .from('wallet_transactions')
        .select(
          'id,job_id,bid_id,user_id,artisan_id,amount,currency,event_type,invoice_number,job_title,job_location,customer_name,customer_email,artisan_name,artisan_email,payment_status,work_status,completed_at,created_at'
        )
        .order('created_at', { ascending: false })
        .limit(1000)
    ),
    safeSelect(
      'threads',
      supabase
        .from('threads')
        .select('id,user_id,artisan_id,last_message,updated_at,created_at')
        .order('updated_at', { ascending: false })
        .limit(500)
    ),
    safeSelect(
      'messages',
      supabase
        .from('messages')
        .select('id,thread_id,sender_id,type,content,read_at,created_at')
        .order('created_at', { ascending: false })
        .limit(2000)
    ),
    safeSelect(
      'job_ratings',
      supabase
        .from('job_ratings')
        .select('id,job_id,artisan_id,user_id,stars,comment,created_at')
        .order('created_at', { ascending: false })
        .limit(500)
    ),
    safeSelect(
      'admin_notifications',
      supabase
        .from('admin_notifications')
        .select('id,type,title,body,actor_id,related_user_id,related_table,related_id,read_at,created_at')
        .order('created_at', { ascending: false })
        .limit(500)
    ),
    safeSelect(
      'reports',
      supabase
        .from('reports')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(500)
    ),
  ]);

  state.data = {
    profiles,
    listings,
    jobs,
    bids,
    walletTransactions,
    threads,
    messages,
    ratings,
    notifications,
    reports,
  };
}

async function adminAction(action, payload = {}) {
  const { data, error } = await supabase.functions.invoke('admin-dashboard', {
    body: {
      action,
      redirectTo: `${window.location.origin}/reset-password`,
      ...payload,
    },
  });
  if (error) {
    throw new Error(
      `${error.message}. Confirm the admin-dashboard Edge Function is deployed and its SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY secrets are set for the same Supabase project as Vercel.`
    );
  }
  if (data?.error) throw new Error(data.error);
  return data;
}

const isEdgeFunctionRequestError = (error) =>
  lower(error?.message || error).includes('failed to send a request to the edge function');

async function updateManagedRow(table, id, patch, edgeAction) {
  try {
    await adminAction(edgeAction, { id, patch });
  } catch (error) {
    if (!isEdgeFunctionRequestError(error)) throw error;
    const { error: tableError } = await supabase.from(table).update(patch).eq('id', id);
    if (tableError) {
      throw new Error(
        `${tableError.message}. The Edge Function is unavailable and direct ${table} updates are blocked. Apply the admin RLS migration or deploy admin-dashboard.`
      );
    }
  }
}

async function deleteManagedRow(table, id, edgeAction) {
  try {
    await adminAction(edgeAction, { id });
  } catch (error) {
    if (!isEdgeFunctionRequestError(error)) throw error;
    const { error: tableError } = await supabase.from(table).delete().eq('id', id);
    if (tableError) {
      throw new Error(
        `${tableError.message}. The Edge Function is unavailable and direct ${table} deletes are blocked. Apply the admin RLS migration or deploy admin-dashboard.`
      );
    }
  }
}

async function insertManagedRow(table, patch, edgeAction) {
  try {
    await adminAction(edgeAction, { patch });
  } catch (error) {
    if (!isEdgeFunctionRequestError(error)) throw error;
    const { error: tableError } = await supabase.from(table).insert(patch);
    if (tableError) {
      throw new Error(
        `${tableError.message}. The Edge Function is unavailable and direct ${table} inserts are blocked. Apply the admin RLS migration or deploy admin-dashboard.`
      );
    }
  }
}

async function signIn(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  state.busy = true;
  state.error = '';
  render();

  const { error } = await supabase.auth.signInWithPassword({
    email: normalize(form.get('email')),
    password: String(form.get('password') || ''),
  });

  state.busy = false;
  if (error) state.error = error.message;
  render();
}

async function signOut() {
  state.busy = true;
  render();
  await supabase.auth.signOut({ scope: 'local' });
  state.session = null;
  state.profile = null;
  state.data = emptyData();
  state.busy = false;
  render();
}

async function setVerification(userId, status) {
  const notes =
    status === 'rejected'
      ? window.prompt('Reason for rejection', 'Documents are unclear or incomplete.') || ''
      : '';
  const update = {
    verification_status: status,
    verification_notes: notes,
    verification_reviewed_at: new Date().toISOString(),
  };

  if (status === 'rejected') {
    const retry = new Date();
    retry.setDate(retry.getDate() + 30);
    update.verification_retry_after = retry.toISOString();
  }

  await updateTableRow('profiles', userId, update, `Verification ${status}.`);
}

async function updateProfile(id) {
  const profile = state.data.profiles.find((item) => item.id === id);
  if (!profile) return;
  const full_name = window.prompt('Full name', profile.full_name || '') ?? profile.full_name;
  const phone = window.prompt('Phone', profile.phone || '') ?? profile.phone;
  const country = window.prompt('Country', profile.country || '') ?? profile.country;
  const location = window.prompt('Location', profile.location || '') ?? profile.location;
  await updateTableRow('profiles', id, { full_name, phone, country, location }, 'Profile updated.');
}

async function updateRole(userId, role) {
  await updateTableRow('profiles', userId, { role }, `Role changed to ${role}.`);
}

async function deleteAccount(userId, email) {
  if (state.session?.user?.id === userId) {
    state.error = 'You cannot delete the Admin Account you are currently using.';
    render();
    return;
  }
  const label = email || userId;
  if (!window.confirm(`Permanently delete ${label} from the app and database? This cannot be undone.`)) return;

  await runAction(async () => {
    const result = await adminAction('deleteUser', { userId });
    if (result?.ok === false) throw new Error(result.error || 'Could not delete account.');
    setNotice('Account deleted from Auth and database.');
    await refreshData();
  });
}

async function updateTableRow(table, id, patch, message) {
  state.busy = true;
  state.error = '';
  render();

  try {
    const actionByTable = {
      profiles: 'updateProfile',
      listings: 'upsertListing',
      jobs: 'upsertJob',
    };
    const action = actionByTable[table];
    if (action) {
      await updateManagedRow(table, id, patch, action);
    } else {
      const { error } = await supabase.from(table).update(patch).eq('id', id);
      if (error) throw new Error(error.message);
    }
    setNotice(message);
    await refreshData();
  } catch (error) {
    state.error = error.message || String(error);
  } finally {
    state.busy = false;
    render();
  }
}

async function deleteTableRow(table, id) {
  if (!window.confirm(`Delete this ${table.slice(0, -1)}? This cannot be undone.`)) return;
  state.busy = true;
  state.error = '';
  render();

  try {
    const actionByTable = {
      listings: 'deleteListing',
      jobs: 'deleteJob',
    };
    const action = actionByTable[table];
    if (action) {
      await deleteManagedRow(table, id, action);
    } else {
      const { error } = await supabase.from(table).delete().eq('id', id);
      if (error) throw new Error(error.message);
    }
    setNotice('Record deleted.');
    await refreshData();
  } catch (error) {
    state.error = error.message || String(error);
  } finally {
    state.busy = false;
    render();
  }
}

async function createAccount(role) {
  const email = normalize(window.prompt(`New ${role} email`, ''));
  if (!email) return;
  if (!validEmail(email)) {
    state.error = 'Enter a complete email address.';
    render();
    return;
  }
  const fullName = normalize(window.prompt('Full name', '')) || email.split('@')[0];
  const randomPassword = generateStrongPassword();

  await runAction(async () => {
    await adminAction('createUser', {
      email,
      password: randomPassword,
      role,
      full_name: fullName,
    });
    await adminAction('sendPasswordReset', { email });
    setNotice(`${role} created. Password setup link sent to ${email}.`);
    await refreshData();
  });
}

async function importAccounts(file) {
  if (!file) return;
  await runAction(async () => {
    const rows = file.name.toLowerCase().endsWith('.csv')
      ? parseCsvRows(await file.text())
      : rowsToObjects(await readXlsxFile(file));
    const accounts = rows
      .map((row) => {
        const normalized = Object.fromEntries(
          Object.entries(row).map(([key, value]) => [lower(key).replace(/\s+/g, '_'), value])
        );
        const email = normalize(normalized.email).toLowerCase();
        const role = lower(normalized.role || normalized.account_type || 'customer');
        return {
          email,
          role: role === 'user' ? 'customer' : role,
          full_name: normalize(normalized.full_name || normalized.name || email.split('@')[0]),
          phone: normalize(normalized.phone || normalized.phone_number),
          location: normalize(normalized.location || normalized.city),
          country: normalize(normalized.country),
          password: normalize(normalized.password),
        };
      })
      .filter((account) => account.email);

    if (!accounts.length) throw new Error('No rows with an email column were found.');
    const badEmails = accounts.filter((account) => !validEmail(account.email));
    if (badEmails.length) {
      throw new Error(`Fix invalid email addresses before importing: ${badEmails.map((account) => account.email).slice(0, 5).join(', ')}`);
    }
    const result = await adminAction('bulkCreateUsers', { accounts });
    const created = result.created?.length || 0;
    const failed = result.failed?.length || 0;
    setNotice(`Imported ${created} account${created === 1 ? '' : 's'}${failed ? `, ${failed} failed` : ''}.`);
    if (failed) {
      state.error = result.failed.map((item) => `${item.email}: ${item.error}`).join('\n');
    }
    await refreshData();
  });
}

function rowsToObjects(rows) {
  const [header = [], ...records] = rows;
  const keys = header.map((value) => normalize(value));
  return records.map((record) =>
    Object.fromEntries(keys.map((key, index) => [key, record[index] ?? '']))
  );
}

function parseCsvRows(text) {
  const lines = text.split(/\r?\n/).filter((line) => line.trim().length);
  if (!lines.length) return [];
  const parseLine = (line) => {
    const values = [];
    let value = '';
    let quoted = false;
    for (let i = 0; i < line.length; i += 1) {
      const char = line[i];
      if (char === '"' && line[i + 1] === '"') {
        value += '"';
        i += 1;
      } else if (char === '"') {
        quoted = !quoted;
      } else if (char === ',' && !quoted) {
        values.push(value);
        value = '';
      } else {
        value += char;
      }
    }
    values.push(value);
    return values;
  };
  return rowsToObjects(lines.map(parseLine));
}

async function createListing() {
  const artisanId = await chooseProfileId('artisan', 'Artisan owner email or user id');
  if (!artisanId) return;
  const title = normalize(window.prompt('Listing title', ''));
  if (!title) return;
  const description = normalize(window.prompt('Description', ''));
  const category = normalize(window.prompt('Category', 'General')) || 'General';
  const location = normalize(window.prompt('Location', ''));
  const priceMin = Number(window.prompt('Minimum price', '0') || 0);
  const priceMax = Number(window.prompt('Maximum price', String(priceMin || 0)) || priceMin || 0);
  await runAction(async () => {
    await insertManagedRow('listings', {
      artisan_id: artisanId,
      title,
      description,
      category,
      location,
      price_min: priceMin,
      price_max: priceMax,
    }, 'upsertListing');
    setNotice('Listing created.');
    await refreshData();
  });
}

async function createJob() {
  const createdBy = await chooseProfileId(null, 'Customer/artisan owner email or user id');
  if (!createdBy) return;
  const title = normalize(window.prompt('Job title', ''));
  if (!title) return;
  const description = normalize(window.prompt('Description', ''));
  const location = normalize(window.prompt('Location', ''));
  const budget = Number(window.prompt('Budget', '0') || 0);
  await runAction(async () => {
    await insertManagedRow('jobs', {
      created_by: createdBy,
      title,
      description,
      location,
      budget,
      status: 'active',
    }, 'upsertJob');
    setNotice('Job created.');
    await refreshData();
  });
}

async function chooseProfileId(role, promptText) {
  const value = normalize(window.prompt(promptText, ''));
  if (!value) return '';
  const profile = state.data.profiles.find(
    (item) =>
      (role ? item.role === role : true) &&
      (lower(item.email) === lower(value) || item.id === value)
  );
  if (profile) return profile.id;
  state.error = role ? `No ${role} found for ${value}.` : `No account found for ${value}.`;
  render();
  return '';
}

async function sendPasswordReset(email) {
  if (!email) return;
  await runAction(async () => {
    await adminAction('sendPasswordReset', { email });
    setNotice(`Password reset sent to ${email}.`);
  });
}

async function updateRecoveredPassword(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const password = normalize(form.get('password'));
  const confirmation = normalize(form.get('confirmation'));
  if (password.length < 8) {
    state.error = 'Password must be at least 8 characters.';
    render();
    return;
  }
  if (password !== confirmation) {
    state.error = 'Passwords do not match.';
    render();
    return;
  }
  await runAction(async () => {
    if (!state.session) throw new Error('This recovery link is invalid or has expired. Request a new one.');
    const { error } = await supabase.auth.updateUser({ password });
    if (error) throw error;
    await supabase.auth.signOut();
    window.history.replaceState({}, '', '/');
    state.recoveringPassword = false;
    state.session = null;
    state.profile = null;
    setNotice('Password updated. You can now sign in.');
  });
}

async function randomizePassword(userId, email) {
  if (!window.confirm(`Create a new random password for ${email}?`)) return;
  const password = generateStrongPassword();
  await runAction(async () => {
    await adminAction('setPassword', { userId, password });
    await adminAction('sendPasswordReset', { email });
    setNotice(`New secure password created. Password setup link sent to ${email}.`);
  });
}

async function runAction(fn) {
  state.busy = true;
  state.error = '';
  render();
  try {
    await fn();
  } catch (error) {
    state.error = error.message || String(error);
  } finally {
    state.busy = false;
    render();
  }
}

async function markNotificationRead(id) {
  await updateTableRow('admin_notifications', id, { read_at: new Date().toISOString() }, 'Notification reviewed.');
}

async function setReportStatus(id, status) {
  await updateTableRow('reports', id, { status, reviewed_at: new Date().toISOString() }, `Report marked ${status}.`);
}

async function sendReportResponse(id) {
  const report = state.data.reports.find((item) => item.id === id);
  if (!report?.reporter_id) {
    state.error = 'This report has no reporter account to notify.';
    render();
    return;
  }
  const response = window.prompt('No-reply message to user', 'Your support ticket has been reviewed.');
  if (!response) return;
  await runAction(async () => {
    const { error } = await supabase.from('admin_notifications').insert({
      type: 'admin_response',
      title: 'Support update',
      body: response,
      actor_id: state.session?.user?.id,
      related_user_id: report.reporter_id,
      related_table: 'reports',
      related_id: id,
    });
    if (error) throw new Error(error.message);
    await supabase.from('reports').update({
      status: 'resolved',
      reviewed_at: new Date().toISOString(),
    }).eq('id', id);
    setNotice('No-reply support response sent.');
    await refreshData();
  });
}

function dashboardStats() {
  const profiles = state.data.profiles;
  const artisans = profiles.filter((profile) => profile.role === 'artisan');
  const customers = profiles.filter((profile) => profile.role === 'customer');
  const pending = artisans.filter((profile) => profile.verification_status === 'pending');
  const rejected = artisans.filter((profile) => profile.verification_status === 'rejected');
  const unread = state.data.notifications.filter((item) => !item.read_at);
  const openJobs = state.data.jobs.filter((job) => (job.status || 'active') === 'active');
  const reports = visibleReports();

  return [
    ['Total users', profiles.length, `${customers.length} customers`],
    ['Artisans', artisans.length, `${pending.length} pending verification`],
    ['Listings', state.data.listings.length, 'Editable service listings'],
    ['Open jobs', openJobs.length, `${state.data.bids.length} bids`],
    ['Reports', reports.length, `${unread.length} unread admin notices`],
    ['Rejected verification', rejected.length, 'Retry lock handled in app'],
  ];
}

function renderShell(content) {
  const profile = state.profile;
  return `
    <div class="shell">
      <aside class="sidebar">
        <div class="brand">
          <img src="/prosme_logo.png" alt="ProSME" />
          <div>
            <strong>ProSME</strong>
            <span>Admin Portal</span>
          </div>
        </div>
        <nav>
          ${tabs
            .map(
              ([id, label]) =>
                `<button class="nav-item ${state.tab === id ? 'active' : ''}" data-tab="${id}">${label}</button>`
            )
            .join('')}
        </nav>
        <div class="account">
          <span>${esc(profile?.email || state.session?.user?.email || '')}</span>
          ${roleBadge(profile?.role)}
          <button class="ghost small" data-action="sign-out">Sign out</button>
        </div>
      </aside>
      <main class="main">
        <header class="topbar">
          <div>
            <p>Admin only</p>
            <h1>${esc(tabs.find(([id]) => id === state.tab)?.[1] || 'Overview')}</h1>
          </div>
          <div class="actions">
            <button class="ghost" data-action="print">Print</button>
            <button class="ghost" data-action="refresh">Refresh</button>
          </div>
        </header>
        ${state.notice ? `<div class="notice">${esc(state.notice)}</div>` : ''}
        ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
        <div class="mobile-account">
          <div>
            <strong>${esc(profile?.email || state.session?.user?.email || '')}</strong>
            ${roleBadge(profile?.role)}
          </div>
          <button class="ghost small" data-action="sign-out">Sign out</button>
        </div>
        ${Object.keys(state.tableErrors).length ? renderTableErrors() : ''}
        ${content}
      </main>
    </div>
  `;
}

function renderTableErrors() {
  return `
    <details class="warning" open>
      <summary>Some Supabase tables or policies need attention</summary>
      <ul>
        ${Object.entries(state.tableErrors)
          .map(([name, message]) => `<li><strong>${esc(name)}:</strong> ${esc(message)}</li>`)
          .join('')}
      </ul>
    </details>
  `;
}

function renderOverview() {
  const stats = dashboardStats();
  const recentNotifications = state.data.notifications.slice(0, 8);
  const pending = pendingVerifications().slice(0, 6);
  return `
    <section class="stat-grid">
      ${stats
        .map(
          ([label, value, hint]) => `
          <article class="stat-card">
            <span>${esc(label)}</span>
            <strong>${esc(value)}</strong>
            <small>${esc(hint)}</small>
          </article>`
        )
        .join('')}
    </section>
    <section class="grid two">
      <article class="panel">
        <div class="panel-head">
          <h2>Pending Verifications</h2>
          <button class="link" data-tab="verifications">View all</button>
        </div>
        ${pending.length ? renderVerificationList(pending) : '<p class="empty">No pending artisan verifications.</p>'}
      </article>
      <article class="panel">
        <div class="panel-head">
          <h2>Recent Activity</h2>
          <button class="link" data-tab="reports">Reports</button>
        </div>
        ${recentNotifications.length ? renderActivityList(recentNotifications) : '<p class="empty">No admin activity yet.</p>'}
      </article>
    </section>
  `;
}

function pendingVerifications() {
  return state.data.profiles.filter(
    (profile) => profile.role === 'artisan' && profile.verification_status === 'pending'
  );
}

function controls({ roleFilter = true, statusFilter = true } = {}) {
  return `
    <div class="toolbar">
      <input data-filter="q" type="search" placeholder="Search records" value="${esc(state.filters.q)}" />
      ${
        roleFilter
          ? `<select data-filter="role">
              ${['all', 'customer', 'artisan', 'admin']
                .map((role) => `<option value="${role}" ${state.filters.role === role ? 'selected' : ''}>${role}</option>`)
                .join('')}
            </select>`
          : ''
      }
      ${
        statusFilter
          ? `<select data-filter="status">
              ${['all', 'pending', 'accepted', 'rejected', 'verified', 'active', 'in_progress', 'open', 'reviewing', 'resolved', 'completed', 'cancelled']
                .map(
                  (status) => `<option value="${status}" ${state.filters.status === status ? 'selected' : ''}>${status}</option>`
                )
                .join('')}
            </select>`
          : ''
      }
      <select data-filter="sort">
        <option value="newest" ${state.filters.sort === 'newest' ? 'selected' : ''}>Newest</option>
        <option value="oldest" ${state.filters.sort === 'oldest' ? 'selected' : ''}>Oldest</option>
        <option value="name" ${state.filters.sort === 'name' ? 'selected' : ''}>Name A-Z</option>
      </select>
    </div>
  `;
}

function filterRows(rows, fields) {
  const q = lower(state.filters.q);
  const filtered = rows.filter((row) => {
    if (state.filters.role !== 'all' && 'role' in row && row.role !== state.filters.role) return false;
    const status = row.verification_status || row.status || (row.read_at ? 'resolved' : 'open');
    const hasStatus = 'verification_status' in row || 'status' in row || 'read_at' in row;
    if (state.filters.status !== 'all' && hasStatus && status !== state.filters.status) return false;
    if (!q) return true;
    return fields.some((field) => lower(row[field]).includes(q));
  });

  return filtered.sort((a, b) => {
    if (state.filters.sort === 'oldest') return String(a.created_at || '').localeCompare(String(b.created_at || ''));
    if (state.filters.sort === 'name') {
      const aName = a.full_name || a.title || a.email || '';
      const bName = b.full_name || b.title || b.email || '';
      return aName.localeCompare(bName);
    }
    return String(b.created_at || '').localeCompare(String(a.created_at || ''));
  });
}

function renderVerificationList(items) {
  return `
    <div class="list">
      ${items
        .map(
          (profile) => `
        <div class="list-row">
          <div>
            <strong>${esc(profile.full_name || profile.email || 'Unnamed artisan')}</strong>
            <span>${esc(profile.email || 'No email')} ${profile.location ? `- ${esc(profile.location)}` : ''}</span>
            <small>Submitted ${dateText(profile.verification_submitted_at || profile.created_at)}</small>
          </div>
          <div class="row-actions">
            ${documentLinks(profile)}
            <button class="approve" data-verify="verified" data-id="${esc(profile.id)}">Approve</button>
            <button class="reject" data-verify="rejected" data-id="${esc(profile.id)}">Reject</button>
          </div>
        </div>`
        )
        .join('')}
    </div>
  `;
}

function documentLinks(profile) {
  const links = [
    ['Front ID', profile.national_id_front_url || profile.national_id_url],
    ['Back ID', profile.national_id_back_url],
    ...((profile.business_certificate_urls || []).map((url, index) => [`Certificate ${index + 1}`, url])),
  ].filter(([, url]) => Boolean(url));

  if (!links.length) return '<span class="muted">No documents</span>';
  return links
    .map(([label, url]) => `<a class="ghost small" href="${esc(url)}" target="_blank" rel="noreferrer">${esc(label)}</a>`)
    .join('');
}

function renderActivityList(items) {
  return `
    <div class="list compact">
      ${items
        .map(
          (item) => `
        <details class="detail-row">
          <summary>
            <span>
              <strong>${esc(item.title || item.type || 'Activity')}</strong>
              <small>${dateText(item.created_at)}</small>
            </span>
            ${item.read_at ? '<span class="badge">Reviewed</span>' : `<button class="ghost small" data-read="${esc(item.id)}">Mark read</button>`}
          </summary>
          <p>${esc(item.body || '')}</p>
          <small>Related: ${esc(item.related_table || '')} ${esc(item.related_id || '')}</small>
        </details>`
        )
        .join('')}
    </div>
  `;
}

function renderProfiles(filterRole = null) {
  const rows = filterRows(state.data.profiles, ['full_name', 'email', 'phone', 'location', 'country', 'tenant_id']);
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Accounts</h2>
        <div class="row-actions">
          <button class="primary compact-button" data-create-role="customer">Create user</button>
          <button class="primary compact-button" data-create-role="artisan">Create artisan</button>
          <button class="primary compact-button" data-create-role="admin">Create admin</button>
          <label class="ghost small file-action">
            Import Excel
            <input type="file" accept=".xlsx,.csv" data-import-accounts />
          </label>
        </div>
      </div>
      ${controls({ roleFilter: true })}
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Phone</th>
              <th>Role</th>
              <th>Verification</th>
              <th>Tenant</th>
              <th>Joined</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            ${rows.map(renderProfileRow).join('') || tableEmpty(8)}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function renderProfileRow(profile) {
  return `
    <tr>
      <td>
        <strong>${esc(profile.full_name || 'Unnamed')}</strong>
        <small>${esc(profile.location || profile.country || '')}</small>
      </td>
      <td>${esc(profile.email || '')}</td>
      <td>${esc(profile.phone || '')}</td>
      <td>${roleBadge(profile.role)}</td>
      <td>${statusBadge(profile.verification_status)}</td>
      <td>${esc(profile.tenant_id || 'default')}</td>
      <td>${dateText(profile.created_at)}</td>
      <td class="row-actions">
        <button class="ghost small" data-edit-profile="${esc(profile.id)}">Edit</button>
        <button class="ghost small" data-reset-email="${esc(profile.email || '')}">Reset</button>
        <button class="ghost small" data-random-password="${esc(profile.id)}" data-email="${esc(profile.email || '')}">Random password</button>
        <button class="reject small" data-delete-account="${esc(profile.id)}" data-email="${esc(profile.email || '')}">Delete</button>
        <select data-role-user="${esc(profile.id)}">
          ${['customer', 'artisan', 'admin']
            .map((role) => `<option value="${role}" ${profile.role === role ? 'selected' : ''}>${role}</option>`)
            .join('')}
        </select>
      </td>
    </tr>
  `;
}

function renderVerifications() {
  const rows = filterRows(
    state.data.profiles.filter((profile) => profile.role === 'artisan'),
    ['full_name', 'email', 'location', 'verification_notes']
  );
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Artisan Verification Queue</h2>
        <span class="badge">${pendingVerifications().length} pending</span>
      </div>
      ${controls({ roleFilter: false })}
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Artisan</th>
              <th>Status</th>
              <th>Documents</th>
              <th>Notes</th>
              <th>Submitted</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            ${rows
              .map(
                (profile) => `
                <tr>
                  <td><strong>${esc(profile.full_name || profile.email || 'Unnamed')}</strong><small>${esc(profile.email || '')}</small></td>
                  <td>${statusBadge(profile.verification_status)}</td>
                  <td class="doc-cell">${documentLinks(profile)}</td>
                  <td>${esc(profile.verification_notes || '')}</td>
                  <td>${dateText(profile.verification_submitted_at || profile.created_at)}</td>
                  <td class="row-actions">
                    <button class="approve small" data-verify="verified" data-id="${esc(profile.id)}">Approve</button>
                    <button class="reject small" data-verify="rejected" data-id="${esc(profile.id)}">Reject</button>
                  </td>
                </tr>`
              )
              .join('') || tableEmpty(6)}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function visibleReports() {
  const reportRows = state.data.reports.length
    ? state.data.reports
    : state.data.notifications.filter((item) => String(item.type || '').includes('report'));
  return filterRows(reportRows, ['type', 'category', 'title', 'reason', 'body', 'description', 'message', 'status']);
}

function renderReports() {
  const reports = visibleReports();
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Reports and admin Notifications</h2>
        <span class="badge">${reports.length || state.data.notifications.length} records</span>
      </div>
      ${controls({ roleFilter: false })}
      ${reports.length ? renderReportRows(reports) : renderActivityList(state.data.notifications)}
    </section>
  `;
}

function renderReportRows(reports) {
  return `
    <div class="list">
      ${reports
        .map(
          (item) => `
          <details class="detail-row">
            <summary>
              <span>
                <strong>${esc(item.title || item.reason || item.type || 'Report')}</strong>
                <small>${esc(item.body || item.description || item.message || '')}</small>
              </span>
              ${statusBadge(item.status || (item.read_at ? 'resolved' : 'open'))}
            </summary>
            <dl class="details-grid">
              <dt>Type</dt><dd>${esc(item.type || item.category || 'report')}</dd>
              <dt>Reporter</dt><dd>${esc(item.reporter_id || item.actor_id || '')}</dd>
              <dt>Reported user</dt><dd>${esc(item.reported_user_id || item.related_user_id || '')}</dd>
              <dt>Related</dt><dd>${esc(item.related_table || '')} ${esc(item.related_id || '')}</dd>
              <dt>Date</dt><dd>${dateText(item.created_at)}</dd>
              <dt>Details</dt><dd>${esc(item.body || item.description || item.message || '')}</dd>
            </dl>
            <div class="row-actions">
              ${item.id ? `<button class="ghost small" data-report-status="reviewing" data-id="${esc(item.id)}">Reviewing</button>` : ''}
              ${item.id ? `<button class="approve small" data-report-status="resolved" data-id="${esc(item.id)}">Resolve</button>` : ''}
              ${item.reporter_id ? `<button class="ghost small" data-report-response="${esc(item.id)}">Send response</button>` : ''}
              ${item.read_at || !item.id ? '' : `<button class="ghost small" data-read="${esc(item.id)}">Mark read</button>`}
            </div>
          </details>`
        )
        .join('')}
    </div>
  `;
}

function profileFor(id) {
  return state.data.profiles.find((profile) => profile.id === id) || null;
}

function profileLabel(id, fallback = 'Unknown account') {
  const profile = profileFor(id);
  return normalize(profile?.full_name) || normalize(profile?.email) || fallback;
}

function jobFor(id) {
  return state.data.jobs.find((job) => job.id === id) || null;
}

function walletForBid(id) {
  return state.data.walletTransactions.find(
    (transaction) => transaction.bid_id === id && transaction.event_type === 'bid_accepted'
  ) || null;
}

function threadForParticipants(customerId, artisanId) {
  return state.data.threads.find(
    (thread) => thread.user_id === customerId && thread.artisan_id === artisanId
  ) || null;
}

function messagePreview(message) {
  if (message?.type !== 'invoice') return normalize(message?.content) || 'Empty message';
  try {
    const invoice = JSON.parse(message.content || '{}');
    return `Invoice ${invoice.invoice_number || ''}`.trim();
  } catch (_) {
    return 'Invoice';
  }
}

function conversationDetails(thread) {
  if (!thread) return '<span class="muted">No conversation</span>';
  const messages = state.data.messages
    .filter((message) => message.thread_id === thread.id)
    .sort((a, b) => new Date(a.created_at || 0) - new Date(b.created_at || 0));
  const visible = messages.slice(-20);
  return `
    <details class="conversation-detail">
      <summary>${messages.length} message${messages.length === 1 ? '' : 's'}</summary>
      <div class="conversation-log">
        ${
          visible.length
            ? visible
                .map(
                  (message) => `
                    <div class="message-line">
                      <strong>${esc(profileLabel(message.sender_id, 'Account'))}</strong>
                      <span>${esc(dateText(message.created_at))} · ${esc(message.type || 'text')}</span>
                      <p>${esc(messagePreview(message))}</p>
                    </div>`
                )
                .join('')
            : '<p class="muted">Conversation has no messages.</p>'
        }
      </div>
    </details>`;
}

function trackedBidRows() {
  const q = lower(state.filters.q);
  const rows = state.data.bids.map((bid) => {
    const job = jobFor(bid.job_id);
    const customerId = job?.created_by || '';
    const wallet = walletForBid(bid.id);
    const thread = threadForParticipants(customerId, bid.artisan_id);
    return {
      ...bid,
      job,
      wallet,
      thread,
      customerId,
      customerName: profileLabel(customerId, wallet?.customer_name || 'Customer'),
      artisanName: profileLabel(bid.artisan_id, wallet?.artisan_name || 'Artisan'),
    };
  });
  const filtered = rows.filter((row) => {
    if (state.filters.status !== 'all' && row.status !== state.filters.status) return false;
    if (!q) return true;
    return [
      row.job?.title,
      row.job?.location,
      row.customerName,
      row.artisanName,
      row.status,
      row.wallet?.invoice_number,
      row.message,
    ].some((value) => lower(value).includes(q));
  });
  filtered.sort((a, b) => {
    if (state.filters.sort === 'oldest') {
      return new Date(a.created_at || 0) - new Date(b.created_at || 0);
    }
    if (state.filters.sort === 'name') {
      return normalize(a.job?.title).localeCompare(normalize(b.job?.title));
    }
    return new Date(b.created_at || 0) - new Date(a.created_at || 0);
  });
  return filtered;
}

function userMoneyFlow() {
  const flow = new Map();
  const ensure = (id) => {
    if (!flow.has(id)) {
      const profile = profileFor(id);
      flow.set(id, {
        id,
        name: profileLabel(id),
        email: profile?.email || '',
        role: profile?.role || 'unknown',
        spent: 0,
        received: 0,
        jobs: new Set(),
      });
    }
    return flow.get(id);
  };
  state.data.walletTransactions
    .filter((transaction) => transaction.event_type === 'bid_accepted')
    .forEach((transaction) => {
      const amount = Number(transaction.amount || 0);
      if (transaction.user_id) {
        const customer = ensure(transaction.user_id);
        customer.spent += amount;
        if (transaction.job_id) customer.jobs.add(transaction.job_id);
      }
      if (transaction.artisan_id) {
        const artisan = ensure(transaction.artisan_id);
        artisan.received += amount;
        if (transaction.job_id) artisan.jobs.add(transaction.job_id);
      }
    });
  return [...flow.values()].sort((a, b) => b.spent + b.received - (a.spent + a.received));
}

function renderBidTracking() {
  const rows = trackedBidRows();
  const accepted = state.data.bids.filter((bid) => bid.status === 'accepted');
  const pending = state.data.bids.filter((bid) => bid.status === 'pending');
  const acceptedAmount = accepted.reduce(
    (sum, bid) => sum + Number(walletForBid(bid.id)?.amount ?? bid.amount ?? 0),
    0
  );
  const flowRows = userMoneyFlow();
  const linkedThreads = new Set(rows.map((row) => row.thread?.id).filter(Boolean));
  return `
    <section class="stat-grid bid-stat-grid">
      <article class="stat-card">
        <span>Total bids</span>
        <strong>${state.data.bids.length}</strong>
        <small>${pending.length} awaiting decisions</small>
      </article>
      <article class="stat-card">
        <span>Accepted value</span>
        <strong>${money(acceptedAmount)}</strong>
        <small>${accepted.length} accepted bids</small>
      </article>
      <article class="stat-card">
        <span>Wallet records</span>
        <strong>${state.data.walletTransactions.length}</strong>
        <small>Accepted spending and earnings</small>
      </article>
      <article class="stat-card">
        <span>Bid conversations</span>
        <strong>${linkedThreads.size}</strong>
        <small>${state.data.messages.length} messages loaded</small>
      </article>
    </section>

    <section class="panel">
      <div class="panel-head">
        <h2>User spending and artisan earnings</h2>
        <span class="badge">${flowRows.length} accounts</span>
      </div>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Account</th>
              <th>Role</th>
              <th>Customer spending</th>
              <th>Artisan earnings</th>
              <th>Accepted jobs</th>
            </tr>
          </thead>
          <tbody>
            ${
              flowRows
                .map(
                  (item) => `
                    <tr>
                      <td><strong>${esc(item.name)}</strong><small>${esc(item.email)}</small></td>
                      <td>${roleBadge(item.role)}</td>
                      <td>${money(item.spent)}</td>
                      <td class="money-positive">${money(item.received)}</td>
                      <td>${item.jobs.size}</td>
                    </tr>`
                )
                .join('') || tableEmpty(5)
            }
          </tbody>
        </table>
      </div>
    </section>

    <section class="panel">
      <div class="panel-head">
        <h2>Bid ledger and conversations</h2>
        <span class="badge">${rows.length} shown</span>
      </div>
      ${controls({ roleFilter: false })}
      <div class="table-wrap">
        <table class="bid-ledger">
          <thead>
            <tr>
              <th>Job</th>
              <th>Customer</th>
              <th>Artisan</th>
              <th>Bid</th>
              <th>Wallet / invoice</th>
              <th>Conversation</th>
              <th>Submitted</th>
            </tr>
          </thead>
          <tbody>
            ${
              rows
                .map(
                  (row) => `
                    <tr>
                      <td>
                        <strong>${esc(row.job?.title || 'Deleted job')}</strong>
                        <small>${esc(row.job?.location || '')}</small>
                      </td>
                      <td><strong>${esc(row.customerName)}</strong><small>${esc(profileFor(row.customerId)?.email || '')}</small></td>
                      <td><strong>${esc(row.artisanName)}</strong><small>${esc(profileFor(row.artisan_id)?.email || '')}</small></td>
                      <td>
                        <strong>${money(row.amount)}</strong>
                        ${statusBadge(row.status)}
                        <small>${esc(row.message || '')}</small>
                      </td>
                      <td>
                        ${
                          row.wallet
                            ? `<strong>${money(row.wallet.amount)}</strong><small>${esc(row.wallet.invoice_number || '')}</small>${statusBadge(row.wallet.work_status || row.wallet.payment_status || 'accepted')}`
                            : '<span class="badge badge-orange">No wallet record</span>'
                        }
                      </td>
                      <td>${conversationDetails(row.thread)}</td>
                      <td>${dateText(row.created_at)}</td>
                    </tr>`
                )
                .join('') || tableEmpty(7)
            }
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function renderJobs() {
  const rows = filterRows(state.data.jobs, ['title', 'description', 'location', 'status', 'tenant_id']);
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Jobs and Bids</h2>
        <div class="row-actions">
          <span class="badge">${rows.length} jobs</span>
          <button class="primary compact-button" data-create-job>Create job</button>
        </div>
      </div>
      ${controls({ roleFilter: false })}
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Job</th>
              <th>Location</th>
              <th>Budget</th>
              <th>Status</th>
              <th>Bids</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            ${rows
              .map((job) => {
                const bidCount = state.data.bids.filter((bid) => bid.job_id === job.id).length;
                return `
                  <tr>
                    <td><strong>${esc(job.title)}</strong><small>${esc(job.description || '')}</small></td>
                    <td>${esc(job.location || '')}</td>
                    <td>${money(job.budget)}</td>
                    <td>${statusBadge(job.status || 'active')}</td>
                    <td>${bidCount}</td>
                    <td>${dateText(job.created_at)}</td>
                    <td class="row-actions">
                      <button class="ghost small" data-edit-job="${esc(job.id)}">Edit</button>
                      <button class="reject small" data-delete-row="jobs" data-id="${esc(job.id)}">Delete</button>
                    </td>
                  </tr>`;
              })
              .join('') || tableEmpty(7)}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function renderListings() {
  const rows = filterRows(state.data.listings, ['title', 'description', 'category', 'location', 'tenant_id']);
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Listings</h2>
        <div class="row-actions">
          <span class="badge">${rows.length} listings</span>
          <button class="primary compact-button" data-create-listing>Create listing</button>
        </div>
      </div>
      ${controls({ roleFilter: false, statusFilter: false })}
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Listing</th>
              <th>Category</th>
              <th>Location</th>
              <th>Price</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            ${rows
              .map(
                (listing) => `
                <tr>
                  <td><strong>${esc(listing.title)}</strong><small>${esc(listing.description || '')}</small></td>
                  <td>${esc(listing.category || 'Other')}</td>
                  <td>${esc(listing.location || '')}</td>
                  <td>${money(listing.price_min)} - ${money(listing.price_max)}</td>
                  <td>${dateText(listing.created_at)}</td>
                  <td class="row-actions">
                    <button class="ghost small" data-edit-listing="${esc(listing.id)}">Edit</button>
                    <button class="reject small" data-delete-row="listings" data-id="${esc(listing.id)}">Delete</button>
                  </td>
                </tr>`
              )
              .join('') || tableEmpty(6)}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

async function editListing(id) {
  const listing = state.data.listings.find((item) => item.id === id);
  if (!listing) return;
  const title = window.prompt('Listing title', listing.title || '') ?? listing.title;
  const category = window.prompt('Category', listing.category || '') ?? listing.category;
  const location = window.prompt('Location', listing.location || '') ?? listing.location;
  const description = window.prompt('Description', listing.description || '') ?? listing.description;
  const price_min = Number(window.prompt('Minimum price', listing.price_min ?? 0) ?? listing.price_min ?? 0);
  const price_max = Number(window.prompt('Maximum price', listing.price_max ?? price_min) ?? listing.price_max ?? price_min);
  await updateTableRow('listings', id, { title, category, location, description, price_min, price_max }, 'Listing updated.');
}

async function editJob(id) {
  const job = state.data.jobs.find((item) => item.id === id);
  if (!job) return;
  const title = window.prompt('Job title', job.title || '') ?? job.title;
  const status = window.prompt('Status', job.status || 'active') ?? job.status;
  const location = window.prompt('Location', job.location || '') ?? job.location;
  const description = window.prompt('Description', job.description || '') ?? job.description;
  const budget = Number(window.prompt('Budget', job.budget ?? 0) ?? job.budget ?? 0);
  await updateTableRow('jobs', id, { title, status, location, description, budget }, 'Job updated.');
}

function renderSettings() {
  return `
    <section class="panel narrow">
      <h2>Vercel Environment</h2>
      <div class="setting-row">
        <span>Supabase URL</span>
        <strong>${supabaseUrl ? 'Configured' : 'Missing'}</strong>
      </div>
      <div class="setting-row">
        <span>Supabase publishable key</span>
        <strong>${supabaseKey ? 'Configured' : 'Missing'}</strong>
      </div>
      <div class="callout">
        Keep service role keys out of Vercel frontend variables. Account creation and password changes are handled by the <code>admin-dashboard</code> Edge Function.
      </div>
      <h2>Admin access</h2>
      <p class="muted">
        Only accounts with <code>role = 'admin'</code> in <code>public.profiles</code> can continue. Artisan and user accounts are signed out immediately.
      </p>
    </section>
  `;
}

function tableEmpty(cols) {
  return `<tr><td colspan="${cols}" class="empty">No records found.</td></tr>`;
}

function renderLogin() {
  return `
    <div class="login-page">
      <form class="login-card" id="login-form">
        <img src="/prosme_logo.png" alt="ProSME" />
        <h1>ProSME Admin Dashboard</h1>
        <p>Admin accounts only.</p>
        ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
        ${state.notice ? `<div class="notice">${esc(state.notice)}</div>` : ''}
        <label>
          Email
          <input name="email" type="email" autocomplete="email" placeholder="Email address" required />
        </label>
        <label>
          Password
          <input name="password" type="password" autocomplete="current-password" required />
        </label>
        <button class="primary" ${state.busy ? 'disabled' : ''}>${state.busy ? 'Signing in...' : 'Sign in'}</button>
        <small>Use Supabase Auth. The web dashboard does not store passwords.</small>
      </form>
    </div>
  `;
}

function renderPasswordRecovery() {
  return `
    <div class="login-page">
      <form class="login-card" id="password-recovery-form">
        <img src="/prosme_logo.png" alt="ProSME" />
        <h1>Choose a new password</h1>
        <p>Enter a secure password for your ProSME account.</p>
        ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
        ${!state.session && !state.loading ? '<div class="warning">This recovery link is invalid or has expired. Request another reset email.</div>' : ''}
        <label>
          New password
          <input name="password" type="password" autocomplete="new-password" minlength="8" required />
        </label>
        <label>
          Confirm password
          <input name="confirmation" type="password" autocomplete="new-password" minlength="8" required />
        </label>
        <button class="primary" ${state.busy || !state.session ? 'disabled' : ''}>${state.busy ? 'Updating...' : 'Update password'}</button>
      </form>
    </div>
  `;
}

function renderContent() {
  if (state.loading) {
    return renderShell('<div class="loading">Loading ProSME dashboard...</div>');
  }

  switch (state.tab) {
    case 'users':
      return renderShell(renderProfiles());
    case 'verifications':
      return renderShell(renderVerifications());
    case 'reports':
      return renderShell(renderReports());
    case 'bidTracking':
      return renderShell(renderBidTracking());
    case 'jobs':
      return renderShell(renderJobs());
    case 'listings':
      return renderShell(renderListings());
    case 'settings':
      return renderShell(renderSettings());
    default:
      return renderShell(renderOverview());
  }
}

function render() {
  if (state.recoveringPassword) {
    app.innerHTML = renderPasswordRecovery();
  } else if (!hasConfig || !state.session || state.profile?.role !== 'admin') {
    app.innerHTML = renderLogin();
  } else {
    app.innerHTML = renderContent();
  }
  bindEvents();
}

function bindEvents() {
  document.querySelector('#login-form')?.addEventListener('submit', signIn);
  document.querySelector('#password-recovery-form')?.addEventListener('submit', updateRecoveredPassword);

  document.querySelectorAll('[data-tab]').forEach((button) => {
    button.addEventListener('click', () => {
      state.tab = button.dataset.tab;
      render();
    });
  });

  document.querySelectorAll('[data-action="sign-out"]').forEach((button) => button.addEventListener('click', signOut));
  document.querySelector('[data-action="print"]')?.addEventListener('click', () => window.print());
  document.querySelector('[data-action="refresh"]')?.addEventListener('click', async () => {
    state.loading = true;
    render();
    await refreshData();
    state.loading = false;
    setNotice('Dashboard refreshed.');
    render();
  });

  document.querySelectorAll('[data-filter]').forEach((input) => {
    input.addEventListener('input', () => {
      state.filters[input.dataset.filter] = input.value;
      render();
    });
    input.addEventListener('change', () => {
      state.filters[input.dataset.filter] = input.value;
      render();
    });
  });

  document.querySelectorAll('[data-verify]').forEach((button) => {
    button.addEventListener('click', () => setVerification(button.dataset.id, button.dataset.verify));
  });

  document.querySelectorAll('[data-read]').forEach((button) => {
    button.addEventListener('click', (event) => {
      event.preventDefault();
      markNotificationRead(button.dataset.read);
    });
  });

  document.querySelectorAll('[data-report-status]').forEach((button) => {
    button.addEventListener('click', (event) => {
      event.preventDefault();
      setReportStatus(button.dataset.id, button.dataset.reportStatus);
    });
  });

  document.querySelectorAll('[data-report-response]').forEach((button) => {
    button.addEventListener('click', (event) => {
      event.preventDefault();
      sendReportResponse(button.dataset.reportResponse);
    });
  });

  document.querySelectorAll('[data-role-user]').forEach((select) => {
    select.addEventListener('change', () => updateRole(select.dataset.roleUser, select.value));
  });

  document.querySelectorAll('[data-edit-profile]').forEach((button) => {
    button.addEventListener('click', () => updateProfile(button.dataset.editProfile));
  });

  document.querySelectorAll('[data-reset-email]').forEach((button) => {
    button.addEventListener('click', () => sendPasswordReset(button.dataset.resetEmail));
  });

  document.querySelectorAll('[data-random-password]').forEach((button) => {
    button.addEventListener('click', () => randomizePassword(button.dataset.randomPassword, button.dataset.email));
  });

  document.querySelectorAll('[data-delete-account]').forEach((button) => {
    button.addEventListener('click', () => deleteAccount(button.dataset.deleteAccount, button.dataset.email));
  });

  document.querySelectorAll('[data-create-role]').forEach((button) => {
    button.addEventListener('click', () => createAccount(button.dataset.createRole));
  });

  document.querySelector('[data-import-accounts]')?.addEventListener('change', (event) => {
    importAccounts(event.target.files?.[0]);
    event.target.value = '';
  });

  document.querySelector('[data-create-listing]')?.addEventListener('click', createListing);
  document.querySelector('[data-create-job]')?.addEventListener('click', createJob);

  document.querySelectorAll('[data-edit-listing]').forEach((button) => {
    button.addEventListener('click', () => editListing(button.dataset.editListing));
  });

  document.querySelectorAll('[data-edit-job]').forEach((button) => {
    button.addEventListener('click', () => editJob(button.dataset.editJob));
  });

  document.querySelectorAll('[data-delete-row]').forEach((button) => {
    button.addEventListener('click', () => deleteTableRow(button.dataset.deleteRow, button.dataset.id));
  });
}

init();
