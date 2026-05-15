const state = {
  apiBaseUrl: getDefaultApiBaseUrl(),
  storeCode: 'GT-0145',
  categoryCode: 'BEBIDAS',
  healthStatus: '--',
  paceData: null,
  pendingRecommendations: [],
  dashboardRows: [],
  budgetRows: [],
  selectedBudgetRowId: '',
  posBudgetDate: '',
  lastFeedbackMessage: 'Aun no se envio feedback.',
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
  stageGrid: document.getElementById('stageGrid'),
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
  themeOverviewBtn: document.getElementById('themeOverviewBtn'),
  themeConnectionBtn: document.getElementById('themeConnectionBtn'),
  themeStagesBtn: document.getElementById('themeStagesBtn'),
  themeOpsBtn: document.getElementById('themeOpsBtn'),
  themePosBtn: document.getElementById('themePosBtn'),
  themeBudgetBtn: document.getElementById('themeBudgetBtn'),
  panelOverview: document.getElementById('panelOverview'),
  panelConnection: document.getElementById('panelConnection'),
  panelStages: document.getElementById('panelStages'),
  panelOperations: document.getElementById('panelOperations'),
  panelPos: document.getElementById('panelPos'),
  panelBudget: document.getElementById('panelBudget'),
};

function readConfig() {
  state.apiBaseUrl = normalizeBaseUrl(elements.apiBaseUrl.value.trim() || getDefaultApiBaseUrl());
  state.storeCode = elements.storeCode.value.trim() || 'GT-0145';
  state.categoryCode = elements.categoryCode.value.trim() || 'BEBIDAS';
  elements.storeLabel.textContent = state.storeCode;
  elements.categoryLabel.textContent = state.categoryCode;
  renderStages();
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
    const message = data?.error || data?.message || response.statusText || 'La solicitud fallo';
    throw new Error(message);
  }

  return data;
}

function setLoading(element, isLoading) {
  element.classList.toggle('is-loading', isLoading);
}

function translateUiStatus(value) {
  const normalized = String(value || '').toUpperCase();
  const map = {
    OK: 'operativo',
    ERROR: 'error',
    CONNECTED: 'conectado',
    PENDING: 'pendiente',
    NEW: 'nueva',
    ACCEPTED: 'aceptada',
    REJECTED: 'rechazada',
    MODIFIED: 'modificada',
    EXECUTED: 'ejecutada',
    CLEAR: 'sin pendientes',
    ATTENTION: 'atencion',
    UPDATED: 'actualizado',
    WAITING: 'en espera',
    GOOD: 'ok',
    WARN: 'alerta',
    DANGER: 'critico',
    PACE: 'ritmo',
  };

  return map[normalized] || value || '--';
}

function setActiveTheme(themeName) {
  const tabs = [
    { button: elements.themeOverviewBtn, panel: elements.panelOverview, name: 'overview' },
    { button: elements.themeConnectionBtn, panel: elements.panelConnection, name: 'connection' },
    { button: elements.themeStagesBtn, panel: elements.panelStages, name: 'stages' },
    { button: elements.themeOpsBtn, panel: elements.panelOperations, name: 'operations' },
    { button: elements.themePosBtn, panel: elements.panelPos, name: 'pos' },
    { button: elements.themeBudgetBtn, panel: elements.panelBudget, name: 'budget' },
  ];

  for (const tab of tabs) {
    const isActive = tab.name === themeName;
    tab.button.classList.toggle('is-active', isActive);
    tab.button.setAttribute('aria-selected', String(isActive));
    tab.panel.hidden = !isActive;
  }

  if (themeName === 'operations') {
    void Promise.all([loadPace(), loadPendingRecommendations(), loadDashboard()]);
  }

  if (themeName === 'pos') {
    void loadPosBudgetContext();
  }

  if (themeName === 'budget') {
    void loadBudgets();
  }

  renderStages();
}

function createStageCard({ title, subtitle, value, note, statusLabel, tone = 'neutral', metrics = [] }) {
  const article = document.createElement('article');
  article.className = `stage-card stage-card--${tone}`;
  article.innerHTML = `
    <div class="stage-card__top">
      <div>
        <p class="stage-card__subtitle">${subtitle}</p>
        <h3>${title}</h3>
      </div>
      <span class="pill stage-pill stage-pill--${tone}">${statusLabel}</span>
    </div>
    <strong class="stage-card__value">${value}</strong>
    <p class="stage-card__note">${note}</p>
    <dl class="stage-metrics">
      ${metrics.map((metric) => `
        <div>
          <dt>${metric.label}</dt>
          <dd>${metric.value}</dd>
        </div>
      `).join('')}
    </dl>
  `;
  return article;
}

