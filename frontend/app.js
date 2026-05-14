const state = {
  apiBaseUrl: getDefaultApiBaseUrl(),
  storeCode: 'GT-0145',
  categoryCode: 'BEBIDAS',
  pendingRecommendations: [],
  budgetRows: [],
  selectedBudgetRowId: '',
  posBudgetDate: '',
};

const posDefaults = {
  sourceId: 'pos-evt-001',
  storeCode: 'GT-0145',
  categoryCode: 'BEBIDAS',
  qty: '2',
  price: '3500',
};

const posSkuPool = [
  'SKU-1001',
  'SKU-1002',
  'SKU-1003',
  'SKU-2001',
  'SKU-3001',
];

function getDefaultApiBaseUrl() {
  if (window.location.protocol === 'file:') {
    return '/api';
  }

  if (window.location.pathname.startsWith('/csp/store-console')) {
    return '/csp/store-console';
  }

  if (window.location.pathname.startsWith('/csp/')) {
    return '/csp/user/API.UIController.cls';
  }

  if (window.location.pathname === '/') {
    return '/api';
  }

  return normalizeBaseUrl(window.location.pathname.endsWith('/')
    ? window.location.pathname.slice(0, -1)
    : window.location.pathname);
}

const elements = {
  apiBaseUrl: document.getElementById('apiBaseUrl'),
  storeCode: document.getElementById('storeCode'),
  categoryCode: document.getElementById('categoryCode'),
  healthStatus: document.getElementById('healthStatus'),
  storeLabel: document.getElementById('storeLabel'),
  categoryLabel: document.getElementById('categoryLabel'),
  paceValue: document.getElementById('paceValue'),
  pendingCount: document.getElementById('pendingCount'),
  dashboardCount: document.getElementById('dashboardCount'),
  paceCard: document.getElementById('paceCard'),
  recommendationsList: document.getElementById('recommendationsList'),
  dashboardList: document.getElementById('dashboardList'),
  budgetForm: document.getElementById('budgetForm'),
  budgetFilterDate: document.getElementById('budgetFilterDate'),
  budgetFilterStoreCode: document.getElementById('budgetFilterStoreCode'),
  budgetFilterCategoryCode: document.getElementById('budgetFilterCategoryCode'),
  budgetFilterInternalSku: document.getElementById('budgetFilterInternalSku'),
  budgetDate: document.getElementById('budgetDate'),
  budgetStoreCode: document.getElementById('budgetStoreCode'),
  budgetCategoryCode: document.getElementById('budgetCategoryCode'),
  budgetInternalSku: document.getElementById('budgetInternalSku'),
  budgetTargetUnits: document.getElementById('budgetTargetUnits'),
  budgetTargetRevenue: document.getElementById('budgetTargetRevenue'),
  budgetResult: document.getElementById('budgetResult'),
  budgetCount: document.getElementById('budgetCount'),
  budgetList: document.getElementById('budgetList'),
  posForm: document.getElementById('posForm'),
  posSourceId: document.getElementById('posSourceId'),
  posStoreCode: document.getElementById('posStoreCode'),
  posTimestamp: document.getElementById('posTimestamp'),
  posCategoryCode: document.getElementById('posCategoryCode'),
  posInternalSku: document.getElementById('posInternalSku'),
  posQty: document.getElementById('posQty'),
  posPrice: document.getElementById('posPrice'),
  posResult: document.getElementById('posResult'),
  loadPosSampleBtn: document.getElementById('loadPosSampleBtn'),
  feedbackForm: document.getElementById('feedbackForm'),
  feedbackResult: document.getElementById('feedbackResult'),
  recommendationId: document.getElementById('recommendationId'),
  feedbackStatus: document.getElementById('feedbackStatus'),
  acceptedBy: document.getElementById('acceptedBy'),
  notes: document.getElementById('notes'),
  refreshAllBtn: document.getElementById('refreshAllBtn'),
  loadPaceBtn: document.getElementById('loadPaceBtn'),
  loadPendingBtn: document.getElementById('loadPendingBtn'),
  loadDashboardBtn: document.getElementById('loadDashboardBtn'),
  loadBudgetsBtn: document.getElementById('loadBudgetsBtn'),
  budgetFilterResetBtn: document.getElementById('budgetFilterResetBtn'),
  budgetResetBtn: document.getElementById('budgetResetBtn'),
  budgetReloadBtn: document.getElementById('budgetReloadBtn'),
  clearFeedbackBtn: document.getElementById('clearFeedbackBtn'),
  recommendationTemplate: document.getElementById('recommendationTemplate'),
  tabOpsBtn: document.getElementById('tabOpsBtn'),
  tabPosBtn: document.getElementById('tabPosBtn'),
  tabBudgetBtn: document.getElementById('tabBudgetBtn'),
  tabOps: document.getElementById('tabOps'),
  tabPos: document.getElementById('tabPos'),
  tabBudget: document.getElementById('tabBudget'),
};

