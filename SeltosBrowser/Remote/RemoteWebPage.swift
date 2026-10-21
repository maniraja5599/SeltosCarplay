import Foundation

/// Generates the embedded responsive HTML5/CSS3/JavaScript touch remote for Android and web browsers
public struct RemoteWebPage {

    public static func html(pin: String, currentSeek: Int) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>Kia Seltos Remote</title>
            <style>
                :root {
                    --bg-dark: #0a0c10;
                    --card-bg: rgba(22, 27, 36, 0.85);
                    --accent-cyan: #00b4d8;
                    --accent-glow: #00f0ff;
                    --accent-green: #00e676;
                    --text-primary: #ffffff;
                    --text-secondary: #90a4ae;
                    --border-glow: rgba(0, 180, 216, 0.25);
                }
                * {
                    box-sizing: border-box;
                    margin: 0;
                    padding: 0;
                    -webkit-tap-highlight-color: transparent;
                }
                body {
                    background-color: var(--bg-dark);
                    background-image: radial-gradient(circle at 50% 0%, rgba(0, 180, 216, 0.15) 0%, transparent 60%);
                    color: var(--text-primary);
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    padding: 16px;
                    max-width: 480px;
                    margin: 0 auto;
                    min-height: 100vh;
                    display: flex;
                    flex-direction: column;
                    gap: 16px;
                }
                .header {
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    padding: 8px 4px;
                }
                .brand {
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }
                .badge {
                    width: 36px;
                    height: 36px;
                    border-radius: 10px;
                    background: linear-gradient(135deg, #0077b6, #00b4d8);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-weight: 800;
                    font-size: 14px;
                    box-shadow: 0 0 12px rgba(0, 180, 216, 0.5);
                }
                .title-box h1 {
                    font-size: 17px;
                    font-weight: 700;
                    letter-spacing: 0.5px;
                }
                .title-box p {
                    font-size: 11px;
                    color: var(--text-secondary);
                }
                .pin-badge {
                    background: rgba(0, 230, 118, 0.12);
                    border: 1px solid rgba(0, 230, 118, 0.3);
                    color: var(--accent-green);
                    padding: 4px 10px;
                    border-radius: 20px;
                    font-size: 12px;
                    font-weight: 700;
                    letter-spacing: 1px;
                }
                .card {
                    background: var(--card-bg);
                    border: 1px solid var(--border-glow);
                    border-radius: 16px;
                    padding: 14px;
                    backdrop-filter: blur(16px);
                    -webkit-backdrop-filter: blur(16px);
                    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
                }
                .search-box {
                    display: flex;
                    gap: 8px;
                }
                input[type="text"] {
                    flex: 1;
                    background: rgba(10, 12, 16, 0.8);
                    border: 1px solid rgba(255, 255, 255, 0.12);
                    border-radius: 10px;
                    padding: 12px 14px;
                    color: #fff;
                    font-size: 14px;
                    outline: none;
                }
                input[type="text"]:focus {
                    border-color: var(--accent-cyan);
                    box-shadow: 0 0 8px rgba(0, 180, 216, 0.3);
                }
                .btn-primary {
                    background: linear-gradient(135deg, #0077b6, #00b4d8);
                    border: none;
                    border-radius: 10px;
                    color: #fff;
                    font-size: 14px;
                    font-weight: 600;
                    padding: 0 16px;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    gap: 6px;
                }
                .btn-primary:active {
                    transform: scale(0.96);
                }
                /* Seek interval selector */
                .section-label {
                    font-size: 11px;
                    text-transform: uppercase;
                    letter-spacing: 0.8px;
                    color: var(--text-secondary);
                    margin-bottom: 8px;
                }
                .seek-selector {
                    display: flex;
                    gap: 8px;
                }
                .seek-pill {
                    flex: 1;
                    padding: 8px 0;
                    border-radius: 8px;
                    border: 1px solid rgba(255, 255, 255, 0.1);
                    background: rgba(255, 255, 255, 0.04);
                    color: var(--text-secondary);
                    font-size: 12px;
                    font-weight: 600;
                    cursor: pointer;
                    text-align: center;
                    transition: all 0.2s;
                }
                .seek-pill.active {
                    background: var(--accent-cyan);
                    color: #000;
                    border-color: var(--accent-cyan);
                    box-shadow: 0 0 10px rgba(0, 180, 216, 0.4);
                }
                /* Media control buttons */
                .playback-controls {
                    display: flex;
                    align-items: center;
                    justify-content: space-around;
                    gap: 12px;
                    margin: 8px 0;
                }
                .btn-control {
                    background: rgba(255, 255, 255, 0.06);
                    border: 1px solid rgba(255, 255, 255, 0.12);
                    border-radius: 14px;
                    color: #fff;
                    font-size: 14px;
                    font-weight: 700;
                    padding: 14px 20px;
                    cursor: pointer;
                    flex: 1;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 4px;
                    transition: transform 0.1s, background 0.2s;
                }
                .btn-control:active {
                    transform: scale(0.93);
                    background: rgba(0, 180, 216, 0.2);
                }
                .btn-play {
                    flex: 1.3;
                    background: linear-gradient(135deg, #00b4d8, #0077b6);
                    border-color: var(--accent-glow);
                    font-size: 20px;
                    padding: 16px 20px;
                    box-shadow: 0 0 15px rgba(0, 180, 216, 0.4);
                }
                /* Navigation bar */
                .nav-row {
                    display: flex;
                    gap: 8px;
                }
                .btn-nav {
                    flex: 1;
                    background: rgba(255, 255, 255, 0.05);
                    border: 1px solid rgba(255, 255, 255, 0.08);
                    border-radius: 10px;
                    padding: 10px 4px;
                    font-size: 12px;
                    font-weight: 600;
                    color: var(--text-primary);
                    cursor: pointer;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 4px;
                }
                .btn-nav:active {
                    background: rgba(0, 180, 216, 0.25);
                }
                /* App Shortcuts Grid */
                .apps-grid {
                    display: grid;
                    grid-template-columns: repeat(4, 1fr);
                    gap: 10px;
                }
                .app-btn {
                    background: rgba(255, 255, 255, 0.04);
                    border: 1px solid rgba(255, 255, 255, 0.07);
                    border-radius: 12px;
                    padding: 12px 4px;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 6px;
                    cursor: pointer;
                    color: #fff;
                    font-size: 11px;
                    font-weight: 500;
                }
                .app-btn:active {
                    transform: scale(0.92);
                    border-color: var(--accent-cyan);
                }
                .app-btn .icon {
                    font-size: 22px;
                }
                /* Status footer */
                .footer {
                    margin-top: auto;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    font-size: 11px;
                    color: var(--text-secondary);
                    padding: 8px 4px;
                }
                .status-dot {
                    display: inline-block;
                    width: 7px;
                    height: 7px;
                    border-radius: 50%;
                    background: var(--accent-green);
                    margin-right: 6px;
                    box-shadow: 0 0 6px var(--accent-green);
                }
            </style>
        </head>
        <body>
            <!-- Header -->
            <div class="header">
                <div class="brand">
                    <div class="badge">KIA</div>
                    <div class="title-box">
                        <h1>Seltos Remote</h1>
                        <p>Infotainment Touch Control</p>
                    </div>
                </div>
                <div class="pin-badge" id="pinDisplay">PIN: \(pin)</div>
            </div>

            <!-- Search & Cast -->
            <div class="card">
                <div class="section-label">Play or Search on Car Screen</div>
                <div class="search-box">
                    <input type="text" id="urlInput" placeholder="Search song or paste URL..." onkeydown="if(event.key==='Enter') sendLoad()">
                    <button class="btn-primary" onclick="sendLoad()">Send</button>
                </div>
            </div>

            <!-- Media Scrubbing & Playback -->
            <div class="card">
                <div class="section-label">Scrub Interval</div>
                <div class="seek-selector">
                    <div class="seek-pill \(currentSeek == 5 ? "active" : "")" id="pill5" onclick="setSeek(5)">5s</div>
                    <div class="seek-pill \(currentSeek == 10 ? "active" : "")" id="pill10" onclick="setSeek(10)">10s</div>
                    <div class="seek-pill \(currentSeek == 15 ? "active" : "")" id="pill15" onclick="setSeek(15)">15s</div>
                    <div class="seek-pill \(currentSeek == 60 ? "active" : "")" id="pill60" onclick="setSeek(60)">1m</div>
                </div>

                <div class="playback-controls" style="margin-top: 14px;">
                    <button class="btn-control" onclick="sendSeek(-currentSeekStep)">
                        <span style="font-size: 18px;">⏪</span>
                        <span id="rewindLabel">-\(currentSeek)s</span>
                    </button>
                    <button class="btn-control btn-play" onclick="sendCommand('toggle')">
                        <span id="playIcon">⏯️</span>
                    </button>
                    <button class="btn-control" onclick="sendSeek(currentSeekStep)">
                        <span style="font-size: 18px;">⏩</span>
                        <span id="forwardLabel">+\(currentSeek)s</span>
                    </button>
                </div>
            </div>

            <!-- Browser Navigation -->
            <div class="card">
                <div class="section-label">Car Display Controls</div>
                <div class="nav-row">
                    <button class="btn-nav" onclick="sendCommand('home')">
                        <span style="font-size: 16px;">🏠</span>
                        <span>Home</span>
                    </button>
                    <button class="btn-nav" onclick="sendCommand('back')">
                        <span style="font-size: 16px;">◀</span>
                        <span>Back</span>
                    </button>
                    <button class="btn-nav" onclick="sendCommand('forward')">
                        <span style="font-size: 16px;">▶</span>
                        <span>Forward</span>
                    </button>
                    <button class="btn-nav" onclick="sendCommand('desktop')">
                        <span style="font-size: 16px;">🖥️</span>
                        <span>Desktop</span>
                    </button>
                    <button class="btn-nav" onclick="sendCommand('fullscreen')">
                        <span style="font-size: 16px;">⛶</span>
                        <span>Fullscr</span>
                    </button>
                </div>
            </div>

            <!-- Quick Streaming Shortcuts -->
            <div class="card">
                <div class="section-label">Quick Launch Shortcuts</div>
                <div class="apps-grid">
                    <div class="app-btn" onclick="sendDirectURL('https://m.youtube.com')">
                        <span class="icon">▶️</span>
                        <span>YouTube</span>
                    </div>
                    <div class="app-btn" onclick="sendDirectURL('https://www.netflix.com')">
                        <span class="icon">🎬</span>
                        <span>Netflix</span>
                    </div>
                    <div class="app-btn" onclick="sendDirectURL('https://www.hotstar.com')">
                        <span class="icon">⭐</span>
                        <span>Hotstar</span>
                    </div>
                    <div class="app-btn" onclick="sendDirectURL('https://www.primevideo.com')">
                        <span class="icon">📺</span>
                        <span>Prime</span>
                    </div>
                    <div class="app-btn" onclick="sendDirectURL('https://www.jiocinema.com')">
                        <span class="icon">🎥</span>
                        <span>JioCinema</span>
                    </div>
                    <div class="app-btn" onclick="sendDirectURL('https://open.spotify.com')">
                        <span class="icon">🎵</span>
                        <span>Spotify</span>
                    </div>
                    <div class="app-btn" onclick="sendDirectURL('https://m.cricbuzz.com')">
                        <span class="icon">🏏</span>
                        <span>Cricbuzz</span>
                    </div>
                    <div class="app-btn" onclick="sendDirectURL('https://maps.google.com')">
                        <span class="icon">🗺️</span>
                        <span>Maps</span>
                    </div>
                </div>
            </div>

            <!-- Footer -->
            <div class="footer">
                <div><span class="status-dot"></span><span id="connStatus">Connected to Seltos</span></div>
                <div>PIN: <span id="pinText">\(pin)</span></div>
            </div>

            <script>
                let currentSeekStep = \(currentSeek);
                const pin = '\(pin)';
                const isLocal = window.location.hostname !== '' && window.location.hostname !== 'localhost' && window.location.protocol.startsWith('http');

                function setSeek(seconds) {
                    currentSeekStep = seconds;
                    document.querySelectorAll('.seek-pill').forEach(p => p.classList.remove('active'));
                    const target = document.getElementById('pill' + seconds);
                    if (target) target.classList.add('active');
                    const label = seconds === 60 ? '1m' : seconds + 's';
                    document.getElementById('rewindLabel').innerText = '-' + label;
                    document.getElementById('forwardLabel').innerText = '+' + label;
                    sendCommand('seekInterval', { seconds: seconds });
                }

                function sendCommand(action, data = {}) {
                    const payload = { action: action, pin: pin, ...data };
                    
                    // 1. Try local server endpoint if loaded over local IP
                    fetch('/api/' + action, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(payload)
                    }).catch(() => {
                        // 2. Fallback to Cloud Relay (works on 4G/5G cellular data without hotspot)
                        fetch('https://ntfy.sh/kia_seltos_' + pin, {
                            method: 'POST',
                            headers: { 'Title': 'RemoteCommand' },
                            body: JSON.stringify(payload)
                        }).catch(e => console.error(e));
                    });
                }

                function sendSeek(delta) {
                    sendCommand('seek', { delta: delta });
                }

                function sendLoad() {
                    const val = document.getElementById('urlInput').value.trim();
                    if (!val) return;
                    sendCommand('load', { query: val });
                    document.getElementById('urlInput').value = '';
                }

                function sendDirectURL(url) {
                    sendCommand('load', { query: url });
                }
            </script>
        </body>
        </html>
        """
    }
}