function renderStages() {
  if (!elements.stageGrid) {
    return;
  }

  const pace = state.paceData || {};
  const recCount = state.pendingRecommendations.length;
  const dashboardCount = state.dashboardRows.length;
  const paceTone = pace?.error === 'PACE_NOT_FOUND'
    ? 'warn'
    : Number(pace?.pctPaceUnits) >= 100
      ? 'good'
      : Number(pace?.pctPaceUnits) >= 90
        ? 'warn'
        : 'danger';
  const recommendationTone = recCount === 0 ? 'good' : 'warn';
  const feedbackTone = state.lastFeedbackMessage.startsWith('Feedback guardado') ? 'good' : 'neutral';
  const paceStatusLabel = pace?.error === 'PACE_NOT_FOUND'
    ? 'SIN DATOS'
    : paceTone === 'good'
      ? 'OK'
      : paceTone === 'warn'
        ? 'ALERTA'
        : 'CRITICO';
  const recommendationStatusLabel = recCount === 0 ? 'SIN PENDIENTES' : 'ATENCION';
  const feedbackStatusLabel = state.lastFeedbackMessage.startsWith('Feedback guardado') ? 'ACTUALIZADO' : 'EN ESPERA';

  elements.stageGrid.innerHTML = '';
  elements.stageGrid.appendChild(createStageCard({
    title: 'Ingesta',
    subtitle: 'Configuracion en tiempo real',
    value: state.apiBaseUrl,
    note: 'La consola esta lista para leer y escribir contra el endpoint activo de IRIS.',
    statusLabel: 'CONECTADO',
    tone: 'good',
    metrics: [
      { label: 'Local', value: state.storeCode },
      { label: 'Categoria', value: state.categoryCode },
      { label: 'Contexto de presupuesto', value: state.posBudgetDate || 'pendiente' },
    ],
  }));

  elements.stageGrid.appendChild(createStageCard({
    title: 'Calculo',
    subtitle: 'Gold / ritmo',
    value: pace?.error === 'PACE_NOT_FOUND' ? 'Sin fila de cadencia de ventas' : `${formatValue(pace?.pctPaceUnits)}% de cadencia de ventas`,
    note: pace?.error === 'PACE_NOT_FOUND'
      ? 'No existe una fila de cadencia de ventas para el local y la categoria seleccionados.'
      : 'Este bloque resume la senal mas reciente de ventas contra presupuesto que expone Gold.',
    statusLabel: paceStatusLabel,
    tone: paceTone,
    metrics: [
      { label: 'Unidades vendidas', value: formatValue(pace?.unitsSold) },
      { label: 'Unidades presupuestadas', value: formatValue(pace?.unitsBudget) },
      { label: 'Variacion', value: formatValue(pace?.varianceUnits) },
    ],
  }));

  const firstRecommendation = state.pendingRecommendations[0];
  elements.stageGrid.appendChild(createStageCard({
    title: 'Recomendaciones',
    subtitle: 'Salida del motor de reglas',
    value: recCount === 0 ? 'Sin pendientes' : `${recCount} pendientes`,
    note: firstRecommendation
      ? firstRecommendation.BusinessMessage || firstRecommendation.ActionDescription || 'La recomendacion pendiente esta lista para revision.'
      : 'Cuando una regla dispara, la cola de recomendaciones se vuelve el punto de control del operador.',
    statusLabel: recommendationStatusLabel,
    tone: recommendationTone,
    metrics: firstRecommendation ? [
      { label: 'Prioridad', value: formatValue(firstRecommendation.RulePriority) },
      { label: 'Severidad', value: formatValue(firstRecommendation.RuleSeverity) },
      { label: 'Regla', value: formatValue(firstRecommendation.RuleFired) },
    ] : [
      { label: 'Prioridad', value: '--' },
      { label: 'Severidad', value: '--' },
      { label: 'Regla', value: '--' },
    ],
  }));

  elements.stageGrid.appendChild(createStageCard({
    title: 'Feedback',
    subtitle: 'Cierre operativo',
    value: state.lastFeedbackMessage,
    note: 'Esta etapa cierra el ciclo al persistir la respuesta del operador y refrescar la cola pendiente.',
    statusLabel: feedbackStatusLabel,
    tone: feedbackTone,
    metrics: [
      { label: 'Backlog pendiente', value: String(recCount) },
      { label: 'Filas del panel', value: String(dashboardCount) },
      { label: 'Salud', value: state.healthStatus },
    ],
  }));
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
  elements.budgetResult.textContent = 'Formulario de presupuesto listo.';
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
      elements.posResult.textContent = `Contexto de presupuesto cargado para ${data.budgetDate}.`;
    } else {
      state.posBudgetDate = '';
      elements.posResult.textContent = 'No se encontro contexto de presupuesto para este local/categoria.';
    }
  } catch (error) {
    state.posBudgetDate = '';
    elements.posResult.textContent = `Error al cargar el contexto de presupuesto: ${error.message}`;
  }

  resetPosSample();
  resetBudgetSample();
  syncBudgetFilterDefaults();
  renderStages();
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
    <div class="budget-cell">${item.internalSku || 'CONSOLIDADO DE CATEGORIA'}</div>
    <div class="budget-cell budget-cell--numeric">${formatValue(item.targetUnits)}</div>
    <div class="budget-cell budget-cell--numeric">${formatValue(item.targetRevenue)}</div>
    <div class="budget-cell">${formatValue(item.loadedAt)}</div>
    <div class="budget-cell budget-cell--actions">
      <button class="button button--ghost budget-edit-btn" type="button">Cargar</button>
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
    elements.budgetResult.textContent = `Fila de presupuesto cargada ${formatValue(item.rowId)}.`;
  });

  return node;
}