function readConfig() {
  state.apiBaseUrl = normalizeBaseUrl(elements.apiBaseUrl.value.trim() || getDefaultApiBaseUrl());
  state.storeCode = elements.storeCode.value.trim() || 'GT-0145';
  state.categoryCode = elements.categoryCode.value.trim() || 'BEBIDAS';
  elements.storeLabel.textContent = state.storeCode;
  elements.categoryLabel.textContent = state.categoryCode;
  if (elements.budgetStoreCode) {
    elements.budgetStoreCode.value = state.storeCode;
  }
  if (elements.budgetCategoryCode) {
    elements.budgetCategoryCode.value = state.categoryCode;
  }
}

function normalizeBaseUrl(value) {
  return value.endsWith('/') ? value.slice(0, -1) : value;
}

async function requestJson(path, options = {}) {
  const headers = { ...(options.headers || {}) };
  const hasBody = Object.prototype.hasOwnProperty.call(options, 'body') && options.body !== undefined && options.body !== null;
  if (hasBody && !headers['Content-Type']) {
    headers['Content-Type'] = 'application/json';
  }

  const response = await fetch(`${state.apiBaseUrl}${path}`, {
    ...options,
    headers,
  });

  const text = await response.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch (error) {
    data = { raw: text };
  }

  if (!response.ok) {
    const message = data?.error || data?.message || response.statusText || 'Request failed';
    throw new Error(message);
  }

  return data;
}

function setLoading(element, isLoading) {
  element.classList.toggle('is-loading', isLoading);
}

function formatValue(value, fallback = '--') {
  if (value === null || value === undefined || value === '') {
    return fallback;
  }
  return value;
}

function getCurrentUtcTimestamp() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function getCurrentUtcDate() {
  return new Date().toISOString().slice(0, 10);
}

function toUtcTimestampForDate(dateValue) {
  const timePart = getCurrentUtcTimestamp().slice(11);
  return `${dateValue}T${timePart}`;
}

function getBudgetDateDefault() {
  return state.posBudgetDate || getCurrentUtcDate();
}

function getRandomPosSku() {
  return posSkuPool[Math.floor(Math.random() * posSkuPool.length)];
}

function resetPosSample() {
  elements.posSourceId.value = posDefaults.sourceId;
  elements.posStoreCode.value = posDefaults.storeCode;
  elements.posTimestamp.value = state.posBudgetDate ? toUtcTimestampForDate(state.posBudgetDate) : getCurrentUtcTimestamp();
  elements.posCategoryCode.value = posDefaults.categoryCode;
  elements.posInternalSku.value = getRandomPosSku();
  elements.posQty.value = posDefaults.qty;
  elements.posPrice.value = posDefaults.price;
}

function resetBudgetSample() {
  state.selectedBudgetRowId = '';
  elements.budgetDate.value = getBudgetDateDefault();
  elements.budgetStoreCode.value = state.storeCode;
  elements.budgetCategoryCode.value = state.categoryCode;
  elements.budgetInternalSku.value = '';
  elements.budgetTargetUnits.value = '0';
  elements.budgetTargetRevenue.value = '0';
  elements.budgetResult.textContent = 'Budget form ready.';
}

