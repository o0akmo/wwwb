// ==UserScript==
// @name         Partner IP Lookup
// @namespace    http://tampermonkey.net/
// @version      2.0
// @description  Partner IP geolocation panel for uhmegle/umingle
// @match        *://uhmegle.com/*
// @match        *://umingle.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(() => {
    'use strict';

    // --- Styles ---
    function injectStyles() {
        const style = document.createElement('style');
        style.textContent = `
            #pip-panel {
                position: fixed;
                bottom: 20px;
                right: 20px;
                width: 300px;
                background: #0f111a;
                border: 0.5px solid rgba(255,255,255,0.08);
                border-radius: 16px;
                overflow: hidden;
                font-family: 'Inter', system-ui, sans-serif;
                font-size: 13px;
                color: #f0f2f7;
                z-index: 999999;
                transition: opacity 0.3s ease, transform 0.3s ease;
            }
            #pip-panel.pip-hidden {
                opacity: 0;
                pointer-events: none;
                transform: translateY(8px);
            }
            .pip-header {
                padding: 11px 14px;
                display: flex;
                align-items: center;
                justify-content: space-between;
                background: #13151f;
                border-bottom: 0.5px solid rgba(255,255,255,0.06);
                cursor: move;
            }
            .pip-header-left { display: flex; align-items: center; gap: 6px; }
            .pip-dot { width: 7px; height: 7px; border-radius: 50%; }
            .pip-dot-r { background: #ff5f57; }
            .pip-dot-y { background: #febc2e; }
            .pip-dot-g { background: #28c840; }
            .pip-title {
                font-size: 11px;
                font-weight: 600;
                letter-spacing: 0.08em;
                color: #64748b;
                text-transform: uppercase;
                margin-left: 6px;
            }
            .pip-badge {
                font-size: 10px;
                font-weight: 600;
                padding: 3px 8px;
                border-radius: 20px;
                letter-spacing: 0.04em;
                text-transform: uppercase;
            }
            .pip-badge-live {
                background: rgba(0,230,118,0.12);
                color: #00e676;
                border: 0.5px solid rgba(0,230,118,0.25);
            }
            .pip-badge-wait {
                background: rgba(100,116,139,0.1);
                color: #475569;
                border: 0.5px solid rgba(100,116,139,0.15);
            }
            .pip-ip-block {
                padding: 14px 16px;
                border-bottom: 0.5px solid rgba(255,255,255,0.06);
            }
            .pip-label {
                font-size: 10px;
                color: #475569;
                text-transform: uppercase;
                letter-spacing: 0.08em;
                margin-bottom: 5px;
            }
            .pip-ip-value {
                font-size: 20px;
                font-weight: 600;
                font-family: 'SF Mono', 'JetBrains Mono', monospace;
                color: #e2e8f0;
                letter-spacing: 0.03em;
            }
            .pip-type {
                display: inline-flex;
                align-items: center;
                gap: 5px;
                margin-top: 5px;
                font-size: 11px;
            }
            .pip-type-dot { width: 5px; height: 5px; border-radius: 50%; }
            .pip-p2p { color: #ff5252; }
            .pip-p2p .pip-type-dot { background: #ff5252; }
            .pip-relay { color: #00e676; }
            .pip-relay .pip-type-dot { background: #00e676; }
            .pip-geo-grid {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 12px;
                padding: 14px 16px;
                border-bottom: 0.5px solid rgba(255,255,255,0.06);
            }
            .pip-geo-label {
                font-size: 10px;
                color: #475569;
                text-transform: uppercase;
                letter-spacing: 0.08em;
                margin-bottom: 3px;
            }
            .pip-geo-value {
                font-size: 13px;
                color: #cbd5e1;
                font-weight: 500;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
            }
            .pip-geo-value.pip-accent { color: #7dd3fc; }
            .pip-isp-block {
                padding: 11px 16px;
                border-bottom: 0.5px solid rgba(255,255,255,0.06);
            }
            .pip-isp-row {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 5px;
            }
            .pip-isp-row:last-child { margin-bottom: 0; }
            .pip-isp-key { font-size: 11px; color: #475569; }
            .pip-isp-val {
                font-size: 11px;
                color: #94a3b8;
                text-align: right;
                max-width: 170px;
                overflow: hidden;
                text-overflow: ellipsis;
                white-space: nowrap;
            }
            .pip-coords-row {
                padding: 10px 16px;
                display: flex;
                align-items: center;
                justify-content: space-between;
            }
            .pip-coords-val {
                font-size: 11px;
                font-family: monospace;
                color: #475569;
            }
            .pip-map-btn {
                font-size: 10px;
                font-weight: 600;
                padding: 4px 10px;
                border-radius: 6px;
                border: 0.5px solid rgba(125,211,252,0.2);
                background: rgba(125,211,252,0.06);
                color: #7dd3fc;
                cursor: pointer;
                letter-spacing: 0.04em;
                text-transform: uppercase;
                text-decoration: none;
            }
            .pip-map-btn:hover { background: rgba(125,211,252,0.12); }
            .pip-waiting {
                padding: 32px 16px;
                text-align: center;
                color: #1e293b;
                font-size: 12px;
            }
            .pip-toggle {
                position: fixed;
                bottom: 20px;
                right: 20px;
                width: 38px;
                height: 38px;
                border-radius: 10px;
                background: #13151f;
                border: 0.5px solid rgba(255,255,255,0.08);
                display: flex;
                align-items: center;
                justify-content: center;
                cursor: pointer;
                z-index: 999998;
                display: none;
            }
            .pip-toggle svg { width: 16px; height: 16px; stroke: #64748b; }
            .pip-toggle:hover { background: #1e2130; }
            .pip-loading {
                padding: 18px 16px;
                display: flex;
                align-items: center;
                gap: 10px;
                color: #475569;
                font-size: 12px;
                border-bottom: 0.5px solid rgba(255,255,255,0.06);
            }
            @keyframes pip-spin {
                to { transform: rotate(360deg); }
            }
            .pip-spinner {
                width: 14px;
                height: 14px;
                border: 1.5px solid rgba(125,211,252,0.15);
                border-top-color: #7dd3fc;
                border-radius: 50%;
                animation: pip-spin 0.7s linear infinite;
                flex-shrink: 0;
            }
        `;
        document.head.appendChild(style);
    }

    // --- Build panel DOM ---
    function buildPanel() {
        const panel = document.createElement('div');
        panel.id = 'pip-panel';
        panel.innerHTML = `
            <div class="pip-header" id="pip-drag-handle">
                <div class="pip-header-left">
                    <div class="pip-dot pip-dot-r"></div>
                    <div class="pip-dot pip-dot-y"></div>
                    <div class="pip-dot pip-dot-g"></div>
                    <span class="pip-title">Partner Info</span>
                </div>
                <span class="pip-badge pip-badge-wait" id="pip-badge">Waiting</span>
            </div>
            <div id="pip-body">
                <div class="pip-waiting">
                    <svg viewBox="0 0 24 24" fill="none" stroke="#1e293b" stroke-width="1.5"
                         style="width:28px;height:28px;display:block;margin:0 auto 10px">
                        <circle cx="12" cy="12" r="10"/>
                        <path d="M12 8v4l3 3"/>
                    </svg>
                    Waiting for connection...
                </div>
            </div>
        `;
        document.body.appendChild(panel);
        makeDraggable(panel, panel.querySelector('#pip-drag-handle'));
        return panel;
    }

    function makeDraggable(el, handle) {
        let ox = 0, oy = 0, cx = 0, cy = 0;
        handle.onmousedown = (e) => {
            e.preventDefault();
            cx = e.clientX; cy = e.clientY;
            document.onmousemove = (e) => {
                ox = cx - e.clientX; oy = cy - e.clientY;
                cx = e.clientX; cy = e.clientY;
                el.style.top  = (el.offsetTop  - oy) + 'px';
                el.style.left = (el.offsetLeft - ox) + 'px';
                el.style.bottom = 'auto'; el.style.right = 'auto';
            };
            document.onmouseup = () => {
                document.onmousemove = null;
                document.onmouseup = null;
            };
        };
    }

    function setWaiting() {
        const badge = document.getElementById('pip-badge');
        const body  = document.getElementById('pip-body');
        if (!badge || !body) return;
        badge.className = 'pip-badge pip-badge-wait';
        badge.textContent = 'Waiting';
        body.innerHTML = `
            <div class="pip-waiting">
                <svg viewBox="0 0 24 24" fill="none" stroke="#1e293b" stroke-width="1.5"
                     style="width:28px;height:28px;display:block;margin:0 auto 10px">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M12 8v4l3 3"/>
                </svg>
                Waiting for connection...
            </div>`;
    }

    function setLoading(ip) {
        const badge = document.getElementById('pip-badge');
        const body  = document.getElementById('pip-body');
        if (!badge || !body) return;
        badge.className = 'pip-badge pip-badge-live';
        badge.textContent = 'Live';
        body.innerHTML = `
            <div class="pip-ip-block">
                <div class="pip-label">IP Address</div>
                <div class="pip-ip-value">${ip}</div>
            </div>
            <div class="pip-loading">
                <div class="pip-spinner"></div>
                Looking up location...
            </div>`;
    }

    function setConnected(info, geo) {
        const badge = document.getElementById('pip-badge');
        const body  = document.getElementById('pip-body');
        if (!badge || !body) return;
        badge.className = 'pip-badge pip-badge-live';
        badge.textContent = 'Live';

        const isRelay  = info.type === 'relay';
        const typeHtml = isRelay
            ? `<div class="pip-type pip-relay"><div class="pip-type-dot"></div>Relay — IP protected</div>`
            : `<div class="pip-type pip-p2p"><div class="pip-type-dot"></div>P2P — Direct connection</div>`;

        const geoHtml = geo ? `
            <div class="pip-geo-grid">
                <div>
                    <div class="pip-geo-label">Country</div>
                    <div class="pip-geo-value">${geo.country || '—'}</div>
                </div>
                <div>
                    <div class="pip-geo-label">Region</div>
                    <div class="pip-geo-value">${geo.region || '—'}</div>
                </div>
                <div>
                    <div class="pip-geo-label">City</div>
                    <div class="pip-geo-value pip-accent">${geo.city || '—'}</div>
                </div>
                <div>
                    <div class="pip-geo-label">Timezone</div>
                    <div class="pip-geo-value">${geo.timezone || '—'}</div>
                </div>
            </div>
            <div class="pip-isp-block">
                <div class="pip-isp-row">
                    <span class="pip-isp-key">ISP</span>
                    <span class="pip-isp-val">${geo.isp || '—'}</span>
                </div>
                <div class="pip-isp-row">
                    <span class="pip-isp-key">Org</span>
                    <span class="pip-isp-val">${geo.org || '—'}</span>
                </div>
            </div>
            <div class="pip-coords-row">
                <span class="pip-coords-val">${geo.lat?.toFixed(4)}, ${geo.lon?.toFixed(4)}</span>
                <a class="pip-map-btn" href="https://maps.google.com/?q=${geo.lat},${geo.lon}" target="_blank">Maps ↗</a>
            </div>` : `
            <div style="padding:12px 16px;font-size:12px;color:#475569;">
                Geo lookup unavailable.
            </div>`;

        body.innerHTML = `
            <div class="pip-ip-block">
                <div class="pip-label">IP Address</div>
                <div class="pip-ip-value">${isRelay ? '---.---.---.---' : info.ip}</div>
                ${typeHtml}
            </div>
            ${isRelay ? `
            <div class="pip-geo-grid">
                <div><div class="pip-geo-label">Country</div><div class="pip-geo-value" style="color:#1e293b">Hidden</div></div>
                <div><div class="pip-geo-label">City</div><div class="pip-geo-value" style="color:#1e293b">Hidden</div></div>
            </div>
            <div class="pip-isp-block">
                <div class="pip-isp-row">
                    <span class="pip-isp-key">ISP</span>
                    <span class="pip-isp-val" style="color:#334155">Unavailable via relay</span>
                </div>
            </div>` : geoHtml}
        `;
    }

    // --- Core logic ---
    async function getPartnerInfo(pc) {
        const stats = await pc.getStats();
        for (const stat of stats.values()) {
            if (stat.type === 'candidate-pair' && stat.state === 'succeeded' && stat.remoteCandidateId) {
                const remote = stats.get(stat.remoteCandidateId);
                if (remote?.ip) return { ip: remote.ip, type: remote.candidateType };
            }
        }
        return null;
    }