function renderBudgets(items) {
  elements.budgetList.innerHTML = '';
  const uniqueDays = new Set(items.map((item) => item.budgetDate).filter(Boolean));
  elements.budgetCount.textContent = `${items.length} fila${items.length === 1 ? '' : 's'} · ${uniqueDays.size} dia${uniqueDays.size === 1 ? '' : 's'}`;

  if (!items.length) {
    elements.budgetList.classList.add('state-card--empty');
    elements.budgetList.innerHTML = '<p>No hay filas de presupuesto que coincidan con los filtros actuales.</p>';
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
    elements.budgetList.innerHTML = '<p>Cargando filas de presupuesto...</p>';
    const data = await requestJson('/budgets');
    state.budgetRows = Array.isArray(data) ? data : [];
    renderBudgets(filterBudgetRows(state.budgetRows));
  } catch (error) {
    elements.budgetList.innerHTML = `<p>${error.message}</p>`;
    elements.budgetCount.textContent = '0 filas · 0 dias';
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
    elements.budgetResult.textContent = 'Completa el dia, el local y la categoria antes de guardar.';
    return;
  }

  try {
    setLoading(elements.budgetResult, true);
    elements.budgetResult.textContent = 'Guardando presupuesto...';
    const response = await requestJson('/budgets', {
      method: 'POST',
      body: JSON.stringify(payload),
    });

    state.selectedBudgetRowId = '';
    elements.budgetResult.textContent = `Guardado ${response?.storeCode || payload.store_code} / ${response?.categoryCode || payload.category_code} / ${response?.budgetDate || payload.budget_date}.`;
    elements.budgetResult.classList.add('flash');
    window.setTimeout(() => elements.budgetResult.classList.remove('flash'), 1200);
    await loadBudgets();
  } catch (error) {
    elements.budgetResult.textContent = `Error al guardar el presupuesto: ${error.message}`;
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
    elements.posResult.textContent = `Enviado ${formatValue(data.sourceId)} a ${formatValue(data.storeCode)} / ${formatValue(data.categoryCode)}.`;
    return;
  }

  elements.posResult.textContent = data?.error ? `Error al enviar el POS: ${data.error}` : 'Error al enviar el POS.';
}