function syncBudgetFilterDefaults() {
  if (elements.budgetFilterDate && !elements.budgetFilterDate.value) {
    elements.budgetFilterDate.value = getBudgetDateDefault();
  }

  if (elements.budgetFilterStoreCode && !elements.budgetFilterStoreCode.value) {
    elements.budgetFilterStoreCode.value = state.storeCode;
  }

  if (elements.budgetFilterCategoryCode && !elements.budgetFilterCategoryCode.value) {
    elements.budgetFilterCategoryCode.value = state.categoryCode;
  }
}

async function loadPosBudgetContext() {
  readConfig();
  try {
    const data = await requestJson(`/budget/context/${encodeURIComponent(state.storeCode)}/${encodeURIComponent(state.categoryCode)}`);
    if (data?.budgetDate) {
      state.posBudgetDate = data.budgetDate;
      elements.posResult.textContent = `Budget context loaded for ${data.budgetDate}.`;
    } else {
      state.posBudgetDate = '';
      elements.posResult.textContent = 'No budget context found for this store/category.';
    }
  } catch (error) {
    state.posBudgetDate = '';
    elements.posResult.textContent = `Budget context load failed: ${error.message}`;
  }

  resetPosSample();
  resetBudgetSample();
  syncBudgetFilterDefaults();
}

function buildBudgetPayload() {
  return {
    budget_date: elements.budgetDate.value.trim(),
    store_code: elements.budgetStoreCode.value.trim(),
    category_code: elements.budgetCategoryCode.value.trim(),
    internal_sku: elements.budgetInternalSku.value.trim(),
    target_units: Number(elements.budgetTargetUnits.value),
    target_revenue: Number(elements.budgetTargetRevenue.value),
  };
}

function renderBudgetRow(item) {
  const node = document.createElement('article');
  node.className = 'budget-row';
  const isSelected = state.selectedBudgetRowId && state.selectedBudgetRowId === String(item.rowId || '');
  node.classList.toggle('is-selected', Boolean(isSelected));
  node.dataset.rowId = String(item.rowId || '');
  node.innerHTML = `
    <div class="budget-cell budget-cell--emphasis">${formatValue(item.budgetDate)}</div>
    <div class="budget-cell">${formatValue(item.storeCode)}</div>
    <div class="budget-cell">${formatValue(item.categoryCode)}</div>
    <div class="budget-cell">${item.internalSku || 'CATEGORY ROLLUP'}</div>
    <div class="budget-cell budget-cell--numeric">${formatValue(item.targetUnits)}</div>
    <div class="budget-cell budget-cell--numeric">${formatValue(item.targetRevenue)}</div>
    <div class="budget-cell">${formatValue(item.loadedAt)}</div>
    <div class="budget-cell budget-cell--actions">
      <button class="button button--ghost budget-edit-btn" type="button">Load</button>
    </div>
  `;

  node.querySelector('.budget-edit-btn').addEventListener('click', () => {
    state.selectedBudgetRowId = item.rowId || '';
    elements.budgetDate.value = item.budgetDate || getBudgetDateDefault();
    elements.budgetStoreCode.value = item.storeCode || state.storeCode;
    elements.budgetCategoryCode.value = item.categoryCode || state.categoryCode;
    elements.budgetInternalSku.value = item.internalSku || '';
    elements.budgetTargetUnits.value = String(item.targetUnits ?? 0);
    elements.budgetTargetRevenue.value = String(item.targetRevenue ?? 0);
    elements.budgetResult.textContent = `Loaded budget row ${formatValue(item.rowId)}.`;
  });

  return node;
}

function renderBudgets(items) {
  elements.budgetList.innerHTML = '';
  const uniqueDays = new Set(items.map((item) => item.budgetDate).filter(Boolean));
  elements.budgetCount.textContent = `${items.length} row${items.length === 1 ? '' : 's'} · ${uniqueDays.size} day${uniqueDays.size === 1 ? '' : 's'}`;

  if (!items.length) {
    elements.budgetList.classList.add('state-card--empty');
    elements.budgetList.innerHTML = '<p>No budget rows match the current filters.</p>';
    return;
  }

  elements.budgetList.classList.remove('state-card--empty');
  for (const item of items) {
    elements.budgetList.appendChild(renderBudgetRow(item));
  }
}

