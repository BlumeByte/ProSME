import { createClient } from '@supabase/supabase-js';
import readXlsxFile from 'read-excel-file/browser';
import './styles.css';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
const googleMeasurementId = import.meta.env.VITE_GOOGLE_MEASUREMENT_ID;
const adsenseClient = import.meta.env.VITE_GOOGLE_ADSENSE_CLIENT;
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
  verificationSubscriptions: [],
  analyticsEvents: [],
  emailOutbox: [],
});

const publicRoutes = new Set([
  '/',
  '/about',
  '/features',
  '/login',
  '/signup',
  '/terms',
  '/privacy',
  '/security',
  '/cookies',
]);

const currentPublicPage = () => {
  const path = window.location.pathname;
  return publicRoutes.has(path) ? path : '/';
};

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
  publicPage: currentPublicPage(),
  authMode: window.location.pathname === '/signup' ? 'signup' : 'login',
  pendingConfirmationEmail:
    window.localStorage.getItem('prosme_pending_confirmation_email') || '',
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

const publicNav = [
  ['/', 'Home'],
  ['/about', 'About'],
  ['/features', 'Features'],
];

const socials = [
  ['Instagram', 'https://www.instagram.com/blumebyte/'],
  ['Facebook', 'https://www.facebook.com/bloombyte/'],
  ['LinkedIn', 'https://gh.linkedin.com/in/blumebyte'],
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
const validEmail = (value) =>
  /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(normalize(value));
const authRedirectUrl = (path = '/login') =>
  new URL(path, window.location.origin).toString();
let lastTrackedPath = '';

const sessionAnalyticsId = (() => {
  const key = 'prosme_analytics_session_id';
  const existing = window.sessionStorage.getItem(key);
  if (existing) return existing;
  const created = crypto.randomUUID?.() || `${Date.now()}-${Math.random()}`;
  window.sessionStorage.setItem(key, created);
  return created;
})();
const secureRandomIndex = (bound) => {
  if (!Number.isInteger(bound) || bound <= 0) {
    throw new RangeError('bound must be a positive integer');
  }
  const maxUint32 = 0x100000000;
  const limit = Math.floor(maxUint32 / bound) * bound;
  const buffer = new Uint32Array(1);
  let value = 0;
  do {
    crypto.getRandomValues(buffer);
    value = buffer[0];
  } while (value >= limit);
  return value % bound;
};
const generateStrongPassword = () => {
  const lowercase = 'abcdefghijkmnopqrstuvwxyz';
  const uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const numbers = '23456789';
  const symbols = '!@#$%^&*';
  const all = lowercase + uppercase + numbers + symbols;
  const pick = (chars) => chars[secureRandomIndex(chars.length)];
  const password = [
    pick(lowercase),
    pick(uppercase),
    pick(numbers),
    pick(symbols),
    ...Array.from({ length: 10 }, () => pick(all)),
  ];
  for (let index = password.length - 1; index > 0; index -= 1) {
    const random = secureRandomIndex(index + 1);
    [password[index], password[random]] = [password[random], password[index]];
  }
  return password.join('');
};

const artisanImages = {
  market:
    'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1600&q=80',
  textile:
    'https://images.unsplash.com/photo-1516762689617-e1cffcef479d?auto=format&fit=crop&w=1600&q=80',
  craft:
    'https://images.unsplash.com/photo-1452860606245-08befc0ff44b?auto=format&fit=crop&w=1600&q=80',
  workshop:
    'https://images.unsplash.com/photo-1504917595217-d4dc5ebe6122?auto=format&fit=crop&w=1600&q=80',
  request:
    'https://images.unsplash.com/photo-1556761175-b413da4baf72?auto=format&fit=crop&w=1200&q=80',
  marketplace:
    'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1200&q=80',
  verification:
    'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?auto=format&fit=crop&w=1200&q=80',
  chat:
    'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80',
  invoices:
    'https://images.unsplash.com/photo-1554224155-6726b3ff858f?auto=format&fit=crop&w=1200&q=80',
  account:
    'https://images.unsplash.com/photo-1552664730-d307ca884978?auto=format&fit=crop&w=1200&q=80',
  visibility:
    'https://images.unsplash.com/photo-1531206715517-5c0ba140b2b8?auto=format&fit=crop&w=1200&q=80',
  records:
    'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1200&q=80',
  growth:
    'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=1200&q=80',
  training:
    'https://images.unsplash.com/photo-1556761175-4b46a572b786?auto=format&fit=crop&w=1200&q=80',
  planning:
    'https://images.unsplash.com/photo-1559136555-9303baea8ebd?auto=format&fit=crop&w=1200&q=80',
  support:
    'https://images.unsplash.com/photo-1551836022-d5d88e9218df?auto=format&fit=crop&w=1200&q=80',
};

const smeBanner = ({
  image = artisanImages.market,
  eyebrow = 'SME growth',
  title = 'African small businesses run on trust, visibility, and timely work.',
  body = 'ProSME helps customers discover skilled artisans while giving SMEs digital records for requests, bids, verification, messages, and follow-up.',
} = {}) => `
  <section class="sme-banner" style="--banner-image:url('${image}')">
    <div>
      <span class="eyebrow">${esc(eyebrow)}</span>
      <h2>${esc(title)}</h2>
      <p>${esc(body)}</p>
    </div>
  </section>
`;

const imageCard = ({ title, body, image, className = 'feature-card' }) => `
  <article class="${className} glass-card">
    <div class="card-image" style="background-image:url('${image}')"></div>
    <div class="card-copy">
      <h3>${esc(title)}</h3>
      <p>${esc(body)}</p>
    </div>
  </article>
`;

const wideFeatureCard = ({ title, body, image }) => `
  <article class="wide-row glass-row">
    <div>
      <h2>${esc(title)}</h2>
      <p>${esc(body)}</p>
    </div>
    <div class="row-image" style="background-image:url('${image}')"></div>
  </article>
`;

const journeyStep = ({ label, title, body }) => `
  <article class="journey-step">
    <span>${esc(label)}</span>
    <h3>${esc(title)}</h3>
    <p>${esc(body)}</p>
  </article>
`;

const smeScene = ({
  image = artisanImages.workshop,
  eyebrow = 'SME operating system',
  title = 'A practical workspace for quotes, trust, records, and repeat work.',
  body = 'Each layer supports a real service moment: request intake, artisan comparison, verification, chat, invoices, and follow-up.',
} = {}) => `
  <section class="site-section scene-section">
    <div class="scene-copy">
      <span class="eyebrow">${esc(eyebrow)}</span>
      <h2>${esc(title)}</h2>
      <p>${esc(body)}</p>
    </div>
    <div class="sme-3d-scene" aria-label="Animated SME workflow layers">
      <div class="scene-orbit" aria-hidden="true"></div>
      <div class="scene-card scene-card-main" style="--scene-image:url('${image}')">
        <span>Verified work desk</span>
        <strong>Requests to records</strong>
      </div>
      <div class="scene-chip scene-chip-a">Bids</div>
      <div class="scene-chip scene-chip-b">Invoices</div>
      <div class="scene-chip scene-chip-c">Trust</div>
    </div>
  </section>
`;

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
    admin: 'badge badge-purple',
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
    in_progress: 'badge badge-blue',
    cancelled: 'badge badge-red',
    accepted: 'badge badge-green',
    active: 'badge badge-green',
    payment_required: 'badge badge-orange',
    pending_payment: 'badge badge-blue',
    paid_pending_review: 'badge badge-blue',
    expired: 'badge badge-red',
    renewal_failed: 'badge badge-red',
    cancelled: 'badge badge-red',
    resolved: 'badge badge-green',
    reviewing: 'badge badge-blue',
    open: 'badge badge-orange',
  };
  return `<span class="${map[status] || 'badge'}">${esc(status || 'unknown')}</span>`;
};