function renderPace(data) {
  state.paceData = data;
  if (data?.error === 'PACE_NOT_FOUND') {
    elements.paceCard.innerHTML = '<p>No se encontro una fila de cadencia de ventas para el local y la categoria seleccionados.</p>';
    elements.paceValue.textContent = 'Sin datos';
    renderStages();
    return;
  }

  elements.paceCard.innerHTML = `
    <div class="pace-summary">
      <div class="pace-summary__headline">
        <strong>${formatValue(data.pctPaceUnits)}%</strong>
        <span>${formatValue(data.paceId)}</span>
      </div>
      <div class="metric-grid metric-grid--pace">
        <div class="stat-card">
          <span>Hora</span>
          <strong>${formatValue(data.paceHour)}</strong>
        </div>
        <div class="stat-card">
          <span>Unidades vendidas</span>
          <strong>${formatValue(data.unitsSold)}</strong>
        </div>
        <div class="stat-card">
          <span>Unidades presupuestadas</span>
          <strong>${formatValue(data.unitsBudget)}</strong>
        </div>
        <div class="stat-card">
          <span>Variacion en unidades</span>
          <strong>${formatValue(data.varianceUnits)}</strong>
        </div>
      </div>
    </div>
  `;
  elements.paceValue.textContent = `${formatValue(data.pctPaceUnits)}%`;
  renderStages();
}

function renderRecommendations(items) {
  state.pendingRecommendations = Array.isArray(items) ? items : [];
  elements.recommendationsList.innerHTML = '';

  if (!items.length) {
    elements.recommendationsList.classList.add('state-card--empty');
    elements.recommendationsList.innerHTML = '<p>No hay recomendaciones pendientes por ahora.</p>';
    elements.pendingCount.textContent = '0';
    return;
  }

  elements.recommendationsList.classList.remove('state-card--empty');
  elements.pendingCount.textContent = String(items.length);

  for (const item of items) {
    const node = elements.recommendationTemplate.content.cloneNode(true);
    node.querySelector('.rec-title').textContent = item.ActionDescription || item.ActionCode || 'Recomendacion';
    node.querySelector('.rec-subtitle').textContent = `${item.StoreCode} · ${item.CategoryCode} · ${item.RelatedPaceId || 'sin ID de pace'}`;
    node.querySelector('.rec-status').textContent = translateUiStatus(item.Status || 'PENDING');
    node.querySelector('.rec-rule').textContent = item.RuleFired || '--';
    node.querySelector('.rec-priority').textContent = formatValue(item.RulePriority);
    node.querySelector('.rec-severity').textContent = formatValue(item.RuleSeverity);
    node.querySelector('.rec-window').textContent = `${formatValue(item.RuleWindowType)} · ${formatValue(item.RuleThreshold)}`;
    node.querySelector('.rec-message').textContent = item.BusinessMessage || item.Notes || '';
    node.querySelector('.rec-observed').textContent = formatValue(item.RuleObservedValue);
    node.querySelector('.rec-execution').textContent = formatValue(item.ExecutionState);
    node.querySelector('.rec-triggered').textContent = formatValue(item.TriggeredAt);

    node.querySelector('.select-rec-btn').addEventListener('click', () => {
      elements.recommendationId.value = item.RecommendationId;
      elements.feedbackResult.textContent = `Recomendacion cargada ${item.RecommendationId}`;
      elements.feedbackResult.classList.add('flash');
      window.setTimeout(() => elements.feedbackResult.classList.remove('flash'), 1200);
    });

    elements.recommendationsList.appendChild(node);
  }

  renderStages();
}