function buildBudgetQueryParams() {
  const params = new URLSearchParams();
  const budgetDate = elements.budgetFilterDate.value.trim();
  const storeCode = elements.budgetFilterStoreCode.value.trim();
  const categoryCode = elements.budgetFilterCategoryCode.value.trim();
  const internalSku = elements.budgetFilterInternalSku.value.trim();

  if (budgetDate) params.set('budgetDate', budgetDate);
  if (storeCode) params.set('storeCode', storeCode);
  if (categoryCode) params.set('categoryCode', categoryCode);
  if (internalSku) params.set('internalSku', internalSku);

  return params;
}

function filterBudgetRows(items) {
  const budgetDate = elements.budgetFilterDate.value.trim();
  const storeCode = elements.budgetFilterStoreCode.value.trim();
  const categoryCode = elements.budgetFilterCategoryCode.value.trim();
  const internalSku = elements.budgetFilterInternalSku.value.trim();

  return items.filter((item) => {
    if (budgetDate && item.budgetDate !== budgetDate) {
      return false;
    }

    if (storeCode && item.storeCode !== storeCode) {
      return false;
    }

    if (categoryCode && item.categoryCode !== categoryCode) {
      return false;
    }

    if (internalSku && (item.internalSku || '') !== internalSku) {
      return false;
    }

    return true;
  });
}

async function loadBudgets() {
  readConfig();

  try {
    setLoading(elements.budgetList, true);
    elements.budgetList.innerHTML = '<p>Loading budget rows...</p>';
    const data = await requestJson('/budgets');
    state.budgetRows = Array.isArray(data) ? data : [];
    renderBudgets(filterBudgetRows(state.budgetRows));
  } catch (error) {
    elements.budgetList.innerHTML = `<p>${error.message}</p>`;
    elements.budgetCount.textContent = '0 rows · 0 days';
  } finally {
    setLoading(elements.budgetList, false);
  }
}

function clearBudgetFilters() {
  state.selectedBudgetRowId = '';
  elements.budgetFilterDate.value = '';
  elements.budgetFilterStoreCode.value = '';
  elements.budgetFilterCategoryCode.value = '';
  elements.budgetFilterInternalSku.value = '';
  void loadBudgets();
}

async function submitBudget(event) {
  event.preventDefault();
  readConfig();

  const payload = buildBudgetPayload();
  if (!payload.budget_date || !payload.store_code || !payload.category_code) {
    elements.budgetResult.textContent = 'Fill budget day, store and category before saving.';
    return;
  }

  try {
    setLoading(elements.budgetResult, true);
    elements.budgetResult.textContent = 'Saving budget...';
    const response = await requestJson('/budgets', {
      method: 'POST',
      body: JSON.stringify(payload),
    });

    state.selectedBudgetRowId = '';
    elements.budgetResult.textContent = `Saved ${response?.storeCode || payload.store_code} / ${response?.categoryCode || payload.category_code} / ${response?.budgetDate || payload.budget_date}.`;
    elements.budgetResult.classList.add('flash');
    window.setTimeout(() => elements.budgetResult.classList.remove('flash'), 1200);
    await loadBudgets();
  } catch (error) {
    elements.budgetResult.textContent = `Budget save failed: ${error.message}`;
  } finally {
    setLoading(elements.budgetResult, false);
  }
}

function clearBudgetForm() {
  resetBudgetSample();
}

function buildPosPayload() {
  return {
    source_id: elements.posSourceId.value.trim(),
    store_code: elements.posStoreCode.value.trim(),
    timestamp: elements.posTimestamp.value.trim(),
    category_code: elements.posCategoryCode.value.trim(),
    internal_sku: elements.posInternalSku.value.trim(),
    qty: Number(elements.posQty.value),
    price: Number(elements.posPrice.value),
  };
}