async function lookupIP(ip) {
    try {
        const res = await fetch(`https://free.freeipapi.com/api/json/${ip}`);
        const data = await res.json();

        // freeipapi returns an error object if lookup fails
        if (!data || data.ipVersion === undefined) return null;

        return {
            ip: data.ipAddress || ip,
            country: data.countryName || 'Unknown',
            region: data.regionName || 'Unknown',
            city: data.cityName || 'Unknown',
            timezone: data.timeZone || 'Unknown',
            org: data.asnOrganization || 'Unknown',
            isp: data.asnOrganization || 'Unknown',
            lat: data.latitude,
            lon: data.longitude,
        };
    } catch (err) {
        console.error('IP lookup failed:', err);
        return null;
    }
}

    function hookRTC() {
        if (window.RTCPeerConnection?.isHookedByPIP) return;
        const Original = window.RTCPeerConnection;

        window.RTCPeerConnection = function (...args) {
            const pc = new Original(...args);

            pc.addEventListener('connectionstatechange', async () => {
                if (pc.connectionState === 'connected') {
                    const info = await getPartnerInfo(pc);
                    if (!info) return;
                    setLoading(info.ip);
                    const geo = (info.type !== 'relay') ? await lookupIP(info.ip) : null;
                    setConnected(info, geo);
                }
                if (pc.connectionState === 'disconnected' || pc.connectionState === 'closed') {
                    setWaiting();
                }
            });

            return pc;
        };

        window.RTCPeerConnection.prototype = Original.prototype;
        window.RTCPeerConnection.isHookedByPIP = true;
    }

    // --- Hotkey toggle (Ctrl+Alt+I) ---
    function setupHotkey(panel) {
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey && e.altKey && e.key.toLowerCase() === 'i') {
                e.preventDefault();
                panel.classList.toggle('pip-hidden');
            }
        });
    }

    // --- Init ---
    function init() {
        injectStyles();
        const panel = buildPanel();
        hookRTC();
        setupHotkey(panel);
    }

    if (document.readyState === 'loading') {
        window.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