function renderDashboard(data) {
  elements.dashboardList.innerHTML = '';
  const items = Array.isArray(data.categories) ? data.categories : [];
  state.dashboardRows = items;
  elements.dashboardCount.textContent = String(items.length);

  if (!items.length) {
    elements.dashboardList.classList.add('state-card--empty');
    elements.dashboardList.innerHTML = '<p>No hay filas de panel disponibles para el local seleccionado.</p>';
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
        <span class="pill">${translateUiStatus(row.Status || row.ExecutionState || 'PACE')}</span>
      </div>
      <div class="rec-grid">
        <div><dt>Unidades vendidas</dt><dd>${formatValue(row.UnitsSold)}</dd></div>
        <div><dt>Variacion</dt><dd>${formatValue(row.VarianceUnits)}</dd></div>
        <div><dt>Unidades presupuestadas</dt><dd>${formatValue(row.UnitsBudget)}</dd></div>
        <div><dt>Ultima actualizacion</dt><dd>${formatValue(row.LastUpdated)}</dd></div>
      </div>
      <p class="rec-message">${row.RuleSeverity || 'PACE'} · ${row.BusinessMessage || 'Fila de resumen operativo'}</p>
    `;
    elements.dashboardList.appendChild(item);
  }

  renderStages();
}

async function loadHealth() {
  try {
    setLoading(elements.healthStatus, true);
    const data = await requestJson('/health');
    state.healthStatus = translateUiStatus(data.status || 'ok');
    elements.healthStatus.textContent = state.healthStatus;
  } catch (error) {
    state.healthStatus = 'error';
    elements.healthStatus.textContent = 'error';
    elements.feedbackResult.textContent = `Error en la verificacion de salud: ${error.message}`;
  } finally {
    setLoading(elements.healthStatus, false);
    renderStages();
  }
}

async function loadPace() {
  readConfig();
  try {
    setLoading(elements.paceCard, true);
    elements.paceCard.innerHTML = '<p>Cargando cadencia de ventas...</p>';
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
    elements.recommendationsList.innerHTML = '<p>Cargando recomendaciones pendientes...</p>';
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
    elements.dashboardList.innerHTML = '<p>Cargando panel...</p>';
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
    elements.posResult.textContent = 'Completa todos los campos del POS antes de enviar.';
    return;
  }

  try {
    setLoading(elements.posResult, true);
    elements.posResult.textContent = 'Enviando POS de prueba...';
    const response = await requestJson('/pos/ingest', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    renderPosResult(response);
    setActiveTheme('operations');
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
    elements.feedbackResult.textContent = 'Primero selecciona una recomendacion.';
    return;
  }

  try {
    const response = await requestJson(`/recommendations/${encodeURIComponent(recommendationId)}/feedback/${encodeURIComponent(elements.feedbackStatus.value)}/${encodeURIComponent(elements.acceptedBy.value.trim() || 'store.manager')}/${encodeURIComponent(elements.notes.value.trim() || '-')}`, {
      method: 'POST',
    });

    state.lastFeedbackMessage = `Feedback guardado para ${recommendationId} (${translateUiStatus(response?.after?.Status || elements.feedbackStatus.value)}).`;
    elements.feedbackResult.textContent = state.lastFeedbackMessage;
    elements.feedbackResult.classList.add('flash');
    window.setTimeout(() => elements.feedbackResult.classList.remove('flash'), 1200);
    await loadPendingRecommendations();
    renderStages();
  } catch (error) {
    state.lastFeedbackMessage = `Error al enviar feedback: ${error.message}`;
    elements.feedbackResult.textContent = `Error al enviar feedback: ${error.message}`;
    renderStages();
  }
}

function clearFeedback(preserveMessage = false) {
  elements.recommendationId.value = '';
  elements.acceptedBy.value = '';
  elements.notes.value = '';
  elements.feedbackStatus.value = 'ACCEPTED';
  if (!preserveMessage) {
    state.lastFeedbackMessage = 'Formulario de feedback limpiado.';
    elements.feedbackResult.textContent = state.lastFeedbackMessage;
  }
  renderStages();
}

function wireEvents() {
  elements.apiBaseUrl.addEventListener('change', readConfig);
  elements.storeCode.addEventListener('change', () => { readConfig(); void loadPosBudgetContext(); });
  elements.categoryCode.addEventListener('change', () => { readConfig(); void loadPosBudgetContext(); });
  elements.refreshAllBtn.addEventListener('click', refreshAll);
  elements.themeOverviewBtn.addEventListener('click', () => setActiveTheme('overview'));
  elements.themeConnectionBtn.addEventListener('click', () => setActiveTheme('connection'));
  elements.themeStagesBtn.addEventListener('click', () => setActiveTheme('stages'));
  elements.themeOpsBtn.addEventListener('click', () => setActiveTheme('operations'));
  elements.themePosBtn.addEventListener('click', () => setActiveTheme('pos'));
  elements.themeBudgetBtn.addEventListener('click', () => setActiveTheme('budget'));
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
  renderStages();
}

async function boot() {
  if (elements.apiBaseUrl.value.trim() === '/api' && (window.location.pathname.startsWith('/csp/') || window.location.pathname !== '/')) {
    elements.apiBaseUrl.value = getDefaultApiBaseUrl();
  }
  resetPosSample();
  clearFeedback(true);
  readConfig();
  wireEvents();
  setActiveTheme('overview');
  await loadPosBudgetContext();
  syncBudgetFilterDefaults();
  await refreshAll();
}

void boot();