function renderPosResult(data) {
  if (data?.status === 'ok') {
    elements.posResult.textContent = `Sent ${formatValue(data.sourceId)} to ${formatValue(data.storeCode)} / ${formatValue(data.categoryCode)}.`;
    return;
  }

  elements.posResult.textContent = data?.error ? `POS send failed: ${data.error}` : 'POS send failed.';
}

function setActiveTab(tabName) {
  const tabs = [
    { button: elements.tabOpsBtn, panel: elements.tabOps, name: 'ops' },
    { button: elements.tabPosBtn, panel: elements.tabPos, name: 'pos' },
    { button: elements.tabBudgetBtn, panel: elements.tabBudget, name: 'budget' },
  ];

  for (const tab of tabs) {
    const isActive = tab.name === tabName;
    tab.button.classList.toggle('is-active', isActive);
    tab.button.setAttribute('aria-selected', String(isActive));
    tab.panel.classList.toggle('is-active', isActive);
    tab.panel.hidden = !isActive;
  }

  if (tabName === 'pos') {
    void loadPosBudgetContext();
  }

  if (tabName === 'budget') {
    void loadBudgets();
  }
}

function renderPace(data) {
  if (data?.error === 'PACE_NOT_FOUND') {
    elements.paceCard.innerHTML = '<p>No pace row found for the selected store and category.</p>';
    elements.paceValue.textContent = 'No data';
    return;
  }

  elements.paceCard.innerHTML = `
    <div class="metric-grid">
      <div class="recommendation-item">
        <strong>${formatValue(data.paceId)}</strong>
        <p>Pace ID</p>
      </div>
      <div class="recommendation-item">
        <strong>${formatValue(data.paceHour)}</strong>
        <p>Hour</p>
      </div>
      <div class="recommendation-item">
        <strong>${formatValue(data.unitsSold)}</strong>
        <p>Units sold</p>
      </div>
      <div class="recommendation-item">
        <strong>${formatValue(data.unitsBudget)}</strong>
        <p>Budget units</p>
      </div>
      <div class="recommendation-item">
        <strong>${formatValue(data.varianceUnits)}</strong>
        <p>Variance units</p>
      </div>
      <div class="recommendation-item">
        <strong>${formatValue(data.pctPaceUnits)}</strong>
        <p>% pace units</p>
      </div>
    </div>
  `;
  elements.paceValue.textContent = `${formatValue(data.pctPaceUnits)}%`;
}

function renderRecommendations(items) {
  elements.recommendationsList.innerHTML = '';

  if (!items.length) {
    elements.recommendationsList.classList.add('state-card--empty');
    elements.recommendationsList.innerHTML = '<p>No pending recommendations right now.</p>';
    elements.pendingCount.textContent = '0';
    return;
  }

  elements.recommendationsList.classList.remove('state-card--empty');
  elements.pendingCount.textContent = String(items.length);

  for (const item of items) {
    const node = elements.recommendationTemplate.content.cloneNode(true);
    node.querySelector('.rec-title').textContent = item.ActionDescription || item.ActionCode || 'Recommendation';
    node.querySelector('.rec-subtitle').textContent = `${item.StoreCode} · ${item.CategoryCode} · ${item.RelatedPaceId || 'no pace id'}`;
    node.querySelector('.rec-status').textContent = item.Status || 'PENDING';
    node.querySelector('.rec-rule').textContent = item.RuleFired || '--';
    node.querySelector('.rec-priority').textContent = formatValue(item.RulePriority);
    node.querySelector('.rec-severity').textContent = formatValue(item.RuleSeverity);
    node.querySelector('.rec-window').textContent = `${formatValue(item.RuleWindowType)} · ${formatValue(item.RuleThreshold)}`;
    node.querySelector('.rec-message').textContent = item.BusinessMessage || '';

    node.querySelector('.select-rec-btn').addEventListener('click', () => {
      elements.recommendationId.value = item.RecommendationId;
      elements.feedbackResult.textContent = `Loaded recommendation ${item.RecommendationId}`;
      elements.feedbackResult.classList.add('flash');
      window.setTimeout(() => elements.feedbackResult.classList.remove('flash'), 1200);
    });

    elements.recommendationsList.appendChild(node);
  }
}

