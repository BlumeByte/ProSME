const price = new Intl.NumberFormat('en-GH', {
  style: 'currency',
  currency: 'GHS',
  currencyDisplay: 'code',
});

const imageUrl = (url) => {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' ? parsed.href : '';
  } catch {
    return '';
  }
};

export function renderStorefront(heroImage) {
  return `
    <div class="storefront">
      <section class="shop-hero" style="--shop-hero-image:url('${heroImage}')">
        <h1>Shop local services</h1>
        <p>Find skilled professionals and book the service you need.</p>
      </section>
      <form class="shop-search" id="shop-search" aria-label="Find services">
        <label>Service <input name="keyword" type="search" placeholder="What service do you need?" /></label>
        <label>Location <input name="location" type="search" placeholder="City, town, or area" /></label>
        <button class="primary compact-button">Search</button>
      </form>
      <div class="shop-categories" id="shop-categories" role="group" aria-label="Service categories"></div>
      <section aria-labelledby="shop-title">
        <div class="shop-toolbar">
          <div>
            <h2 id="shop-title">Browse services</h2>
            <p id="shop-count" role="status" aria-live="polite"></p>
          </div>
          <label>Sort by
            <select id="shop-sort" aria-label="Sort services">
              <option value="newest">Newest</option>
              <option value="price-low">Price: low to high</option>
              <option value="price-high">Price: high to low</option>
            </select>
          </label>
        </div>
        <div id="shop-results" class="shop-grid" aria-busy="true"><p>Loading services…</p></div>
      </section>
      <dialog class="shop-dialog" id="shop-detail" aria-labelledby="shop-detail-title"></dialog>
    </div>`;
}

