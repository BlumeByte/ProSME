import { createClient } from '@supabase/supabase-js';
import './styles.css';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
const app = document.querySelector('#app');

const emptyData = () => ({
  profiles: [],
  listings: [],
  jobs: [],
  bids: [],
  ratings: [],
  notifications: [],
  reports: [],
});

const state = {
  session: null,
  profile: null,
  tab: 'overview',
  loading: true,
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
  ['artisans', 'Artisans'],
  ['verifications', 'Verifications'],
  ['reports', 'Reports'],
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
  const map = {
    developer: 'badge badge-purple',
    admin: 'badge badge-blue',
    artisan: 'badge badge-teal',
    customer: 'badge',
  };
  return `<span class="${map[role] || 'badge'}">${esc(role || 'customer')}</span>`;
};

const statusBadge = (status) => {
  const map = {
    verified: 'badge badge-green',
    pending: 'badge badge-orange',
    rejected: 'badge badge-red',
    active: 'badge badge-green',
    completed: 'badge badge-blue',
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

  supabase.auth.onAuthStateChange((_event, session) => {
    state.session = session;
    if (!session) {
      state.profile = null;
      state.data = emptyData();
      state.loading = false;
      render();
      return;
    }
    loadDashboard();
  });

  if (state.session) {
    await loadDashboard();
  } else {
    state.loading = false;
    render();
  }
}

async function loadDashboard() {
  if (!state.session?.user) {
    state.loading = false;
    render();
    return;
  }

  state.loading = true;
  state.error = '';
  render();

  const userId = state.session.user.id;
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('id,full_name,email,role,verification_status,tenant_id,created_at')
    .eq('id', userId)
    .maybeSingle();

  if (profileError) {
    state.error = `Could not load your developer profile: ${profileError.message}`;
    state.loading = false;
    render();
    return;
  }

  state.profile = profile;

  if (profile?.role !== 'developer') {
    await supabase.auth.signOut();
    state.session = null;
    state.profile = null;
    state.error = 'Only developer accounts can open this dashboard.';
    state.loading = false;
    render();
    return;
  }

  await refreshData();
  state.loading = false;
  render();
}

async function refreshData() {
  state.tableErrors = {};

  const [profiles, listings, jobs, bids, ratings, notifications, reports] = await Promise.all([
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

  state.data = { profiles, listings, jobs, bids, ratings, notifications, reports };
}

async function developerAction(action, payload = {}) {
  const { data, error } = await supabase.functions.invoke('developer-admin', {
    body: { action, ...payload },
  });
  if (error) throw new Error(error.message);
  if (data?.error) throw new Error(data.error);
  return data;
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

async function updateTableRow(table, id, patch, message) {
  state.busy = true;
  state.error = '';
  render();
  const { error } = await supabase.from(table).update(patch).eq('id', id);
  state.busy = false;

  if (error) {
    state.error = error.message;
  } else {
    setNotice(message);
    await refreshData();
  }
  render();
}

async function deleteTableRow(table, id) {
  if (!window.confirm(`Delete this ${table.slice(0, -1)}? This cannot be undone.`)) return;
  state.busy = true;
  state.error = '';
  render();
  const { error } = await supabase.from(table).delete().eq('id', id);
  state.busy = false;

  if (error) {
    state.error = error.message;
  } else {
    setNotice('Record deleted.');
    await refreshData();
  }
  render();
}

async function createAccount(role) {
  const email = normalize(window.prompt(`New ${role} email`, ''));
  if (!email) return;
  const fullName = normalize(window.prompt('Full name', '')) || email.split('@')[0];
  const randomPassword = crypto.getRandomValues(new Uint32Array(2)).join('-') + 'Aa!';

  await runAction(async () => {
    await developerAction('createUser', {
      email,
      password: randomPassword,
      role,
      full_name: fullName,
    });
    setNotice(`${role} created. Temporary password: ${randomPassword}`);
    await refreshData();
  });
}

async function sendPasswordReset(email) {
  if (!email) return;
  await runAction(async () => {
    await developerAction('sendPasswordReset', { email });
    setNotice(`Password reset sent to ${email}.`);
  });
}

async function randomizePassword(userId, email) {
  if (!window.confirm(`Create a new random password for ${email}?`)) return;
  const password = crypto.getRandomValues(new Uint32Array(2)).join('-') + 'Aa!';
  await runAction(async () => {
    await developerAction('setPassword', { userId, password });
    setNotice(`New temporary password for ${email}: ${password}`);
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
            <span>Developer Portal</span>
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
            <p>Developer only</p>
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
              ${['all', 'customer', 'artisan', 'admin', 'developer']
                .map((role) => `<option value="${role}" ${state.filters.role === role ? 'selected' : ''}>${role}</option>`)
                .join('')}
            </select>`
          : ''
      }
      ${
        statusFilter
          ? `<select data-filter="status">
              ${['all', 'pending', 'verified', 'rejected', 'active', 'open', 'reviewing', 'resolved', 'completed', 'cancelled']
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
  const source = filterRole
    ? state.data.profiles.filter((profile) => profile.role === filterRole)
    : state.data.profiles;
  const rows = filterRows(source, ['full_name', 'email', 'phone', 'location', 'country', 'tenant_id']);
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>${filterRole === 'artisan' ? 'Artisan Accounts' : 'User Accounts'}</h2>
        <div class="row-actions">
          <button class="primary compact-button" data-create-role="customer">Create user</button>
          <button class="primary compact-button" data-create-role="artisan">Create artisan</button>
          <button class="primary compact-button" data-create-role="developer">Create developer</button>
        </div>
      </div>
      ${controls({ roleFilter: !filterRole })}
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
        <select data-role-user="${esc(profile.id)}">
          ${['customer', 'artisan', 'admin', 'developer']
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
        <h2>Reports and Admin Notifications</h2>
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
              ${item.read_at || !item.id ? '' : `<button class="ghost small" data-read="${esc(item.id)}">Mark read</button>`}
            </div>
          </details>`
        )
        .join('')}
    </div>
  `;
}

function renderJobs() {
  const rows = filterRows(state.data.jobs, ['title', 'description', 'location', 'status', 'tenant_id']);
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Jobs and Bids</h2>
        <span class="badge">${rows.length} jobs</span>
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
        <span class="badge">${rows.length} listings</span>
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
  await updateTableRow('listings', id, { title, category, location }, 'Listing updated.');
}

async function editJob(id) {
  const job = state.data.jobs.find((item) => item.id === id);
  if (!job) return;
  const title = window.prompt('Job title', job.title || '') ?? job.title;
  const status = window.prompt('Status', job.status || 'active') ?? job.status;
  const location = window.prompt('Location', job.location || '') ?? job.location;
  await updateTableRow('jobs', id, { title, status, location }, 'Job updated.');
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
        Keep service role keys out of Vercel frontend variables. Account creation and password changes are handled by the <code>developer-admin</code> Edge Function.
      </div>
      <h2>Developer Access</h2>
      <p class="muted">
        Only accounts with <code>role = 'developer'</code> in <code>public.profiles</code> can continue. Admin, artisan, and user accounts are signed out immediately.
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
        <h1>ProSME Developer Dashboard</h1>
        <p>Developer accounts only.</p>
        ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
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

function renderContent() {
  if (state.loading) {
    return renderShell('<div class="loading">Loading ProSME dashboard...</div>');
  }

  switch (state.tab) {
    case 'users':
      return renderShell(renderProfiles());
    case 'artisans':
      return renderShell(renderProfiles('artisan'));
    case 'verifications':
      return renderShell(renderVerifications());
    case 'reports':
      return renderShell(renderReports());
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
  if (!hasConfig || !state.session) {
    app.innerHTML = renderLogin();
  } else {
    app.innerHTML = renderContent();
  }
  bindEvents();
}

function bindEvents() {
  document.querySelector('#login-form')?.addEventListener('submit', signIn);

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

  document.querySelectorAll('[data-create-role]').forEach((button) => {
    button.addEventListener('click', () => createAccount(button.dataset.createRole));
  });

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
