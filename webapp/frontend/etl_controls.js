// ETL Controls - Reload and Status functionality

// ETL Reload functionality
document.getElementById('reloadETL').addEventListener('click', async () => {
    if (!confirm('This will reload all CSV data and refresh materialized views. This may take several minutes. Continue?')) {
        return;
    }

    const button = document.getElementById('reloadETL');
    const originalText = button.textContent;
    button.disabled = true;
    button.textContent = '⏳ Reloading...';

    try {
        const response = await fetch('/api/etl/reload', {
            method: 'POST'
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail);
        }

        const result = await response.json();
        alert(`ETL Reload Successful!\n\n${result.message}\nTimestamp: ${result.timestamp}`);

        // Refresh health status
        checkHealth();
    } catch (error) {
        alert(`ETL Reload Failed:\n${error.message}`);
    } finally {
        button.disabled = false;
        button.textContent = originalText;
    }
});

// ETL Status modal
const statusModal = document.getElementById('statusModal');
const statusButton = document.getElementById('showStatus');
const closeModal = document.getElementsByClassName('close')[0];

statusButton.addEventListener('click', async () => {
    statusModal.style.display = 'block';
    document.getElementById('statusContent').innerHTML = '<div class="status-loading">Loading...</div>';

    try {
        const response = await fetch('/api/etl/status');
        if (!response.ok) {
            throw new Error('Failed to fetch status');
        }

        const status = await response.json();
        displayStatus(status);
    } catch (error) {
        document.getElementById('statusContent').innerHTML = `
            <div class="status-error">
                <p>Error loading status: ${error.message}</p>
            </div>
        `;
    }
});

closeModal.addEventListener('click', () => {
    statusModal.style.display = 'none';
});

window.addEventListener('click', (event) => {
    if (event.target === statusModal) {
        statusModal.style.display = 'none';
    }
});

function displayStatus(status) {
    const rowCountsHTML = status.row_counts
        .map(row => `<tr><td>${row.table_name}</td><td>${row.row_count.toLocaleString()}</td></tr>`)
        .join('');

    const periodsHTML = status.periods.length > 0
        ? status.periods
            .map(p => `<tr><td>${p.Period}</td><td>${p['Source Count']}</td><td>${p.Sources.join(', ')}</td></tr>`)
            .join('')
        : '<tr><td colspan="3">No periods loaded</td></tr>';

    const lastRefresh = status.last_refresh
        ? `${status.last_refresh.matviewname}: ${new Date(status.last_refresh.last_refresh).toLocaleString()}`
        : 'Never refreshed';

    document.getElementById('statusContent').innerHTML = `
        <div class="status-section">
            <h3>Row Counts</h3>
            <table class="status-table">
                <thead>
                    <tr><th>Table</th><th>Rows</th></tr>
                </thead>
                <tbody>${rowCountsHTML}</tbody>
            </table>
        </div>

        <div class="status-section">
            <h3>Available Periods</h3>
            <table class="status-table">
                <thead>
                    <tr><th>Period</th><th>Sources</th><th>Tables</th></tr>
                </thead>
                <tbody>${periodsHTML}</tbody>
            </table>
        </div>

        <div class="status-section">
            <h3>Last Refresh</h3>
            <p>${lastRefresh}</p>
        </div>

        <div class="status-section">
            <h3>System Time</h3>
            <p>${new Date(status.timestamp).toLocaleString()}</p>
        </div>
    `;
}