function installGoogleTracking() {
  if (googleMeasurementId && !document.querySelector('[data-gtag-loader]')) {
    const loader = document.createElement('script');
    loader.async = true;
    loader.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(googleMeasurementId)}`;
    loader.dataset.gtagLoader = 'true';
    document.head.appendChild(loader);
    window.dataLayer = window.dataLayer || [];
    window.gtag = function gtag() {
      window.dataLayer.push(arguments);
    };
    window.gtag('js', new Date());
    window.gtag('config', googleMeasurementId, {
      send_page_view: false,
    });
  }

  if (adsenseClient && !document.querySelector('[data-adsense-loader]')) {
    const adsense = document.createElement('script');
    adsense.async = true;
    adsense.crossOrigin = 'anonymous';
    adsense.src = `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${encodeURIComponent(adsenseClient)}`;
    adsense.dataset.adsenseLoader = 'true';
    document.head.appendChild(adsense);
  }
}

async function trackPublicPageView() {
  const path = window.location.pathname;
  if (!publicRoutes.has(path) || path === '/login' || path === '/signup') return;
  if (lastTrackedPath === path) return;
  lastTrackedPath = path;

  if (window.gtag && googleMeasurementId) {
    window.gtag('event', 'page_view', {
      page_title: document.title,
      page_location: window.location.href,
      page_path: path,
    });
  }

  if (!hasConfig || !supabase) return;
  await supabase.from('analytics_events').insert({
    source: 'web',
    event_name: 'page_view',
    path,
    referrer: document.referrer || '',
    user_agent: navigator.userAgent,
    session_id: sessionAnalyticsId,
    metadata: {
      title: document.title,
    },
  });
}

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
  installGoogleTracking();
  if (!hasConfig) {
    state.loading = false;
    state.error =
      'Add VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY in Vercel.';
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

  window.addEventListener('popstate', () => {
    state.publicPage = currentPublicPage();
    state.authMode =
      window.location.pathname === '/signup' ? 'signup' : 'login';
    render();
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
  let { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select(
      'id,full_name,email,role,verification_status,verification_expires_at,tenant_id,created_at',
    )
    .eq('id', userId)
    .maybeSingle();

  if (profileError) {
    await supabase.auth.signOut({ scope: 'local' });
    state.session = null;
    state.profile = null;
    state.data = emptyData();
    state.error = `Could not verify account access: ${profileError.message}`;
    state.loading = false;
    state.checkingAccess = false;
    render();
    return;
  }

  if (!profile) {
    const createdProfile = await createProfileForSessionUser();
    if (createdProfile.error) {
      await supabase.auth.signOut({ scope: 'local' });
      state.session = null;
      state.profile = null;
      state.data = emptyData();
      state.error = `Your email was confirmed, but your account profile could not be created: ${createdProfile.error.message}`;
      state.loading = false;
      state.checkingAccess = false;
      render();
      return;
    }
    profile = createdProfile.profile;
  }

  state.profile = profile;
  state.pendingConfirmationEmail = '';
  window.localStorage.removeItem('prosme_pending_confirmation_email');

  if (profile?.role !== 'admin') {
    await refreshPortalData();
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

async function createProfileForSessionUser() {
  const user = state.session?.user;
  if (!user) {
    return { profile: null, error: new Error('No signed-in user was found.') };
  }
  const metadata = user.user_metadata || {};
  const role = ['customer', 'artisan'].includes(metadata.role)
    ? metadata.role
    : 'customer';
  const fullName =
    normalize(metadata.full_name || metadata.username) ||
    normalize(user.email).split('@')[0] ||
    'ProSME user';
  const email = normalize(user.email);
  const { data, error } = await supabase
    .from('profiles')
    .upsert(
      {
        id: user.id,
        email,
        full_name: fullName,
        role,
        verification_status: 'pending',
      },
      { onConflict: 'id' },
    )
    .select(
      'id,full_name,email,role,verification_status,verification_expires_at,tenant_id,created_at',
    )
    .single();
  return { profile: data, error };
}

async function refreshPortalData() {
  state.tableErrors = {};
  const userId = state.session?.user?.id;
  if (!userId) {
    state.data = emptyData();
    return;
  }

  const [listings, jobs, bids, walletTransactions, notifications] =
    await Promise.all([
      safeSelect(
        'listings',
        supabase
          .from('listings')
          .select(
            'id,title,description,category,location,price_min,price_max,artisan_id,created_at',
          )
          .order('created_at', { ascending: false })
          .limit(80),
      ),
      safeSelect(
        'jobs',
        supabase
          .from('jobs')
          .select(
            'id,title,description,location,budget,status,created_by,created_at',
          )
          .order('created_at', { ascending: false })
          .limit(80),
      ),
      safeSelect(
        'job_bids',
        supabase
          .from('job_bids')
          .select(
            'id,job_id,artisan_id,amount,message,status,created_at,updated_at',
          )
          .order('created_at', { ascending: false })
          .limit(80),
      ),
      safeSelect(
        'wallet_transactions',
        supabase
          .from('wallet_transactions')
          .select(
            'id,job_id,bid_id,user_id,artisan_id,amount,currency,event_type,invoice_number,job_title,job_location,customer_name,customer_email,artisan_name,artisan_email,payment_status,work_status,completed_at,created_at',
          )
          .order('created_at', { ascending: false })
          .limit(80),
      ),
      safeSelect(
        'notifications',
        supabase
          .from('admin_notifications')
          .select('id,type,title,body,related_user_id,read_at,created_at')
          .or(`related_user_id.eq.${userId},actor_id.eq.${userId}`)
          .order('created_at', { ascending: false })
          .limit(30),
      ),
    ]);

  state.data = {
    ...emptyData(),
    listings,
    jobs,
    bids,
    walletTransactions,
    notifications,
  };
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
    verificationSubscriptions,
    analyticsEvents,
    emailOutbox,
  ] = await Promise.all([
    safeSelect(
      'profiles',
      supabase
        .from('profiles')
        .select(
          'id,full_name,email,phone,role,verification_status,verification_expires_at,tenant_id,country,location,categories,description,bio,rating_summary,national_id_front_url,national_id_back_url,business_certificate_urls,verification_notes,verification_submitted_at,verification_reviewed_at,created_at',
        )
        .order('created_at', { ascending: false })
        .limit(500),
    ),
    safeSelect(
      'listings',
      supabase
        .from('listings')
        .select(
          'id,title,description,category,location,price_min,price_max,artisan_id,tenant_id,created_at',
        )
        .order('created_at', { ascending: false })
        .limit(500),
    ),
    safeSelect(
      'jobs',
      supabase
        .from('jobs')
        .select(
          'id,title,description,location,budget,status,created_by,tenant_id,created_at',
        )
        .order('created_at', { ascending: false })
        .limit(500),
    ),
    safeSelect(
      'job_bids',
      supabase
        .from('job_bids')
        .select(
          'id,job_id,artisan_id,amount,message,status,created_at,updated_at',
        )
        .order('created_at', { ascending: false })
        .limit(500),
    ),
    safeSelect(
      'wallet_transactions',
      supabase
        .from('wallet_transactions')
        .select(
          'id,job_id,bid_id,user_id,artisan_id,amount,currency,event_type,invoice_number,job_title,job_location,customer_name,customer_email,artisan_name,artisan_email,payment_status,work_status,completed_at,created_at',
        )
        .order('created_at', { ascending: false })
        .limit(1000),
    ),
    safeSelect(
      'threads',
      supabase
        .from('threads')
        .select('id,user_id,artisan_id,last_message,updated_at,created_at')
        .order('updated_at', { ascending: false })
        .limit(500),
    ),
    safeSelect(
      'messages',
      supabase
        .from('messages')
        .select('id,thread_id,sender_id,type,content,read_at,created_at')
        .order('created_at', { ascending: false })
        .limit(2000),
    ),
    safeSelect(
      'job_ratings',
      supabase
        .from('job_ratings')
        .select('id,job_id,artisan_id,user_id,stars,comment,created_at')
        .order('created_at', { ascending: false })
        .limit(500),
    ),
    safeSelect(
      'admin_notifications',
      supabase
        .from('admin_notifications')
        .select(
          'id,type,title,body,actor_id,related_user_id,related_table,related_id,read_at,created_at',
        )
        .order('created_at', { ascending: false })
        .limit(500),
    ),
    safeSelect(
      'reports',
      supabase
        .from('reports')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(500),
    ),
    safeSelect(
      'verification_subscriptions',
      supabase
        .from('verification_subscriptions')
        .select('*')
        .order('updated_at', { ascending: false })
        .limit(500),
    ),
    safeSelect(
      'analytics_events',
      supabase
        .from('analytics_events')
        .select('id,source,event_name,path,session_id,user_id,created_at')
        .order('created_at', { ascending: false })
        .limit(1000),
    ),
    safeSelect(
      'email_outbox',
      supabase
        .from('email_outbox')
        .select('id,to_email,subject,sent_at,attempt_count,last_error,created_at')
        .order('created_at', { ascending: false })
        .limit(200),
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
    verificationSubscriptions,
    analyticsEvents,
    emailOutbox,
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
      `${error.message}. Confirm the admin-dashboard Edge Function is deployed and its backend secrets are set for the same project as Vercel.`,
    );
  }
  if (data?.error) throw new Error(data.error);
  return data;
}

async function billingAction(action, payload = {}) {
  const { data, error } = await supabase.functions.invoke(
    'verification-billing',
    {
      body: { action, ...payload },
    },
  );
  if (error) throw new Error(error.message);
  if (data?.ok === false)
    throw new Error(data.error || 'Verification billing action failed.');
  return data;
}

const isEdgeFunctionRequestError = (error) =>
  lower(error?.message || error).includes(
    'failed to send a request to the edge function',
  );

async function updateManagedRow(table, id, patch, edgeAction) {
  try {
    await adminAction(edgeAction, { id, patch });
  } catch (error) {
    if (!isEdgeFunctionRequestError(error)) throw error;
    const { error: tableError } = await supabase
      .from(table)
      .update(patch)
      .eq('id', id);
    if (tableError) {
      throw new Error(
        `${tableError.message}. The Edge Function is unavailable and direct ${table} updates are blocked. Apply the admin RLS migration or deploy admin-dashboard.`,
      );
    }
  }
}

async function deleteManagedRow(table, id, edgeAction) {
  try {
    await adminAction(edgeAction, { id });
  } catch (error) {
    if (!isEdgeFunctionRequestError(error)) throw error;
    const { error: tableError } = await supabase
      .from(table)
      .delete()
      .eq('id', id);
    if (tableError) {
      throw new Error(
        `${tableError.message}. The Edge Function is unavailable and direct ${table} deletes are blocked. Apply the admin RLS migration or deploy admin-dashboard.`,
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
        `${tableError.message}. The Edge Function is unavailable and direct ${table} inserts are blocked. Apply the admin RLS migration or deploy admin-dashboard.`,
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

async function signUp(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const email = normalize(form.get('email')).toLowerCase();
  const password = String(form.get('password') || '');
  const role = lower(form.get('role')) === 'artisan' ? 'artisan' : 'customer';
  const fullName = normalize(form.get('full_name')) || email.split('@')[0];

  if (!validEmail(email)) {
    state.error = 'Enter a complete email address.';
    render();
    return;
  }
  if (password.length < 8) {
    state.error = 'Password must be at least 8 characters.';
    render();
    return;
  }

  state.busy = true;
  state.error = '';
  render();

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { full_name: fullName, role },
      emailRedirectTo: authRedirectUrl('/login'),
    },
  });

  if (error) {
    state.busy = false;
    state.error = error.message;
    render();
    return;
  }

  state.pendingConfirmationEmail = data.session ? '' : email;
  if (state.pendingConfirmationEmail) {
    window.localStorage.setItem(
      'prosme_pending_confirmation_email',
      state.pendingConfirmationEmail,
    );
  } else {
    window.localStorage.removeItem('prosme_pending_confirmation_email');
  }

  if (data.session?.user) {
    await supabase.from('profiles').upsert({
      id: data.session.user.id,
      email,
      full_name: fullName,
      role,
      verification_status: 'pending',
    });
  }

  state.busy = false;
  state.notice = data.session
    ? 'Account created. Your web and mobile account now use the same ProSME login.'
    : 'Check your email to confirm your account, then sign in.';
  state.authMode = 'login';
  navigate('/login');
}

async function resendConfirmationEmail() {
  const email = normalize(state.pendingConfirmationEmail).toLowerCase();
  if (!validEmail(email)) {
    state.error = 'Enter your email and create the account again to request confirmation.';
    render();
    return;
  }
  state.busy = true;
  state.error = '';
  state.notice = '';
  render();

  const { error } = await supabase.auth.resend({
    type: 'signup',
    email,
    options: {
      emailRedirectTo: authRedirectUrl('/login'),
    },
  });

  state.busy = false;
  if (error) {
    state.error = error.message;
  } else {
    state.notice = `Confirmation email resent to ${email}.`;
  }
  render();
}

function navigate(path) {
  window.history.pushState({}, '', path);
  state.publicPage = currentPublicPage();
  state.authMode = path === '/signup' ? 'signup' : 'login';
  state.error = '';
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
  state.publicPage = '/';
  window.history.replaceState({}, '', '/');
  render();
}

async function setVerification(userId, status) {
  const profile = state.data.profiles.find((item) => item.id === userId);
  if (status === 'verified' && profile?.verification_status === 'verified') {
    await runAction(async () => {
      await billingAction('backfillVerified');
      setNotice('Verified accounts were marked active for payment tracking.');
      await refreshData();
    });
    return;
  }
  const notes =
    status === 'rejected'
      ? window.prompt(
          'Reason for rejection',
          'Documents are unclear or incomplete.',
        ) || ''
      : window.prompt(
          'Approval notes',
          'Payment confirmed. Documents accepted and verification approved.',
        ) || '';
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

  await updateTableRow(
    'profiles',
    userId,
    update,
    status === 'verified'
      ? 'Verification approved and badge activated.'
      : `Verification ${status}.`,
  );
}

async function syncVerificationBilling(action) {
  await runAction(async () => {
    const result = await billingAction(action, { limit: 50 });
    if (action === 'renewDue') {
      setNotice(
        `Renewed ${result.renewed?.length || 0}; failed ${result.failed?.length || 0}.`,
      );
    } else if (action === 'backfillVerified') {
      setNotice(
        `Marked ${result.created || 0} already verified account${result.created === 1 ? '' : 's'} active.`,
      );
    } else {
      setNotice('Verification expiry status synced.');
    }
    await refreshData();
  });
}

async function confirmPaystackReference(reference) {
  if (!reference) return;
  await runAction(async () => {
    await billingAction('adminVerifyReference', { reference });
    setNotice('Paystack payment confirmed. Document review is now pending.');
    await refreshData();
  });
}

async function overrideVerificationPaid(userId) {
  const interval =
    lower(
      window.prompt('Subscription interval: monthly or yearly', 'monthly') ||
        'monthly',
    ) === 'yearly'
      ? 'yearly'
      : 'monthly';
  const notes = window.prompt(
    'Admin override note',
    'Admin reviewed documents and marked payment complete.',
  );
  if (notes === null) return;
  await runAction(async () => {
    await adminAction('overrideVerificationPaid', { userId, interval, notes });
    setNotice('Account marked paid and verified. Tracking was updated.');
    await refreshData();
  });
}

async function requestExtraVerification(userId) {
  const message = window.prompt(
    'Message to send by email and dashboard',
    'Please upload clearer or additional verification documents before approval.',
  );
  if (!message) return;
  await runAction(async () => {
    await adminAction('requestExtraVerification', { userId, message });
    setNotice('More verification information requested.');
    await refreshData();
  });
}

async function updateProfile(id) {
  const profile = state.data.profiles.find((item) => item.id === id);
  if (!profile) return;
  const full_name =
    window.prompt('Full name', profile.full_name || '') ?? profile.full_name;
  const phone = window.prompt('Phone', profile.phone || '') ?? profile.phone;
  const country =
    window.prompt('Country', profile.country || '') ?? profile.country;
  const location =
    window.prompt('Location', profile.location || '') ?? profile.location;
  await updateTableRow(
    'profiles',
    id,
    { full_name, phone, country, location },
    'Profile updated.',
  );
}

async function updateRole(userId, role) {
  await updateTableRow(
    'profiles',
    userId,
    { role },
    `Role changed to ${role}.`,
  );
}

async function deleteAccount(userId, email) {
  if (state.session?.user?.id === userId) {
    state.error =
      'You cannot delete the Admin Account you are currently using.';
    render();
    return;
  }
  const label = email || userId;
  if (
    !window.confirm(
      `Permanently delete ${label} from the app and database? This cannot be undone.`,
    )
  )
    return;

  await runAction(async () => {
    const result = await adminAction('deleteUser', { userId });
    if (result?.ok === false)
      throw new Error(result.error || 'Could not delete account.');
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
  if (
    !window.confirm(`Delete this ${table.slice(0, -1)}? This cannot be undone.`)
  )
    return;
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
  const fullName =
    normalize(window.prompt('Full name', '')) || email.split('@')[0];
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
          Object.entries(row).map(([key, value]) => [
            lower(key).replace(/\s+/g, '_'),
            value,
          ]),
        );
        const email = normalize(normalized.email).toLowerCase();
        const role = lower(
          normalized.role || normalized.account_type || 'customer',
        );
        return {
          email,
          role: role === 'user' ? 'customer' : role,
          full_name: normalize(
            normalized.full_name || normalized.name || email.split('@')[0],
          ),
          phone: normalize(normalized.phone || normalized.phone_number),
          location: normalize(normalized.location || normalized.city),
          country: normalize(normalized.country),
          password: normalize(normalized.password),
        };
      })
      .filter((account) => account.email);

    if (!accounts.length)
      throw new Error('No rows with an email column were found.');
    const badEmails = accounts.filter((account) => !validEmail(account.email));
    if (badEmails.length) {
      throw new Error(
        `Fix invalid email addresses before importing: ${badEmails
          .map((account) => account.email)
          .slice(0, 5)
          .join(', ')}`,
      );
    }
    const result = await adminAction('bulkCreateUsers', { accounts });
    const created = result.created?.length || 0;
    const failed = result.failed?.length || 0;
    setNotice(
      `Imported ${created} account${created === 1 ? '' : 's'}${failed ? `, ${failed} failed` : ''}.`,
    );
    if (failed) {
      state.error = result.failed
        .map((item) => `${item.email}: ${item.error}`)
        .join('\n');
    }
    await refreshData();
  });
}

function rowsToObjects(rows) {
  const [header = [], ...records] = rows;
  const keys = header.map((value) => normalize(value));
  return records.map((record) =>
    Object.fromEntries(keys.map((key, index) => [key, record[index] ?? ''])),
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
  const artisanId = await chooseProfileId(
    'artisan',
    'Artisan owner email or user id',
  );
  if (!artisanId) return;
  const title = normalize(window.prompt('Listing title', ''));
  if (!title) return;
  const description = normalize(window.prompt('Description', ''));
  const category = normalize(window.prompt('Category', 'General')) || 'General';
  const location = normalize(window.prompt('Location', ''));
  const priceMin = Number(window.prompt('Minimum price', '0') || 0);
  const priceMax = Number(
    window.prompt('Maximum price', String(priceMin || 0)) || priceMin || 0,
  );
  await runAction(async () => {
    await insertManagedRow(
      'listings',
      {
        artisan_id: artisanId,
        title,
        description,
        category,
        location,
        price_min: priceMin,
        price_max: priceMax,
      },
      'upsertListing',
    );
    setNotice('Listing created.');
    await refreshData();
  });
}

async function createJob() {
  const createdBy = await chooseProfileId(
    null,
    'Customer/artisan owner email or user id',
  );
  if (!createdBy) return;
  const title = normalize(window.prompt('Job title', ''));
  if (!title) return;
  const description = normalize(window.prompt('Description', ''));
  const location = normalize(window.prompt('Location', ''));
  const budget = Number(window.prompt('Budget', '0') || 0);
  await runAction(async () => {
    await insertManagedRow(
      'jobs',
      {
        created_by: createdBy,
        title,
        description,
        location,
        budget,
        status: 'active',
      },
      'upsertJob',
    );
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
      (lower(item.email) === lower(value) || item.id === value),
  );
  if (profile) return profile.id;
  state.error = role
    ? `No ${role} found for ${value}.`
    : `No account found for ${value}.`;
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
    if (!state.session)
      throw new Error(
        'This recovery link is invalid or has expired. Request a new one.',
      );
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
    setNotice(
      `New secure password created. Password setup link sent to ${email}.`,
    );
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
  await updateTableRow(
    'admin_notifications',
    id,
    { read_at: new Date().toISOString() },
    'Notification reviewed.',
  );
}

async function setReportStatus(id, status) {
  await updateTableRow(
    'reports',
    id,
    { status, reviewed_at: new Date().toISOString() },
    `Report marked ${status}.`,
  );
}

async function sendReportResponse(id) {
  const report = state.data.reports.find((item) => item.id === id);
  if (!report?.reporter_id) {
    state.error = 'This report has no reporter account to notify.';
    render();
    return;
  }
  const response = window.prompt(
    'No-reply message to user',
    'Your support ticket has been reviewed.',
  );
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
    await supabase
      .from('reports')
      .update({
        status: 'resolved',
        reviewed_at: new Date().toISOString(),
      })
      .eq('id', id);
    setNotice('No-reply support response sent.');
    await refreshData();
  });
}

function dashboardStats() {
  const profiles = state.data.profiles;
  const artisans = profiles.filter((profile) => profile.role === 'artisan');
  const customers = profiles.filter((profile) => profile.role === 'customer');
  const pending = artisans.filter(
    (profile) => profile.verification_status === 'pending',
  );
  const rejected = artisans.filter(
    (profile) => profile.verification_status === 'rejected',
  );
  const unread = state.data.notifications.filter((item) => !item.read_at);
  const openJobs = state.data.jobs.filter(
    (job) => (job.status || 'active') === 'active',
  );
  const reports = visibleReports();
  const dayAgo = Date.now() - 24 * 60 * 60 * 1000;
  const recentVisits = state.data.analyticsEvents.filter(
    (event) => new Date(event.created_at).getTime() >= dayAgo,
  );
  const visitorCount = new Set(
    recentVisits.map((event) => event.session_id || event.id),
  ).size;
  const pendingEmails = state.data.emailOutbox.filter((item) => !item.sent_at);
  const failedEmails = pendingEmails.filter((item) => item.last_error);

  return [
    ['Total users', profiles.length, `${customers.length} customers`],
    ['Artisans', artisans.length, `${pending.length} pending verification`],
    ['Listings', state.data.listings.length, 'Editable service listings'],
    ['Open jobs', openJobs.length, `${state.data.bids.length} bids`],
    ['Reports', reports.length, `${unread.length} unread admin notices`],
    ['Visitors 24h', visitorCount, `${recentVisits.length} page views`],
    ['Email queue', pendingEmails.length, `${failedEmails.length} failed sends`],
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
                `<button class="nav-item ${state.tab === id ? 'active' : ''}" data-tab="${id}">${label}</button>`,
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
      <summary>Some data tables or access policies need attention</summary>
      <ul>
        ${Object.entries(state.tableErrors)
          .map(
            ([name, message]) =>
              `<li><strong>${esc(name)}:</strong> ${esc(message)}</li>`,
          )
          .join('')}
      </ul>
    </details>
  `;
}

