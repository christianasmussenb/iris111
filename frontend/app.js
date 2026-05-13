const state = {
  apiBaseUrl: getDefaultApiBaseUrl(),
  storeCode: 'GT-0145',
  categoryCode: 'BEBIDAS',
  pendingRecommendations: [],
};

function getDefaultApiBaseUrl() {
  if (window.location.pathname.includes('/csp/')) {
    return '/csp/user/API.UIController.cls';
  }

  return '/api';
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
  clearFeedbackBtn: document.getElementById('clearFeedbackBtn'),
  recommendationTemplate: document.getElementById('recommendationTemplate'),
};

function readConfig() {
  state.apiBaseUrl = normalizeBaseUrl(elements.apiBaseUrl.value.trim() || getDefaultApiBaseUrl());
  state.storeCode = elements.storeCode.value.trim() || 'GT-0145';
  state.categoryCode = elements.categoryCode.value.trim() || 'BEBIDAS';
  elements.storeLabel.textContent = state.storeCode;
  elements.categoryLabel.textContent = state.categoryCode;
}

function normalizeBaseUrl(value) {
  return value.endsWith('/') ? value.slice(0, -1) : value;
}

async function requestJson(path, options = {}) {
  const response = await fetch(`${state.apiBaseUrl}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
    ...options,
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

async function submitFeedback(event) {
  event.preventDefault();
  readConfig();

  const recommendationId = elements.recommendationId.value.trim();
  if (!recommendationId) {
    elements.feedbackResult.textContent = 'Select a recommendation first.';
    return;
  }

  try {
    const response = await requestJson(`/recommendations/${encodeURIComponent(recommendationId)}/feedback`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        status: elements.feedbackStatus.value,
        acceptedBy: elements.acceptedBy.value.trim(),
        notes: elements.notes.value.trim(),
      }).toString(),
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
  elements.storeCode.addEventListener('change', readConfig);
  elements.categoryCode.addEventListener('change', readConfig);
  elements.refreshAllBtn.addEventListener('click', refreshAll);
  elements.loadPaceBtn.addEventListener('click', loadPace);
  elements.loadPendingBtn.addEventListener('click', loadPendingRecommendations);
  elements.loadDashboardBtn.addEventListener('click', loadDashboard);
  elements.feedbackForm.addEventListener('submit', submitFeedback);
  elements.clearFeedbackBtn.addEventListener('click', clearFeedback);
}

async function refreshAll() {
  readConfig();
  await Promise.all([loadHealth(), loadPace(), loadPendingRecommendations(), loadDashboard()]);
}

function boot() {
  if (window.location.pathname.includes('/csp/') && elements.apiBaseUrl.value.trim() === '/api') {
    elements.apiBaseUrl.value = getDefaultApiBaseUrl();
  }
  clearFeedback();
  readConfig();
  wireEvents();
  refreshAll();
}

boot();
