import { createClient } from '@supabase/supabase-js';
import './styles.css';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
const app = document.querySelector('#app');

const state = {
  session: null,
  profile: null,
  tab: 'overview',
  loading: true,
  busy: false,
  error: '',
  notice: '',
  data: {
    profiles: [],
    listings: [],
    jobs: [],
    bids: [],
    ratings: [],
    notifications: [],
    reports: [],
  },
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
      state.data = {
        profiles: [],
        listings: [],
        jobs: [],
        bids: [],
        ratings: [],
        notifications: [],
        reports: [],
      };
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

  if (!['admin', 'developer'].includes(profile?.role)) {
    state.error =
      'This account can sign in, but it is not marked as admin or developer in public.profiles.';
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

  const [
    profiles,
    listings,
    jobs,
    bids,
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
        .limit(300)
    ),
    safeSelect(
      'listings',
      supabase
        .from('listings')
        .select('id,title,description,category,location,price_min,price_max,artisan_id,tenant_id,created_at')
        .order('created_at', { ascending: false })
        .limit(300)
    ),
    safeSelect(
      'jobs',
      supabase
        .from('jobs')
        .select('id,title,description,location,budget,status,created_by,tenant_id,created_at')
        .order('created_at', { ascending: false })
        .limit(300)
    ),
    safeSelect(
      'job_bids',
      supabase
        .from('job_bids')
        .select('id,job_id,artisan_id,amount,message,status,created_at,updated_at')
        .order('created_at', { ascending: false })
        .limit(300)
    ),
    safeSelect(
      'job_ratings',
      supabase
        .from('job_ratings')
        .select('id,job_id,artisan_id,user_id,stars,comment,created_at')
        .order('created_at', { ascending: false })
        .limit(300)
    ),
    safeSelect(
      'admin_notifications',
      supabase
        .from('admin_notifications')
        .select('id,type,title,body,actor_id,read_at,created_at')
        .order('created_at', { ascending: false })
        .limit(300)
    ),
    safeSelect(
      'reports',
      supabase
        .from('reports')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(300)
    ),
  ]);

  state.data = {
    profiles,
    listings,
    jobs,
    bids,
    ratings,
    notifications,
    reports,
  };
}

async function signIn(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  state.busy = true;
  state.error = '';
  render();

  const { error } = await supabase.auth.signInWithPassword({
    email: String(form.get('email') || '').trim(),
    password: String(form.get('password') || ''),
  });

  state.busy = false;
  if (error) {
    state.error = error.message;
  }
  render();
}

async function signOut() {
  await supabase.auth.signOut();
}

async function setVerification(userId, status) {
  const notes =
    status === 'rejected'
      ? window.prompt('Reason for rejection', 'Documents are unclear or incomplete.') || ''
      : '';
  state.busy = true;
  render();

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

  const { error } = await supabase.from('profiles').update(update).eq('id', userId);
  state.busy = false;

  if (error) {
    state.error = error.message;
  } else {
    setNotice(`Verification ${status}.`);
    await refreshData();
  }
  render();
}

async function updateRole(userId, role) {
  state.busy = true;
  render();
  const { error } = await supabase.from('profiles').update({ role }).eq('id', userId);
  state.busy = false;

  if (error) {
    state.error = error.message;
  } else {
    setNotice(`Role changed to ${role}.`);
    await refreshData();
  }
  render();
}

async function markNotificationRead(id) {
  state.busy = true;
  render();
  const { error } = await supabase
    .from('admin_notifications')
    .update({ read_at: new Date().toISOString() })
    .eq('id', id);
  state.busy = false;

  if (error) {
    state.error = error.message;
  } else {
    setNotice('Notification marked as reviewed.');
    await refreshData();
  }
  render();
}