function renderOverview() {
  const stats = dashboardStats();
  const recentNotifications = state.data.notifications.slice(0, 8);
  const pending = pendingVerifications().slice(0, 6);
  const emailQueue = state.data.emailOutbox.slice(0, 8);
  return `
    <section class="stat-grid">
      ${stats
        .map(
          ([label, value, hint]) => `
          <article class="stat-card">
            <span>${esc(label)}</span>
            <strong>${esc(value)}</strong>
            <small>${esc(hint)}</small>
          </article>`,
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
    <section class="panel">
      <div class="panel-head">
        <h2>Email Delivery</h2>
        <span class="muted">Resend and auth email health</span>
      </div>
      ${
        emailQueue.length
          ? `<div class="list">${emailQueue
              .map(
                (item) => `
                  <div class="list-row">
                    <div>
                      <strong>${esc(item.subject || 'Email')}</strong>
                      <small>${esc(item.to_email || 'Profile email')} · ${dateText(item.created_at)}</small>
                      ${item.last_error ? `<small class="error-line">${esc(item.last_error)}</small>` : ''}
                    </div>
                    ${item.sent_at ? statusBadge('completed') : statusBadge(item.last_error ? 'rejected' : 'pending')}
                  </div>`,
              )
              .join('')}</div>`
          : '<p class="empty">No email delivery records loaded.</p>'
      }
    </section>
  `;
}

