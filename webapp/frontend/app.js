// State management
let gridApi = null;
let currentData = [];
let currentColumns = [];
let predefinedQueries = [];
let lastExecutedSQL = '';

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    initializeApp();
});

async function initializeApp() {
    // Check health
    await checkHealth();

    // Load predefined queries
    await loadPredefinedQueries();

    // Setup event listeners
    setupEventListeners();

    // Initialize grid
    initializeGrid();
}

async function checkHealth() {
    try {
        const response = await fetch('/api/health');
        const data = await response.json();

        const indicator = document.getElementById('statusIndicator');
        const statusText = document.getElementById('statusText');

        if (data.status === 'healthy') {
            indicator.classList.add('healthy');
            indicator.classList.remove('unhealthy');
            statusText.textContent = `Connected to ${data.database.database}`;
        } else {
            indicator.classList.add('unhealthy');
            indicator.classList.remove('healthy');
            statusText.textContent = 'Database connection failed';
        }
    } catch (error) {
        const indicator = document.getElementById('statusIndicator');
        const statusText = document.getElementById('statusText');
        indicator.classList.add('unhealthy');
        indicator.classList.remove('healthy');
        statusText.textContent = 'API connection failed';
    }
}

async function loadPredefinedQueries() {
    try {
        const response = await fetch('/api/queries/predefined');
        const data = await response.json();
        predefinedQueries = data.queries;

        const select = document.getElementById('querySelect');
        select.innerHTML = '<option value="">-- Select a query --</option>';

        // Group by category
        const categories = {};
        predefinedQueries.forEach(q => {
            const cat = q.category || 'general';
            if (!categories[cat]) categories[cat] = [];
            categories[cat].push(q);
        });

        // Add optgroups
        Object.keys(categories).sort().forEach(cat => {
            const optgroup = document.createElement('optgroup');
            optgroup.label = cat.toUpperCase();
            categories[cat].forEach(q => {
                const option = document.createElement('option');
                option.value = q.id;
                option.textContent = q.name;
                option.title = q.description;
                optgroup.appendChild(option);
            });
            select.appendChild(optgroup);
        });
    } catch (error) {
        console.error('Failed to load predefined queries:', error);
    }
}

function setupEventListeners() {
    // Tab navigation
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const tab = btn.dataset.tab;
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            btn.classList.add('active');
            document.getElementById(`${tab}-tab`).classList.add('active');
        });
    });

    // Query execution
    document.getElementById('runPredefined').addEventListener('click', executePredefinedQuery);
    document.getElementById('runCustom').addEventListener('click', executeCustomQuery);
    document.getElementById('runView').addEventListener('click', executeViewQuery);

    // Results controls
    document.getElementById('applyFilter').addEventListener('click', applyColumnFilter);
    document.getElementById('clearFilters').addEventListener('click', clearFilters);
    document.getElementById('pageSize').addEventListener('change', updatePageSize);

    // Query builder
    document.getElementById('addFilter').addEventListener('click', addFilterAndRerun);
}

function initializeGrid() {
    const gridDiv = document.getElementById('resultsGrid');
    const gridOptions = {
        columnDefs: [],
        rowData: [],
        defaultColDef: {
            sortable: true,
            filter: true,
            resizable: true,
            minWidth: 100
        },
        pagination: true,
        paginationPageSize: 10,
        domLayout: 'normal',
        enableCellTextSelection: true,
        ensureDomOrder: true
    };

    gridApi = agGrid.createGrid(gridDiv, gridOptions);
}

function getCellStyle(params) {
    const value = params.value;
    const colId = params.colDef.field;

    // Check if numeric
    if (typeof value !== 'number') return null;

    // Negative values - red background
    if (value < 0) {
        return { backgroundColor: '#ffebee', color: '#c62828', fontWeight: '500' };
    }

    // Variance columns with non-zero values - yellow background
    if (colId && (colId.toLowerCase().includes('variance') || colId.toLowerCase().includes('outstanding'))) {
        if (Math.abs(value) > 0.02) {
            return { backgroundColor: '#fff9c4', color: '#f57f17' };
        }
    }

    // Default/zero values - gray background
    if (value === 0) {
        return { backgroundColor: '#f5f5f5', color: '#999' };
    }

    return null;
}

async function executePredefinedQuery() {
    const queryId = document.getElementById('querySelect').value;
    if (!queryId) {
        alert('Please select a query');
        return;
    }

    try {
        const pageSize = parseInt(document.getElementById('pageSize').value) || 1000;
        const response = await fetch(`/api/queries/predefined/${queryId}/execute?limit=${pageSize}`);

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail);
        }

        const data = await response.json();
        displayResults(data);

        // Store last executed query info
        const query = predefinedQueries.find(q => q.id === queryId);
        document.getElementById('queryInfo').textContent = `Query: ${query.name}`;

        // Get the SQL for future filters
        const queryResponse = await fetch(`/api/queries/predefined/${queryId}`);
        const queryData = await queryResponse.json();
        lastExecutedSQL = queryData.sql;
    } catch (error) {
        alert(`Query failed: ${error.message}`);
    }
}