function renderDashboard(data) {
  elements.dashboardList.innerHTML = '';
  const items = Array.isArray(data.categories) ? data.categories : [];
  elements.dashboardCount.textContent = String(items.length);

  if (!items.length) {
    elements.dashboardList.classList.add('state-card--empty');
    elements.dashboardList.innerHTML = '<p>No dashboard rows available for the selected store.</p>';
    return;
  }

  elements.dashboardList.classList.remove('state-card--empty');
  for (const row of items) {
    const item = document.createElement('article');
    item.className = 'dashboard-item';
    item.innerHTML = `
      <div class="recommendation-item__top">
        <div>
          <strong>${row.CategoryCode || '--'}</strong>
          <p>${row.PaceHour ?? '--'}h · ${row.PaceId || ''}</p>
        </div>
        <span class="pill">${formatValue(row.Status || row.ExecutionState || 'PACE')}</span>
      </div>
      <div class="rec-grid">
        <div><dt>Units sold</dt><dd>${formatValue(row.UnitsSold)}</dd></div>
        <div><dt>Variance</dt><dd>${formatValue(row.VarianceUnits)}</dd></div>
        <div><dt>Budget units</dt><dd>${formatValue(row.UnitsBudget)}</dd></div>
        <div><dt>Last updated</dt><dd>${formatValue(row.LastUpdated)}</dd></div>
      </div>
    `;
    elements.dashboardList.appendChild(item);
  }
}

async function loadHealth() {
  try {
    setLoading(elements.healthStatus, true);
    const data = await requestJson('/health');
    elements.healthStatus.textContent = data.status || 'ok';
  } catch (error) {
    elements.healthStatus.textContent = 'error';
    elements.feedbackResult.textContent = `Health check failed: ${error.message}`;
  } finally {
    setLoading(elements.healthStatus, false);
  }
}

async function loadPace() {
  readConfig();
  try {
    setLoading(elements.paceCard, true);
    elements.paceCard.innerHTML = '<p>Loading pace...</p>';
    const data = await requestJson(`/stores/${encodeURIComponent(state.storeCode)}/categories/${encodeURIComponent(state.categoryCode)}/pace`);
    renderPace(data);
  } catch (error) {
    elements.paceCard.innerHTML = `<p>${error.message}</p>`;
  } finally {
    setLoading(elements.paceCard, false);
  }
}

async function loadPendingRecommendations() {
  readConfig();
  try {
    setLoading(elements.recommendationsList, true);
    elements.recommendationsList.innerHTML = '<p>Loading pending recommendations...</p>';
    const data = await requestJson(`/recommendations/pending/${encodeURIComponent(state.storeCode)}`);
    state.pendingRecommendations = Array.isArray(data) ? data : [];
    renderRecommendations(state.pendingRecommendations);
  } catch (error) {
    elements.recommendationsList.innerHTML = `<p>${error.message}</p>`;
  } finally {
    setLoading(elements.recommendationsList, false);
  }
}

async function loadDashboard() {
  readConfig();
  try {
    setLoading(elements.dashboardList, true);
    elements.dashboardList.innerHTML = '<p>Loading dashboard...</p>';
    const data = await requestJson(`/dashboard/store/${encodeURIComponent(state.storeCode)}`);
    renderDashboard(data);
  } catch (error) {
    elements.dashboardList.innerHTML = `<p>${error.message}</p>`;
  } finally {
    setLoading(elements.dashboardList, false);
  }
}