function pendingVerifications() {
  return state.data.profiles.filter(
    (profile) => {
      const subscription = subscriptionForUser(profile.id);
      return (
        ['customer', 'artisan'].includes(profile.role) &&
        profile.verification_status === 'pending' &&
        subscription?.status === 'paid_pending_review' &&
        (profile.national_id_front_url || profile.national_id_back_url)
      );
    },
  );
}

function subscriptionForUser(userId) {
  return (
    state.data.verificationSubscriptions.find(
      (item) => item.user_id === userId,
    ) || null
  );
}

function subscriptionBadge(subscription) {
  if (!subscription) return '<span class="badge">not started</span>';
  return statusBadge(subscription.status || 'payment_required');
}

function controls({ roleFilter = true, statusFilter = true } = {}) {
  return `
    <div class="toolbar">
      <input data-filter="q" type="search" placeholder="Search records" value="${esc(state.filters.q)}" />
      ${
        roleFilter
          ? `<select data-filter="role">
              ${['all', 'customer', 'artisan', 'admin']
                .map(
                  (role) =>
                    `<option value="${role}" ${state.filters.role === role ? 'selected' : ''}>${role}</option>`,
                )
                .join('')}
            </select>`
          : ''
      }
      ${
        statusFilter
          ? `<select data-filter="status">
              ${[
                'all',
                'pending',
                'accepted',
                'rejected',
                'verified',
                'payment_required',
                'pending_payment',
                'paid_pending_review',
                'active',
                'expired',
                'renewal_failed',
                'in_progress',
                'open',
                'reviewing',
                'resolved',
                'completed',
                'cancelled',
              ]
                .map(
                  (status) =>
                    `<option value="${status}" ${state.filters.status === status ? 'selected' : ''}>${status}</option>`,
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
    if (
      state.filters.role !== 'all' &&
      'role' in row &&
      row.role !== state.filters.role
    )
      return false;
    const status =
      row.verification_status ||
      row.status ||
      (row.read_at ? 'resolved' : 'open');
    const hasStatus =
      'verification_status' in row || 'status' in row || 'read_at' in row;
    if (
      state.filters.status !== 'all' &&
      hasStatus &&
      status !== state.filters.status
    )
      return false;
    if (!q) return true;
    return fields.some((field) => lower(row[field]).includes(q));
  });

  return filtered.sort((a, b) => {
    if (state.filters.sort === 'oldest')
      return String(a.created_at || '').localeCompare(
        String(b.created_at || ''),
      );
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
            <strong>${esc(profile.full_name || profile.email || 'Unnamed account')}</strong>
            <span>${esc(profile.email || 'No email')} ${profile.location ? `- ${esc(profile.location)}` : ''}</span>
            <small>${esc(profile.role || 'customer')} · Submitted ${dateText(profile.verification_submitted_at || profile.created_at)}</small>
          </div>
          <div class="row-actions">
            ${documentLinks(profile)}
            <button class="approve" data-verify="verified" data-id="${esc(profile.id)}">Accept docs</button>
            <button class="reject" data-verify="rejected" data-id="${esc(profile.id)}">Reject</button>
          </div>
        </div>`,
        )
        .join('')}
    </div>
  `;
}

function documentLinks(profile) {
  const links = [
    ['Front ID', profile.national_id_front_url || profile.national_id_url],
    ['Back ID', profile.national_id_back_url],
    ...(profile.business_certificate_urls || []).map((url, index) => [
      `Certificate ${index + 1}`,
      url,
    ]),
  ].filter(([, url]) => Boolean(url));

  if (!links.length) return '<span class="muted">No documents</span>';
  return links
    .map(
      ([label, url]) =>
        `<a class="ghost small" href="${esc(url)}" target="_blank" rel="noreferrer">${esc(label)}</a>`,
    )
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
        </details>`,
        )
        .join('')}
    </div>
  `;
}

function renderProfiles(filterRole = null) {
  const rows = filterRows(state.data.profiles, [
    'full_name',
    'email',
    'phone',
    'location',
    'country',
    'tenant_id',
  ]);
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
              <th>Subscription</th>
              <th>Tenant</th>
              <th>Joined</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            ${rows.map(renderProfileRow).join('') || tableEmpty(9)}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function renderProfileRow(profile) {
  const subscription = subscriptionForUser(profile.id);
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
      <td>
        ${subscriptionBadge(subscription)}
        <small>${subscription?.current_period_end ? `Expires ${dateText(subscription.current_period_end)}` : ''}</small>
      </td>
      <td>${esc(profile.tenant_id || 'default')}</td>
      <td>${dateText(profile.created_at)}</td>
      <td class="row-actions">
        <button class="ghost small" data-edit-profile="${esc(profile.id)}">Edit</button>
        <button class="ghost small" data-reset-email="${esc(profile.email || '')}">Reset</button>
        <button class="ghost small" data-random-password="${esc(profile.id)}" data-email="${esc(profile.email || '')}">Random password</button>
        <button class="reject small" data-delete-account="${esc(profile.id)}" data-email="${esc(profile.email || '')}">Delete</button>
        <select data-role-user="${esc(profile.id)}">
          ${['customer', 'artisan', 'admin']
            .map(
              (role) =>
                `<option value="${role}" ${profile.role === role ? 'selected' : ''}>${role}</option>`,
            )
            .join('')}
        </select>
      </td>
    </tr>
  `;
}

function renderVerifications() {
  const rows = filterRows(
    state.data.profiles.filter((profile) =>
      ['customer', 'artisan'].includes(profile.role),
    ),
    ['full_name', 'email', 'location', 'verification_notes'],
  );
  const subscriptions = filterRows(state.data.verificationSubscriptions, [
    'status',
    'role',
    'paystack_reference',
  ]);
  return `
    <section class="panel">
      <div class="panel-head">
        <h2>Verification Queue</h2>
        <div class="row-actions">
          <span class="badge">${pendingVerifications().length} pending</span>
          <button class="ghost small" data-billing-action="syncExpirations">Check expiries</button>
          <button class="ghost small" data-billing-action="renewDue">Run renewals</button>
          <button class="ghost small" data-billing-action="backfillVerified">Mark existing verified active</button>
        </div>
      </div>
      ${controls({ roleFilter: false })}
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Artisan</th>
              <th>Status</th>
              <th>Payment tracking</th>
              <th>Documents</th>
              <th>Notes</th>
              <th>Submitted</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            ${
              rows
                .map(
                  (profile) => `
                <tr>
                  <td><strong>${esc(profile.full_name || profile.email || 'Unnamed')}</strong><small>${esc(profile.email || '')}</small></td>
                  <td>${statusBadge(profile.verification_status)}</td>
                  <td>
                    ${subscriptionBadge(subscriptionForUser(profile.id))}
                    <small>${subscriptionForUser(profile.id)?.current_period_end ? `Expires ${dateText(subscriptionForUser(profile.id).current_period_end)}` : ''}</small>
                  </td>
                  <td class="doc-cell">${documentLinks(profile)}</td>
                  <td>${esc(profile.verification_notes || '')}</td>
                  <td>${dateText(profile.verification_submitted_at || profile.created_at)}</td>
                  <td class="row-actions">
                    <button class="approve small" data-verify="verified" data-id="${esc(profile.id)}">Accept docs</button>
                    <button class="approve small" data-override-verify="${esc(profile.id)}">Mark paid + verify</button>
                    <button class="ghost small" data-request-extra="${esc(profile.id)}">Request more info</button>
                    <button class="reject small" data-verify="rejected" data-id="${esc(profile.id)}">Reject</button>
                  </td>
                </tr>`,
                )
                .join('') || tableEmpty(7)
            }
          </tbody>
        </table>
      </div>
    </section>
    <section class="panel">
      <div class="panel-head">
        <h2>Verification Payment Tracking</h2>
        <span class="badge">${subscriptions.length} subscriptions</span>
      </div>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Account</th>
              <th>Role</th>
              <th>Plan</th>
              <th>Status</th>
              <th>Auto-renew</th>
              <th>Payment method</th>
              <th>Reference</th>
              <th>Expires</th>
              <th>Last payment</th>
              <th>Renewal issue</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            ${
              subscriptions
                .map((sub) => {
                  const profile = profileFor(sub.user_id);
                  return `
                    <tr>
                      <td><strong>${esc(profileLabel(sub.user_id))}</strong><small>${esc(profile?.email || '')}</small></td>
                      <td>${roleBadge(sub.role)}</td>
                      <td>${esc(sub.plan_interval || 'monthly')} · $${Number(sub.amount_usd || 0).toFixed(2)}</td>
                      <td>${statusBadge(sub.status)}</td>
                      <td>${sub.auto_renew ? '<span class="badge badge-green">on</span>' : '<span class="badge">off</span>'}</td>
                      <td><strong>${esc(sub.payment_method_label || 'Not saved')}</strong><small>${esc(sub.payment_method_channel || '')}</small></td>
                      <td>${esc(sub.paystack_reference || '')}</td>
                      <td>${dateText(sub.current_period_end)}</td>
                      <td>${dateText(sub.last_payment_at)}</td>
                      <td>${esc(sub.last_renewal_error || '')}</td>
                      <td class="row-actions">
                        ${
                          sub.paystack_reference &&
                          !['active', 'success'].includes(lower(sub.status))
                            ? `<button class="approve small" data-confirm-paystack="${esc(sub.paystack_reference)}">Confirm Paystack</button>`
                            : ''
                        }
                      </td>
                    </tr>`;
                })
                .join('') || tableEmpty(11)
            }
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function visibleReports() {
  const reportRows = state.data.reports.length
    ? state.data.reports
    : state.data.notifications.filter((item) =>
        String(item.type || '').includes('report'),
      );
  return filterRows(reportRows, [
    'type',
    'category',
    'title',
    'reason',
    'body',
    'description',
    'message',
    'status',
  ]);
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
          </details>`,
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
  return (
    state.data.walletTransactions.find(
      (transaction) =>
        transaction.bid_id === id && transaction.event_type === 'bid_accepted',
    ) || null
  );
}

function threadForParticipants(customerId, artisanId) {
  return (
    state.data.threads.find(
      (thread) =>
        thread.user_id === customerId && thread.artisan_id === artisanId,
    ) || null
  );
}

function messagePreview(message) {
  if (message?.type !== 'invoice')
    return normalize(message?.content) || 'Empty message';
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
                    </div>`,
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
      customerName: profileLabel(
        customerId,
        wallet?.customer_name || 'Customer',
      ),
      artisanName: profileLabel(
        bid.artisan_id,
        wallet?.artisan_name || 'Artisan',
      ),
    };
  });
  const filtered = rows.filter((row) => {
    if (state.filters.status !== 'all' && row.status !== state.filters.status)
      return false;
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
  return [...flow.values()].sort(
    (a, b) => b.spent + b.received - (a.spent + a.received),
  );
}

function renderBidTracking() {
  const rows = trackedBidRows();
  const accepted = state.data.bids.filter((bid) => bid.status === 'accepted');
  const pending = state.data.bids.filter((bid) => bid.status === 'pending');
  const acceptedAmount = accepted.reduce(
    (sum, bid) => sum + Number(walletForBid(bid.id)?.amount ?? bid.amount ?? 0),
    0,
  );
  const flowRows = userMoneyFlow();
  const linkedThreads = new Set(
    rows.map((row) => row.thread?.id).filter(Boolean),
  );
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
                    </tr>`,
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
                    </tr>`,
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
  const rows = filterRows(state.data.jobs, [
    'title',
    'description',
    'location',
    'status',
    'tenant_id',
  ]);
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
            ${
              rows
                .map((job) => {
                  const bidCount = state.data.bids.filter(
                    (bid) => bid.job_id === job.id,
                  ).length;
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
                .join('') || tableEmpty(7)
            }
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function renderListings() {
  const rows = filterRows(state.data.listings, [
    'title',
    'description',
    'category',
    'location',
    'tenant_id',
  ]);
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
            ${
              rows
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
                </tr>`,
                )
                .join('') || tableEmpty(6)
            }
          </tbody>
        </table>
      </div>
    </section>
  `;
}

async function editListing(id) {
  const listing = state.data.listings.find((item) => item.id === id);
  if (!listing) return;
  const title =
    window.prompt('Listing title', listing.title || '') ?? listing.title;
  const category =
    window.prompt('Category', listing.category || '') ?? listing.category;
  const location =
    window.prompt('Location', listing.location || '') ?? listing.location;
  const description =
    window.prompt('Description', listing.description || '') ??
    listing.description;
  const price_min = Number(
    window.prompt('Minimum price', listing.price_min ?? 0) ??
      listing.price_min ??
      0,
  );
  const price_max = Number(
    window.prompt('Maximum price', listing.price_max ?? price_min) ??
      listing.price_max ??
      price_min,
  );
  await updateTableRow(
    'listings',
    id,
    { title, category, location, description, price_min, price_max },
    'Listing updated.',
  );
}

async function editJob(id) {
  const job = state.data.jobs.find((item) => item.id === id);
  if (!job) return;
  const title = window.prompt('Job title', job.title || '') ?? job.title;
  const status = window.prompt('Status', job.status || 'active') ?? job.status;
  const location =
    window.prompt('Location', job.location || '') ?? job.location;
  const description =
    window.prompt('Description', job.description || '') ?? job.description;
  const budget = Number(
    window.prompt('Budget', job.budget ?? 0) ?? job.budget ?? 0,
  );
  await updateTableRow(
    'jobs',
    id,
    { title, status, location, description, budget },
    'Job updated.',
  );
}

function renderSettings() {
  return `
    <section class="panel narrow">
      <h2>Vercel Environment</h2>
      <div class="setting-row">
        <span>Backend URL</span>
        <strong>${supabaseUrl ? 'Configured' : 'Missing'}</strong>
      </div>
      <div class="setting-row">
        <span>Backend publishable key</span>
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

function publicHeader() {
  const signedIn = Boolean(state.session);
  return `
    <header class="site-header">
      <button class="site-brand" data-link="/">
        <img src="/prosme_logo.png" alt="ProSME" />
        <span>ProSME</span>
      </button>
      <input class="site-menu-toggle" id="site-menu-toggle" type="checkbox" aria-label="Open menu" />
      <label class="site-menu-button" for="site-menu-toggle" aria-hidden="true">
        <span></span>
        <span></span>
        <span></span>
      </label>
      <nav class="site-nav" aria-label="Main navigation">
        ${publicNav
          .map(
            ([path, label]) =>
              `<button class="${state.publicPage === path ? 'active' : ''}" data-link="${path}">${label}</button>`,
          )
          .join('')}
      </nav>
      <div class="site-actions site-auth-actions">
        ${
          signedIn
            ? `<button class="ghost small" data-action="refresh-portal">Refresh</button>
               <button class="ghost small" data-action="sign-out">Sign out</button>`
            : `<button class="ghost small" data-link="/login">Log in</button>
               <button class="primary compact-button" data-link="/signup">Sign up</button>`
        }
      </div>
    </header>
  `;
}

function publicFooter() {
  return `
    <footer class="site-footer">
      <div>
        <strong>Blumebyte ProSME</strong>
        <p>Professional service matching, job tracking, verification, invoices, and account tools for customers and artisans.</p>
        <small>Built for practical SME service work across Ghana and beyond.</small>
      </div>
      <div>
        <strong>Company</strong>
        <button data-link="/about">About</button>
        <a href="https://blumebyte.com/contact/">Contact</a>
        <button data-link="/terms">Terms</button>
      </div>
      <div>
        <strong>Policies</strong>
        <button data-link="/privacy">Privacy</button>
        <button data-link="/security">Security</button>
        <button data-link="/cookies">Cookies</button>
      </div>
      <div>
        <strong>Blumebyte online</strong>
        ${socials.map(([label, href]) => `<a href="${href}" target="_blank" rel="noreferrer">${label}</a>`).join('')}
      </div>
    </footer>
  `;
}

function renderPublicLayout(content) {
  return `
    <div class="site-page public-site" onmousemove="this.style.setProperty('--mouse-x', event.clientX + 'px'); this.style.setProperty('--mouse-y', event.clientY + 'px')">
      <div class="cursor-glow" aria-hidden="true"></div>
      ${publicHeader()}
      <main>${content}</main>
      ${publicFooter()}
    </div>
  `;
}

function renderHome() {
  return renderPublicLayout(`
    <section class="hero-section hero-showcase" style="--hero-image:url('${artisanImages.market}')">
      <div class="hero-copy">
        <span class="eyebrow">Built by Blumebyte</span>
        <h1>Find verified artisans. Manage service work.</h1>
        <p>
          Post jobs, receive bids, chat, track work, manage verification, and keep invoices in one connected account.
        </p>
        <div class="hero-actions">
          <button class="primary compact-button" data-link="/signup">Create an account</button>
          <button class="ghost" data-link="/login">Log in</button>
          <a class="ghost button-link" href="https://blumebyte.com/contact/">Contact Blumebyte</a>
        </div>
      </div>
      <div class="product-panel" aria-label="ProSME service snapshot">
        <div class="product-top">
          <span>Live service desk</span>
          <strong>Requests, bids, payments</strong>
        </div>
        <div class="product-row"><span>Open job requests</span><strong>Find work</strong></div>
        <div class="product-row"><span>Verified artisans</span><strong>Badge tracking</strong></div>
        <div class="product-row"><span>Invoices</span><strong>PDF + wallet</strong></div>
        <div class="product-row"><span>Notifications</span><strong>Email + dashboard</strong></div>
      </div>
    </section>
    ${smeScene({
      image: artisanImages.craft,
      eyebrow: '3D service flow',
      title: 'Built around the way SMEs win, deliver, and repeat work.',
      body: 'The public website now mirrors the product: layered, traceable, and designed for customers and artisans moving from first request to finished work.',
    })}
    <section class="site-section insight-strip">
      <article class="glass-mini"><strong>Request</strong><span>Describe the work clearly.</span></article>
      <article class="glass-mini"><strong>Compare</strong><span>Review bids, profiles, and verification.</span></article>
      <article class="glass-mini"><strong>Track</strong><span>Keep chat, invoices, and status together.</span></article>
      <article class="glass-mini"><strong>Grow</strong><span>Help serious SMEs earn repeat work.</span></article>
    </section>
    ${smeBanner()}
    <section class="site-section">
      <div class="section-head">
        <span class="eyebrow">What it does</span>
        <h2>Tools for the full service journey</h2>
      </div>
      <div class="feature-grid">
        ${[
          {
            title: 'Job requests',
            body: 'Customers can describe work, location, budget, and receive bids from artisans.',
            image: artisanImages.request,
          },
          {
            title: 'Artisan marketplace',
            body: 'Artisans list services, manage bids, and build trust with ratings and verified status.',
            image: artisanImages.marketplace,
          },
          {
            title: 'Verification subscriptions',
            body: 'Accepted users and artisans keep verification active through monthly or yearly Paystack billing.',
            image: artisanImages.verification,
          },
          {
            title: 'Chat and alerts',
            body: 'Messages, status changes, reports, and verification decisions stay visible in the account.',
            image: artisanImages.chat,
          },
          {
            title: 'Invoices and wallet tracking',
            body: 'Accepted work creates invoice and wallet records for clearer payment follow-up.',
            image: artisanImages.invoices,
          },
          {
            title: 'Connected work history',
            body: 'Customers and artisans can return to their requests, bids, alerts, invoices, and account records from the same ProSME profile.',
            image: artisanImages.account,
          },
        ]
          .map((card) => imageCard(card))
          .join('')}
      </div>
    </section>
    <section class="site-section sme-info-grid">
      ${[
        {
          title: 'SME visibility',
          body: 'Artisans can show service areas, skills, ratings, and verification status so customers can compare options before contacting them.',
          image: artisanImages.visibility,
        },
        {
          title: 'Work records',
          body: 'Requests, bids, invoices, wallet records, and notifications create a clearer history than scattered phone calls and screenshots.',
          image: artisanImages.records,
        },
        {
          title: 'Local growth',
          body: 'Digital profiles make it easier for small teams, solo makers, repairers, builders, and home-service providers to earn repeat work.',
          image: artisanImages.growth,
        },
      ]
        .map((card) => imageCard({ ...card, className: 'sme-info-card' }))
        .join('')}
    </section>
    <section class="site-section narrative-panel">
      <div>
        <span class="eyebrow">For everyday operations</span>
        <h2>One place for the moments that usually get lost.</h2>
      </div>
      <p>
        ProSME gives customers and artisans a shared record of what was requested, who responded, what was agreed, and what still needs attention. It is designed for repeat service work, trust-building, and clear follow-up.
      </p>
    </section>
    <section class="site-section journey-panel">
      ${[
        {
          label: '01',
          title: 'A customer describes the job',
          body: 'The request captures location, budget, photos, and context so artisans can respond with better bids.',
        },
        {
          label: '02',
          title: 'Artisans compete with trust',
          body: 'Profiles, service areas, ratings, and verification status make comparison clearer before a chat starts.',
        },
        {
          label: '03',
          title: 'Accepted work stays recorded',
          body: 'Bids, invoices, wallet records, notifications, and decisions remain available after the work is done.',
        },
      ]
        .map((step) => journeyStep(step))
        .join('')}
    </section>
  `);
}

function renderAboutPage() {
  return renderPublicLayout(`
    <section class="page-hero page-hero-split">
      <div>
        <span class="eyebrow">About ProSME</span>
        <h1>Blumebyte built ProSME for practical service work, not just listings.</h1>
        <p>
          ProSME helps customers find artisans and gives artisans a structured place to manage opportunities, verification, payments, and service history.
        </p>
      </div>
      <div class="page-hero-image" style="--hero-image:url('${artisanImages.textile}')"></div>
    </section>
    ${smeBanner({
      image: artisanImages.textile,
      eyebrow: 'About ProSME',
      title: 'Digital tools for artisans, service teams, and the customers who rely on them.',
      body: 'The platform is designed around practical SME workflows: find work, prove identity, organize jobs, and keep communication traceable.',
    })}
    ${smeScene({
      image: artisanImages.training,
      eyebrow: 'Local business depth',
      title: 'A stronger digital layer for work that still depends on trust.',
      body: 'The platform supports the practical details small teams need: identity, communication, accepted bids, records, and follow-up.',
    })}
    <section class="site-section about-story">
      <div class="glass-copy">
        <span class="eyebrow">Why this matters</span>
        <h2>SMEs need visibility, trust, and records they can return to.</h2>
        <p>Small service businesses often win work through relationships, referrals, and fast responses. ProSME adds a digital layer around those habits so customers can act with more confidence and artisans can keep better proof of their work.</p>
      </div>
      <div class="story-image" style="background-image:url('${artisanImages.training}')"></div>
    </section>
    <section class="site-section two-column">
      ${[
        {
          title: 'Why it exists',
          body: 'Small businesses and independent professionals often manage requests, quotes, documents, payments, and follow-ups across too many channels. ProSME brings those steps into one account.',
          image: artisanImages.records,
        },
        {
          title: 'Who it serves',
          body: 'Customers can request services and track accepted work. Artisans can receive jobs, prove their identity, manage bids, and keep verified status active.',
          image: artisanImages.marketplace,
        },
      ]
        .map((card) => imageCard({ ...card, className: 'about-card' }))
        .join('')}
    </section>
  `);
}

function renderFeaturesPage() {
  return renderPublicLayout(`
    <section class="page-hero page-hero-split">
      <div>
        <span class="eyebrow">Features</span>
        <h1>Service operations for customers, artisans, and administrators.</h1>
        <p>Each workflow is designed around the real steps of service work: request, compare, chat, approve, pay, and follow up.</p>
      </div>
      <div class="page-hero-image" style="--hero-image:url('${artisanImages.craft}')"></div>
    </section>
    ${smeBanner({
      image: artisanImages.craft,
      eyebrow: 'SME workflows',
      title: 'From first request to paid work, each tab supports a real service step.',
      body: 'Customers can search and request help; artisans can manage listings, bids, verification, messages, bookings, and profile trust signals.',
    })}
    ${smeScene({
      image: artisanImages.support,
      eyebrow: 'Layered controls',
      title: 'Every role gets the right surface without losing the shared record.',
      body: 'Customers see requests and accepted work. Artisans see listings, bids, verification, and payments. Admins see the review controls that keep the marketplace accountable.',
    })}
    <section class="site-section feature-list">
      ${[
        {
          title: 'For customers',
          body: 'Create requests, compare bids, chat with artisans, receive alerts, and keep invoice records.',
          image: artisanImages.request,
        },
        {
          title: 'For artisans',
          body: 'Manage listings, bid on requests, track work history, renew verification, and keep payment records.',
          image: artisanImages.craft,
        },
        {
          title: 'For admins',
          body: 'Review documents, approve payment-required verification, confirm Paystack references, request more information, reject, or override when needed.',
          image: artisanImages.support,
        },
        {
          title: 'For trust',
          body: 'Verification status, expiration checks, renewal tracking, and email/dashboard notifications are built into the workflow.',
          image: artisanImages.verification,
        },
      ]
        .map((card) => wideFeatureCard(card))
        .join('')}
    </section>
    <section class="site-section narrative-panel">
      <div>
        <span class="eyebrow">Designed for clarity</span>
        <h2>Every action leaves a useful trail.</h2>
      </div>
      <p>Profiles, verification, messages, jobs, bids, invoices, notifications, and admin decisions are connected so users can understand what happened and what to do next.</p>
    </section>
  `);
}

function renderPolicyPage(type) {
  const pages = {
    '/terms': {
      title: 'Terms of Service',
      eyebrow: 'Fair work rules',
      image: artisanImages.records,
      body: 'Use ProSME to request, offer, manage, and track legitimate services. Users are responsible for accurate account details, lawful documents, fair communication, and honoring accepted job terms.',
      cards: [
        ['Marketplace role', 'ProSME helps customers and artisans discover, message, negotiate, and record service requests. Private work agreements remain the responsibility of the customer and artisan unless a separate written contract says otherwise.'],
        ['User conduct', 'Accounts may be limited when activity appears fraudulent, unsafe, abusive, misleading, unlawful, or harmful to marketplace trust.'],
        ['Service records', 'Requests, bids, invoices, wallet records, messages, reports, and verification decisions may be kept to support safety, disputes, and account history.'],
      ],
    },
    '/privacy': {
      title: 'Privacy Policy',
      eyebrow: 'Data and trust',
      image: artisanImages.planning,
      body: 'ProSME uses account, profile, job, bid, chat, verification, notification, and payment reference data to operate the service. Payment card or bank details are handled by Paystack.',
      cards: [
        ['Data collected', 'Profile details, listings, requests, bids, messages, verification documents, reports, notifications, payment references, and account activity help operate the marketplace.'],
        ['How it is used', 'Data supports authentication, service matching, artisan verification, safety review, support, alerts, dispute context, abuse prevention, and transaction records.'],
        ['User choices', 'Users can update profile details, request account deletion, report unsafe activity, block chats, and contact Blumebyte about data access or correction.'],
      ],
    },
    '/security': {
      title: 'Security Policy',
      eyebrow: 'Protected access',
      image: artisanImages.verification,
      body: 'Passwords, recovery links, and verification emails use protected account services. Admin tools run through server functions, and service keys are not exposed in browser code.',
      cards: [
        ['Account protection', 'Email verification, password recovery, and configured sign-in providers protect access to customer, artisan, and admin accounts.'],
        ['Access controls', 'Database access rules restrict private data and limit verification, report, and admin review tools to authorized accounts.'],
        ['Incident response', 'Report suspicious behavior or security concerns through Support or Blumebyte contact so the team can review account and platform activity.'],
      ],
    },
    '/cookies': {
      title: 'Cookie Policy',
      eyebrow: 'Session clarity',
      image: artisanImages.account,
      body: 'The web app uses browser storage and secure session cookies or tokens to keep users signed in and route them to the correct customer, artisan, or admin experience.',
      cards: [
        ['Session storage', 'Local browser storage helps keep the account session active and remembers the right web experience after login.'],
        ['Functional use', 'Cookies and tokens support authentication, navigation, security checks, and continuity between public pages and the account portal.'],
        ['User control', 'Users can clear browser storage or sign out to remove the local session from the current device.'],
      ],
    },
  };
  const page = pages[type] || pages['/terms'];
  return renderPublicLayout(`
    <section class="page-hero page-hero-split policy-hero">
      <div>
        <span class="eyebrow">${esc(page.eyebrow)}</span>
        <h1>${esc(page.title)}</h1>
        <p>${esc(page.body)}</p>
        <a class="ghost button-link" href="https://blumebyte.com/contact/">Questions? Contact Blumebyte</a>
      </div>
      <div class="page-hero-image" style="--hero-image:url('${page.image}')"></div>
    </section>
    ${smeScene({
      image: page.image,
      eyebrow: 'Policy workflow',
      title: 'Rules stay close to the work they protect.',
      body: 'The policies are written around real SME activity: account access, service records, verification, payments, support review, and safe communication.',
    })}
    <section class="site-section policy-list policy-grid">
      ${page.cards
        .map(
          ([heading, copy]) =>
            `<article><span class="eyebrow">ProSME</span><h2>${esc(heading)}</h2><p>${esc(copy)}</p></article>`,
        )
        .join('')}
      <article><span class="eyebrow">Payments</span><h2>Paystack processing</h2><p>Verification subscription payments are processed through Paystack. ProSME tracks payment references, subscription status, renewals, expiry, and admin overrides.</p></article>
      <article><span class="eyebrow">Support</span><h2>Platform decisions</h2><p>Verification, reports, disputes, and abuse checks may be reviewed by admins. Admin decisions may request more information, reject a submission, or temporarily restrict features.</p></article>
      <article><span class="eyebrow">Account</span><h2>Account responsibility</h2><p>Keep login details private, use accurate profile information, and notify Blumebyte if your account or verification documents may be compromised.</p></article>
    </section>
  `);
}

function renderAuthPage(mode = state.authMode) {
  const isSignup = mode === 'signup';
  return renderPublicLayout(`
    <section class="auth-layout">
      <div>
        <span class="eyebrow">Account access</span>
        <h1>${isSignup ? 'Create your ProSME account' : 'Log in to ProSME'}</h1>
        <p>Your browser account uses the same secure login as the mobile app, so profile, verification, job, bid, invoice, and notification data stay connected.</p>
      </div>
      <form class="login-card" id="${isSignup ? 'signup-form' : 'login-form'}">
        <img src="/prosme_logo.png" alt="ProSME" />
        <h2>${isSignup ? 'Sign up' : 'Welcome back'}</h2>
        ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
        ${state.notice ? `<div class="notice">${esc(state.notice)}</div>` : ''}
        ${
          isSignup
            ? `<label>
                Full name or business name
                <input name="full_name" autocomplete="name" placeholder="Your name or business" required />
              </label>
              <label>
                Account type
                <select name="role">
                  <option value="customer">Customer</option>
                  <option value="artisan">Artisan</option>
                </select>
              </label>`
            : ''
        }
        <label>
          Email
          <input name="email" type="email" autocomplete="email" placeholder="Email address" required />
        </label>
        <label>
          Password
          <input name="password" type="password" autocomplete="${isSignup ? 'new-password' : 'current-password'}" minlength="8" required />
        </label>
        <button class="primary" ${state.busy ? 'disabled' : ''}>${state.busy ? 'Please wait...' : isSignup ? 'Create account' : 'Log in'}</button>
        ${
          !isSignup && state.pendingConfirmationEmail
            ? `<button class="ghost full-width" type="button" data-action="resend-confirmation" ${state.busy ? 'disabled' : ''}>Resend confirmation email</button>`
            : ''
        }
        <small>
          ${
            isSignup
              ? 'Already have an account? <button type="button" class="text-button" data-link="/login">Log in</button>'
              : 'New to ProSME? <button type="button" class="text-button" data-link="/signup">Create an account</button>'
          }
        </small>
      </form>
    </section>
  `);
}

function renderPortal() {
  const profile = state.profile || {};
  const isArtisan = profile.role === 'artisan';
  const ownJobs = state.data.jobs.filter(
    (job) => job.created_by === profile.id,
  );
  const relevantBids = state.data.bids.filter(
    (bid) => bid.artisan_id === profile.id,
  );
  const walletTotal = state.data.walletTransactions.reduce(
    (sum, item) => sum + Number(item.amount || 0),
    0,
  );
  return `
    <div class="site-page portal-page">
      ${publicHeader()}
      <main class="portal-main">
        <section class="portal-head">
          <div>
            <span class="eyebrow">${esc(profile.role || 'customer')} account</span>
            <h1>${esc(profile.full_name || profile.email || 'Your ProSME account')}</h1>
            <p>Review your requests, bids, wallet records, and account alerts in one place.</p>
          </div>
          <div class="row-actions">
            ${roleBadge(profile.role)}
            ${statusBadge(profile.verification_status)}
            <button class="ghost" data-action="refresh-portal">Refresh</button>
            <button class="ghost" data-action="sign-out">Sign out</button>
          </div>
        </section>
        ${Object.keys(state.tableErrors).length ? renderTableErrors() : ''}
        <section class="stat-grid">
          <article class="stat-card"><span>${isArtisan ? 'Bids sent' : 'Your requests'}</span><strong>${isArtisan ? relevantBids.length : ownJobs.length}</strong><small>Synced from ProSME</small></article>
          <article class="stat-card"><span>Wallet records</span><strong>${state.data.walletTransactions.length}</strong><small>${money(walletTotal)} tracked</small></article>
          <article class="stat-card"><span>Alerts</span><strong>${state.data.notifications.length}</strong><small>Dashboard notifications</small></article>
        </section>
        <section class="grid two">
          <article class="panel">
            <div class="panel-head"><h2>${isArtisan ? 'Open job requests' : 'Your job requests'}</h2></div>
            ${renderPortalJobs(isArtisan ? state.data.jobs : ownJobs)}
          </article>
          <article class="panel">
            <div class="panel-head"><h2>${isArtisan ? 'Your bids' : 'Available services'}</h2></div>
            ${isArtisan ? renderPortalBids(relevantBids) : renderPortalListings(state.data.listings)}
          </article>
        </section>
      </main>
      ${publicFooter()}
    </div>
  `;
}

function renderPortalJobs(items) {
  if (!items.length) return '<p class="empty">No job records yet.</p>';
  return `<div class="list">${items
    .slice(0, 8)
    .map(
      (job) => `
        <div class="list-row">
          <div><strong>${esc(job.title || 'Untitled job')}</strong><small>${esc(job.location || '')} · ${dateText(job.created_at)}</small></div>
          ${statusBadge(job.status || 'open')}
        </div>`,
    )
    .join('')}</div>`;
}

function renderPortalBids(items) {
  if (!items.length) return '<p class="empty">No bids yet.</p>';
  return `<div class="list">${items
    .slice(0, 8)
    .map(
      (bid) => `
        <div class="list-row">
          <div><strong>${money(bid.amount)}</strong><small>${dateText(bid.created_at)}</small></div>
          ${statusBadge(bid.status || 'pending')}
        </div>`,
    )
    .join('')}</div>`;
}

function renderPortalListings(items) {
  if (!items.length) return '<p class="empty">No service listings yet.</p>';
  return `<div class="list">${items
    .slice(0, 8)
    .map(
      (listing) => `
        <div class="list-row">
          <div><strong>${esc(listing.title || 'Service')}</strong><small>${esc(listing.location || listing.category || '')}</small></div>
          <span>${money(listing.price_min || listing.price_max || 0)}</span>
        </div>`,
    )
    .join('')}</div>`;
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
        <small>The web dashboard does not store passwords.</small>
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
    return renderShell(
      '<div class="loading">Loading ProSME dashboard...</div>',
    );
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
  } else if (!hasConfig) {
    if (state.publicPage === '/about') {
      app.innerHTML = renderAboutPage();
    } else if (state.publicPage === '/features') {
      app.innerHTML = renderFeaturesPage();
    } else if (
      ['/terms', '/privacy', '/security', '/cookies'].includes(state.publicPage)
    ) {
      app.innerHTML = renderPolicyPage(state.publicPage);
    } else if (state.publicPage === '/signup') {
      app.innerHTML = renderAuthPage('signup');
    } else if (state.publicPage === '/login') {
      app.innerHTML = renderAuthPage('login');
    } else {
      app.innerHTML = renderHome();
    }
  } else if (!state.session) {
    if (state.publicPage === '/login') {
      app.innerHTML = renderAuthPage('login');
    } else if (state.publicPage === '/signup') {
      app.innerHTML = renderAuthPage('signup');
    } else if (state.publicPage === '/about') {
      app.innerHTML = renderAboutPage();
    } else if (state.publicPage === '/features') {
      app.innerHTML = renderFeaturesPage();
    } else if (
      ['/terms', '/privacy', '/security', '/cookies'].includes(state.publicPage)
    ) {
      app.innerHTML = renderPolicyPage(state.publicPage);
    } else {
      app.innerHTML = renderHome();
    }
  } else if (state.loading) {
    app.innerHTML = renderPublicLayout(
      '<div class="loading">Loading your ProSME account...</div>',
    );
  } else if (state.profile?.role === 'admin') {
    app.innerHTML = renderContent();
  } else {
    app.innerHTML = renderPortal();
  }
  bindEvents();
  trackPublicPageView().catch(() => {});
}

function bindEvents() {
  document.querySelector('#login-form')?.addEventListener('submit', signIn);
  document.querySelector('#signup-form')?.addEventListener('submit', signUp);
  document
    .querySelector('#password-recovery-form')
    ?.addEventListener('submit', updateRecoveredPassword);
  document
    .querySelector('[data-action="resend-confirmation"]')
    ?.addEventListener('click', resendConfirmationEmail);

  document.querySelectorAll('[data-link]').forEach((element) => {
    element.addEventListener('click', (event) => {
      event.preventDefault();
      navigate(element.dataset.link || '/');
    });
  });

  document.querySelectorAll('[data-tab]').forEach((button) => {
    button.addEventListener('click', () => {
      state.tab = button.dataset.tab;
      render();
    });
  });

  document
    .querySelectorAll('[data-action="sign-out"]')
    .forEach((button) => button.addEventListener('click', signOut));
  document
    .querySelector('[data-action="print"]')
    ?.addEventListener('click', () => window.print());
  document
    .querySelector('[data-action="refresh"]')
    ?.addEventListener('click', async () => {
      state.loading = true;
      render();
      await refreshData();
      state.loading = false;
      setNotice('Dashboard refreshed.');
      render();
    });

  document
    .querySelector('[data-action="refresh-portal"]')
    ?.addEventListener('click', async () => {
      state.loading = true;
      render();
      await refreshPortalData();
      state.loading = false;
      setNotice('Account refreshed.');
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
    button.addEventListener('click', () =>
      setVerification(button.dataset.id, button.dataset.verify),
    );
  });

  document.querySelectorAll('[data-billing-action]').forEach((button) => {
    button.addEventListener('click', () =>
      syncVerificationBilling(button.dataset.billingAction),
    );
  });

  document.querySelectorAll('[data-confirm-paystack]').forEach((button) => {
    button.addEventListener('click', () =>
      confirmPaystackReference(button.dataset.confirmPaystack),
    );
  });

  document.querySelectorAll('[data-override-verify]').forEach((button) => {
    button.addEventListener('click', () =>
      overrideVerificationPaid(button.dataset.overrideVerify),
    );
  });

  document.querySelectorAll('[data-request-extra]').forEach((button) => {
    button.addEventListener('click', () =>
      requestExtraVerification(button.dataset.requestExtra),
    );
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
    select.addEventListener('change', () =>
      updateRole(select.dataset.roleUser, select.value),
    );
  });

  document.querySelectorAll('[data-edit-profile]').forEach((button) => {
    button.addEventListener('click', () =>
      updateProfile(button.dataset.editProfile),
    );
  });

  document.querySelectorAll('[data-reset-email]').forEach((button) => {
    button.addEventListener('click', () =>
      sendPasswordReset(button.dataset.resetEmail),
    );
  });

  document.querySelectorAll('[data-random-password]').forEach((button) => {
    button.addEventListener('click', () =>
      randomizePassword(button.dataset.randomPassword, button.dataset.email),
    );
  });

  document.querySelectorAll('[data-delete-account]').forEach((button) => {
    button.addEventListener('click', () =>
      deleteAccount(button.dataset.deleteAccount, button.dataset.email),
    );
  });

  document.querySelectorAll('[data-create-role]').forEach((button) => {
    button.addEventListener('click', () =>
      createAccount(button.dataset.createRole),
    );
  });

  document
    .querySelector('[data-import-accounts]')
    ?.addEventListener('change', (event) => {
      importAccounts(event.target.files?.[0]);
      event.target.value = '';
    });

  document
    .querySelector('[data-create-listing]')
    ?.addEventListener('click', createListing);
  document
    .querySelector('[data-create-job]')
    ?.addEventListener('click', createJob);

  document.querySelectorAll('[data-edit-listing]').forEach((button) => {
    button.addEventListener('click', () =>
      editListing(button.dataset.editListing),
    );
  });

  document.querySelectorAll('[data-edit-job]').forEach((button) => {
    button.addEventListener('click', () => editJob(button.dataset.editJob));
  });

  document.querySelectorAll('[data-delete-row]').forEach((button) => {
    button.addEventListener('click', () =>
      deleteTableRow(button.dataset.deleteRow, button.dataset.id),
    );
  });
}

init();