export function createStorefront(client, esc, images) {
  let catalogRequest;

  async function fetchCatalog() {
    const { data, error } = await client.from('listings')
      .select('id,artisan_id,title,description,category,price_min,images,location')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false })
      .limit(100);
    if (error) throw error;
    const artisanIds = [...new Set(data.map(({ artisan_id }) => artisan_id).filter(Boolean))];
    const profiles = new Map();
    if (artisanIds.length) {
      const { data: artisans } = await client.from('profiles')
        .select('id,full_name,username,verification_status')
        .in('id', artisanIds);
      for (const artisan of artisans ?? []) profiles.set(artisan.id, artisan);
    }
    return data.map((listing) => ({ ...listing, artisan: profiles.get(listing.artisan_id) }));
  }

  return async function bindStorefront(root) {
    if (!root) return;
    const form = root.querySelector('#shop-search');
    const results = root.querySelector('#shop-results');
    const count = root.querySelector('#shop-count');
    const categories = root.querySelector('#shop-categories');
    const sort = root.querySelector('#shop-sort');
    const dialog = root.querySelector('#shop-detail');
    const searchText = (value) => String(value ?? '').trim().toLowerCase();
    let selectedCategory = '';
    let listings;
    form.addEventListener('submit', (event) => {
      event.preventDefault();
      if (listings) draw();
    });
    try {
      if (!client) throw new Error('Catalog is unavailable');
      catalogRequest ??= fetchCatalog().catch((error) => {
        catalogRequest = undefined;
        throw error;
      });
      listings = await catalogRequest;
    } catch {
      results.setAttribute('aria-busy', 'false');
      results.innerHTML = '<p class="shop-empty">Services could not be loaded. <button type="button" class="ghost small">Try again</button></p>';
      results.querySelector('button').addEventListener('click', () => window.location.reload());
      return;
    }
    if (!root.isConnected) return;
    results.setAttribute('aria-busy', 'false');

    const labelFor = (listing) => listing.artisan?.full_name || listing.artisan?.username || '';
    const fallbackCover = (listing) => {
      const category = searchText(listing.category);
      return Object.hasOwn(images, category) ? images[category] : images.default;
    };
    const coverFor = (listing) =>
      (Array.isArray(listing.images) ? listing.images.map(imageUrl).find(Boolean) : '') ||
      fallbackCover(listing);
    results.addEventListener('error', (event) => {
      const image = event.target;
      const fallback = image.dataset?.fallback;
      if (!fallback) return;
      delete image.dataset.fallback;
      image.src = fallback;
    }, true);
    const listingPrice = (listing) => listing.price_min != null && Number.isFinite(Number(listing.price_min))
      ? `From ${price.format(Number(listing.price_min))}`
      : 'Ask for a quote';
    const bookingUrl = (listing) => `/app/#/listing/${encodeURIComponent(listing.id)}`;
    const categoryNames = [...new Set(listings.map(({ category }) => category).filter(Boolean))].sort();
    for (const category of ['', ...categoryNames]) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'shop-category';
      button.textContent = category || 'All services';
      button.setAttribute('aria-pressed', String(!category));
      button.addEventListener('click', () => {
        selectedCategory = category;
        for (const sibling of categories.children) sibling.setAttribute('aria-pressed', String(sibling === button));
        draw();
      });
      categories.append(button);
    }
    sort.addEventListener('change', draw);
    results.addEventListener('click', (event) => {
      const trigger = event.target.closest('[data-shop-listing]');
      if (!trigger) return;
      const listing = listings.find(({ id }) => id === trigger.dataset.shopListing);
      if (!listing) return;
      dialog.innerHTML = `
        <form method="dialog"><button class="ghost small" aria-label="Close service details" autofocus>Close</button></form>
        <h2 id="shop-detail-title">${esc(listing.title)}</h2>
        <p>${esc([labelFor(listing), listing.location].filter(Boolean).join(' · '))}</p>
        <p>${esc(listing.description)}</p>
        <strong>${esc(listingPrice(listing))}</strong>
        <a class="primary button-link" href="${esc(bookingUrl(listing))}">Book in app</a>`;
      dialog.showModal();
    });

    function draw() {
      const keyword = searchText(form.elements.keyword.value);
      const location = searchText(form.elements.location.value);
      const filtered = listings.filter((listing) =>
        (!selectedCategory || selectedCategory === listing.category) &&
        searchText(listing.location).includes(location) &&
        keyword.split(/\s+/).every((part) => searchText(
          [listing.title, listing.description, listing.category, labelFor(listing)].join(' '),
        ).includes(part)),
      );
      if (sort.value !== 'newest') {
        const direction = sort.value === 'price-low' ? 1 : -1;
        filtered.sort((a, b) => a.price_min == null ? Number(b.price_min != null) :
          b.price_min == null ? -1 : direction * (a.price_min - b.price_min));
      }
      count.textContent = `${filtered.length} ${filtered.length === 1 ? 'service' : 'services'}`;
      results.innerHTML = filtered.map((listing) => `
        <article class="shop-card">
          <img class="shop-card-image" src="${esc(coverFor(listing))}" data-fallback="${esc(fallbackCover(listing))}" alt="" loading="lazy" width="640" height="360" />
          <div class="shop-card-content">
            <div class="shop-tags">
              ${listing.category ? `<span>${esc(listing.category)}</span>` : ''}
              ${listing.artisan?.verification_status === 'verified' ? '<span class="shop-verified">✓ Verified</span>' : ''}
            </div>
            <h3>${esc(listing.title)}</h3>
            <p class="shop-artisan">${esc([labelFor(listing), listing.location].filter(Boolean).join(' · '))}</p>
            <strong class="shop-price">${esc(listingPrice(listing))}</strong>
            <div class="shop-card-actions">
              <button type="button" class="ghost small" data-shop-listing="${esc(listing.id)}">Details</button>
              <a class="primary button-link" href="${esc(bookingUrl(listing))}">Book in app</a>
            </div>
          </div>
        </article>`).join('') ||
        '<p class="shop-empty">No services match. Try another search or category.</p>';
    }

    draw();
  };
}