function dashboardStats() {
  const profiles = state.data.profiles;
  const artisans = profiles.filter((profile) => profile.role === 'artisan');
  const customers = profiles.filter((profile) => profile.role === 'customer');
  const pending = artisans.filter((profile) => profile.verification_status === 'pending');
  const rejected = artisans.filter((profile) => profile.verification_status === 'rejected');
  const unread = state.data.notifications.filter((item) => !item.read_at);
  const openJobs = state.data.jobs.filter((job) => (job.status || 'active') === 'active');
  const reports = state.data.reports.length
    ? state.data.reports
    : state.data.notifications.filter((item) => String(item.type || '').includes('report'));

  return [
    ['Total users', profiles.length, `${customers.length} customers`],
    ['Artisans', artisans.length, `${pending.length} pending verification`],
    ['Listings', state.data.listings.length, 'Visible in app search'],
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
            <p>Admin / Developer</p>
            <h1>${esc(tabs.find(([id]) => id === state.tab)?.[1] || 'Overview')}</h1>
          </div>
          <div class="actions">
            <button class="ghost" data-action="refresh">Refresh</button>
          </div>
        </header>
        ${state.notice ? `<div class="notice">${esc(state.notice)}</div>` : ''}
        ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
        ${Object.keys(state.tableErrors).length ? renderTableErrors() : ''}
        ${content}
      </main>
    </div>
  `;
}

function renderTableErrors() {
  return `
    <details class="warning">
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
        <div class="list-row">
          <div>
            <strong>${esc(item.title || item.type || 'Activity')}</strong>
            <span>${esc(item.body || '')}</span>
            <small>${dateText(item.created_at)}</small>
          </div>
          ${item.read_at ? '<span class="badge">Reviewed</span>' : `<button class="ghost small" data-read="${esc(item.id)}">Mark read</button>`}
        </div>`
        )
        .join('')}
    </div>
  `;
}

function renderProfiles(filterRole = null) {
  const rows = filterRole
    ? state.data.profiles.filter((profile) => profile.role === filterRole)
    : state.data.profiles;
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>${filterRole === 'artisan' ? 'Artisan Accounts' : 'User Accounts'}</h2>
        <span class="badge">${rows.length} records</span>
      </div>
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
      <td>
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
  const rows = state.data.profiles.filter((profile) => profile.role === 'artisan');
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Artisan Verification Queue</h2>
        <span class="badge">${pendingVerifications().length} pending</span>
      </div>
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
                  <td>
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

function renderReports() {
  const reports = state.data.reports.length
    ? state.data.reports
    : state.data.notifications.filter((item) => String(item.type || '').includes('report'));

  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Reports and Admin Notifications</h2>
        <span class="badge">${reports.length || state.data.notifications.length} records</span>
      </div>
      ${reports.length ? renderReportRows(reports) : renderActivityList(state.data.notifications)}
    </section>
  `;
}

function renderReportRows(reports) {
  return `
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Type</th>
            <th>Title</th>
            <th>Details</th>
            <th>Status</th>
            <th>Date</th>
          </tr>
        </thead>
        <tbody>
          ${reports
            .map(
              (item) => `
              <tr>
                <td>${esc(item.type || item.category || 'report')}</td>
                <td><strong>${esc(item.title || item.reason || 'Report')}</strong></td>
                <td>${esc(item.body || item.description || item.message || '')}</td>
                <td>${statusBadge(item.status || (item.read_at ? 'reviewed' : 'open'))}</td>
                <td>${dateText(item.created_at)}</td>
              </tr>`
            )
            .join('')}
        </tbody>
      </table>
    </div>
  `;
}

function renderJobs() {
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Jobs and Bids</h2>
        <span class="badge">${state.data.jobs.length} jobs</span>
      </div>
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
            </tr>
          </thead>
          <tbody>
            ${state.data.jobs
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
                  </tr>`;
              })
              .join('') || tableEmpty(6)}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function renderListings() {
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Listings</h2>
        <span class="badge">${state.data.listings.length} listings</span>
      </div>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Listing</th>
              <th>Category</th>
              <th>Location</th>
              <th>Price</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            ${state.data.listings
              .map(
                (listing) => `
                <tr>
                  <td><strong>${esc(listing.title)}</strong><small>${esc(listing.description || '')}</small></td>
                  <td>${esc(listing.category || 'Other')}</td>
                  <td>${esc(listing.location || '')}</td>
                  <td>${money(listing.price_min)} - ${money(listing.price_max)}</td>
                  <td>${dateText(listing.created_at)}</td>
                </tr>`
              )
              .join('') || tableEmpty(5)}
          </tbody>
        </table>
      </div>
    </section>
  `;
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
        Keep service role keys out of Vercel frontend variables. Use only publishable or anon keys here.
      </div>
      <h2>Developer Access</h2>
      <p class="muted">
        A signed-in account must have <code>role = 'developer'</code> or <code>role = 'admin'</code> in <code>public.profiles</code>.
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
        <p>Sign in with an admin or developer account.</p>
        ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
        <label>
          Email
          <input name="email" type="email" autocomplete="email" placeholder="blumebyte@gmail.com" required />
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

  document.querySelector('[data-action="sign-out"]')?.addEventListener('click', signOut);
  document.querySelector('[data-action="refresh"]')?.addEventListener('click', async () => {
    state.loading = true;
    render();
    await refreshData();
    state.loading = false;
    setNotice('Dashboard refreshed.');
    render();
  });

  document.querySelectorAll('[data-verify]').forEach((button) => {
    button.addEventListener('click', () => setVerification(button.dataset.id, button.dataset.verify));
  });

  document.querySelectorAll('[data-read]').forEach((button) => {
    button.addEventListener('click', () => markNotificationRead(button.dataset.read));
  });

  document.querySelectorAll('[data-role-user]').forEach((select) => {
    select.addEventListener('change', () => updateRole(select.dataset.roleUser, select.value));
  });
}

init();