async function executeCustomQuery() {
    const sql = document.getElementById('customSQL').value.trim();
    if (!sql) {
        alert('Please enter a SQL query');
        return;
    }

    try {
        const pageSize = parseInt(document.getElementById('pageSize').value) || 1000;
        const response = await fetch('/api/queries/execute', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ sql, limit: pageSize })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail);
        }

        const data = await response.json();
        displayResults(data);

        document.getElementById('queryInfo').textContent = 'Custom Query';
        lastExecutedSQL = sql;
    } catch (error) {
        alert(`Query failed: ${error.message}`);
    }
}

async function executeViewQuery() {
    const viewName = document.getElementById('viewSelect').value;
    const pageSize = parseInt(document.getElementById('pageSize').value) || 1000;

    try {
        const response = await fetch(`/api/views/${viewName}?limit=${pageSize}`);

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail);
        }

        const data = await response.json();
        displayResults(data);

        document.getElementById('queryInfo').textContent = `View: ${viewName}`;
        lastExecutedSQL = `SELECT * FROM mart.v_${viewName}`;
    } catch (error) {
        alert(`Query failed: ${error.message}`);
    }
}

function displayResults(data) {
    currentData = data.rows;
    currentColumns = data.columns;

    // Update row count
    document.getElementById('rowCount').textContent = `${data.row_count} rows`;

    // Create column definitions with conditional formatting
    const columnDefs = currentColumns.map(col => ({
        field: col,
        headerName: col,
        cellStyle: getCellStyle,
        valueFormatter: params => {
            if (params.value === null || params.value === undefined) return '';
            if (typeof params.value === 'number') {
                return params.value.toFixed(2);
            }
            return params.value;
        }
    }));

    // Update grid
    gridApi.setGridOption('columnDefs', columnDefs);
    gridApi.setGridOption('rowData', currentData);

    // Update filter dropdowns
    updateFilterDropdowns();
}

function updateFilterDropdowns() {
    const columnFilter = document.getElementById('columnFilter');
    const builderColumn = document.getElementById('builderColumn');

    columnFilter.innerHTML = '<option value="">-- Select column --</option>';
    builderColumn.innerHTML = '<option value="">-- Select column --</option>';

    currentColumns.forEach(col => {
        const option1 = document.createElement('option');
        option1.value = col;
        option1.textContent = col;
        columnFilter.appendChild(option1);

        const option2 = document.createElement('option');
        option2.value = col;
        option2.textContent = col;
        builderColumn.appendChild(option2);
    });
}

function applyColumnFilter() {
    const column = document.getElementById('columnFilter').value;
    const value = document.getElementById('filterValue').value;

    if (!column || !value) {
        alert('Please select a column and enter a filter value');
        return;
    }

    const filterInstance = gridApi.getFilterInstance(column);
    if (filterInstance) {
        filterInstance.setModel({
            type: 'contains',
            filter: value
        });
        gridApi.onFilterChanged();
    }
}

function clearFilters() {
    gridApi.setFilterModel(null);
    document.getElementById('filterValue').value = '';
}

function updatePageSize() {
    const pageSize = parseInt(document.getElementById('pageSize').value);
    if (pageSize === 1000) {
        gridApi.setGridOption('paginationPageSize', currentData.length);
        gridApi.paginationGoToPage(0);
    } else {
        gridApi.setGridOption('paginationPageSize', pageSize);
    }
}

async function addFilterAndRerun() {
    const column = document.getElementById('builderColumn').value;
    const operator = document.getElementById('builderOperator').value;
    const value = document.getElementById('builderValue').value;

    if (!column || !value) {
        alert('Please select a column and enter a value');
        return;
    }

    if (!lastExecutedSQL) {
        alert('No query has been executed yet');
        return;
    }

    // Build WHERE clause
    let whereClause = '';
    const quotedValue = isNaN(value) ? `'${value}'` : value;

    if (lastExecutedSQL.toUpperCase().includes('WHERE')) {
        whereClause = `AND "${column}" ${operator} ${quotedValue}`;
    } else {
        whereClause = `WHERE "${column}" ${operator} ${quotedValue}`;
    }

    // Remove existing LIMIT and add new one
    let newSQL = lastExecutedSQL.replace(/LIMIT\s+\d+/gi, '');
    newSQL = `${newSQL} ${whereClause}`;

    const pageSize = parseInt(document.getElementById('pageSize').value) || 1000;
    newSQL += ` LIMIT ${pageSize}`;

    // Execute modified query
    try {
        const response = await fetch('/api/queries/execute', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ sql: newSQL, limit: pageSize })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail);
        }

        const data = await response.json();
        displayResults(data);

        document.getElementById('queryInfo').textContent = 'Filtered Query';
        lastExecutedSQL = newSQL;

        // Clear builder inputs
        document.getElementById('builderValue').value = '';
    } catch (error) {
        alert(`Query failed: ${error.message}`);
    }
}