async function submitPosMock(event) {
  event.preventDefault();

  const payload = buildPosPayload();
  if (!payload.source_id || !payload.store_code || !payload.timestamp || !payload.category_code || !payload.internal_sku || Number.isNaN(payload.qty) || Number.isNaN(payload.price)) {
    elements.posResult.textContent = 'Fill all POS fields before sending.';
    return;
  }

  try {
    setLoading(elements.posResult, true);
    elements.posResult.textContent = 'Sending mock POS...';
    const response = await requestJson('/pos/ingest', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    renderPosResult(response);
    setActiveTab('ops');
    await refreshAll();
    resetPosSample();
  } catch (error) {
    renderPosResult({ error: error.message });
  } finally {
    setLoading(elements.posResult, false);
  }
}

async function submitFeedback(event) {
  event.preventDefault();
  readConfig();

  const recommendationId = elements.recommendationId.value.trim();
  if (!recommendationId) {
    elements.feedbackResult.textContent = 'Select a recommendation first.';
    return;
  }

  try {
    const params = new URLSearchParams({
    });
    const response = await requestJson(`/recommendations/${encodeURIComponent(recommendationId)}/feedback/${encodeURIComponent(elements.feedbackStatus.value)}/${encodeURIComponent(elements.acceptedBy.value.trim() || 'store.manager')}/${encodeURIComponent(elements.notes.value.trim() || '-')}`, {
      method: 'POST',
    });

    elements.feedbackResult.textContent = `Saved feedback for ${recommendationId} (${response?.after?.Status || elements.feedbackStatus.value}).`;
    elements.feedbackResult.classList.add('flash');
    window.setTimeout(() => elements.feedbackResult.classList.remove('flash'), 1200);
    await loadPendingRecommendations();
  } catch (error) {
    elements.feedbackResult.textContent = `Feedback failed: ${error.message}`;
  }
}

function clearFeedback() {
  elements.recommendationId.value = '';
  elements.acceptedBy.value = '';
  elements.notes.value = '';
  elements.feedbackStatus.value = 'ACCEPTED';
}

function wireEvents() {
  elements.apiBaseUrl.addEventListener('change', readConfig);
  elements.storeCode.addEventListener('change', () => { readConfig(); void loadPosBudgetContext(); });
  elements.categoryCode.addEventListener('change', () => { readConfig(); void loadPosBudgetContext(); });
  elements.refreshAllBtn.addEventListener('click', refreshAll);
  elements.tabOpsBtn.addEventListener('click', () => setActiveTab('ops'));
  elements.tabPosBtn.addEventListener('click', () => setActiveTab('pos'));
  elements.tabBudgetBtn.addEventListener('click', () => setActiveTab('budget'));
  elements.loadPosSampleBtn.addEventListener('click', resetPosSample);
  elements.posForm.addEventListener('submit', submitPosMock);
  elements.budgetForm.addEventListener('submit', submitBudget);
  elements.loadPaceBtn.addEventListener('click', loadPace);
  elements.loadPendingBtn.addEventListener('click', loadPendingRecommendations);
  elements.loadDashboardBtn.addEventListener('click', loadDashboard);
  elements.loadBudgetsBtn.addEventListener('click', loadBudgets);
  elements.budgetFilterDate.addEventListener('change', loadBudgets);
  elements.budgetFilterStoreCode.addEventListener('change', loadBudgets);
  elements.budgetFilterCategoryCode.addEventListener('change', loadBudgets);
  elements.budgetFilterInternalSku.addEventListener('change', loadBudgets);
  elements.budgetFilterResetBtn.addEventListener('click', clearBudgetFilters);
  elements.budgetReloadBtn.addEventListener('click', loadBudgets);
  elements.budgetResetBtn.addEventListener('click', clearBudgetForm);
  elements.feedbackForm.addEventListener('submit', submitFeedback);
  elements.clearFeedbackBtn.addEventListener('click', clearFeedback);
}

async function refreshAll() {
  readConfig();
  await Promise.all([loadHealth(), loadPace(), loadPendingRecommendations(), loadDashboard(), loadBudgets()]);
}

async function boot() {
  if (elements.apiBaseUrl.value.trim() === '/api' && (window.location.pathname.startsWith('/csp/') || window.location.pathname !== '/')) {
    elements.apiBaseUrl.value = getDefaultApiBaseUrl();
  }
  resetPosSample();
  clearFeedback();
  readConfig();
  wireEvents();
  setActiveTab('ops');
  await loadPosBudgetContext();
  syncBudgetFilterDefaults();
  await refreshAll();
}

void boot();
