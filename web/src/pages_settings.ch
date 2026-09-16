// underlayer_web — Settings and profile page renders.
using std::string
using std::string_view

public namespace underlayer_web {

    // Settings page (authenticated user)
    public func render_settings_page() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Settings — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="settings-page">
                <nav class="settings-nav">
                    <a href="#profile" class="tab active" data-tab="profile">Profile</a>
                    <a href="#account" class="tab" data-tab="account">Account</a>
                    <a href="#learning" class="tab" data-tab="learning">Learning</a>
                </nav>
                <div class="settings-content">
                    <section id="profile-section" class="tab-content active">
                        <h2>Profile</h2>
                        <form id="profileForm">
                            <div class="form-group">
                                <label>Display Name</label>
                                <input type="text" id="display_name" maxlength="50" />
                            </div>
                            <div class="form-group">
                                <label>Username</label>
                                <input type="text" id="username" pattern="[a-zA-Z0-9_]{3,20}" />
                                <small>3-20 characters, letters, numbers, underscore</small>
                            </div>
                            <div class="form-group">
                                <label>Bio</label>
                                <textarea id="bio" maxlength="500" rows="3"></textarea>
                            </div>
                            <div class="form-group">
                                <label>Location</label>
                                <input type="text" id="location" maxlength="100" />
                            </div>
                            <div class="form-group">
                                <label>Website</label>
                                <input type="url" id="website" />
                            </div>
                            <div class="form-group">
                                <label>Twitter</label>
                                <input type="text" id="social_twitter" />
                            </div>
                            <div class="form-group">
                                <label>GitHub</label>
                                <input type="text" id="social_github" />
                            </div>
                            <div class="form-group">
                                <label>LinkedIn</label>
                                <input type="text" id="social_linkedin" />
                            </div>
                            <div class="form-group">
                                <label>Profile Visibility</label>
                                <select id="visibility">
                                    <option value="public">Public</option>
                                    <option value="private">Private</option>
                                    <option value="anonymous">Anonymous</option>
                                </select>
                            </div>
                            <button type="submit" class="btn btn-primary">Save Profile</button>
                        </form>
                    </section>
                    <section id="account-section" class="tab-content">
                        <h2>Account Settings</h2>
                        <form id="settingsForm">
                            <div class="form-group">
                                <label>Theme</label>
                                <select id="theme">
                                    <option value="system">System</option>
                                    <option value="light">Light</option>
                                    <option value="dark">Dark</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Font Size</label>
                                <select id="font_size">
                                    <option value="small">Small</option>
                                    <option value="medium">Medium</option>
                                    <option value="large">Large</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Language</label>
                                <select id="language">
                                    <option value="en">English</option>
                                    <option value="es">Spanish</option>
                                    <option value="fr">French</option>
                                    <option value="de">German</option>
                                    <option value="ja">Japanese</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Timezone</label>
                                <select id="timezone">
                                    <option value="UTC">UTC</option>
                                    <option value="America/New_York">Eastern Time</option>
                                    <option value="America/Chicago">Central Time</option>
                                    <option value="America/Denver">Mountain Time</option>
                                    <option value="America/Los_Angeles">Pacific Time</option>
                                    <option value="Europe/London">London</option>
                                    <option value="Europe/Berlin">Berlin</option>
                                    <option value="Asia/Tokyo">Tokyo</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Date Format</label>
                                <select id="date_format">
                                    <option value="YYYY-MM-DD">YYYY-MM-DD</option>
                                    <option value="MM/DD/YYYY">MM/DD/YYYY</option>
                                    <option value="DD/MM/YYYY">DD/MM/YYYY</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label><input type="checkbox" id="email_notifications" /> Email Notifications</label>
                            </div>
                            <div class="form-group">
                                <label><input type="checkbox" id="push_notifications" /> Push Notifications</label>
                            </div>
                            <div class="form-group">
                                <label><input type="checkbox" id="compact_mode" /> Compact Mode</label>
                            </div>
                            <button type="submit" class="btn btn-primary">Save Settings</button>
                        </form>
                    </section>
                    <section id="learning-section" class="tab-content">
                        <h2>Learning Preferences</h2>
                        <form id="learningForm">
                            <div class="form-group">
                                <label>Daily Learning Goal (minutes)</label>
                                <select id="daily_goal_minutes">
                                    <option value="10">10</option>
                                    <option value="15">15</option>
                                    <option value="20">20</option>
                                    <option value="30">30</option>
                                    <option value="45">45</option>
                                    <option value="60">60</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Daily Review Items</label>
                                <select id="daily_review_items">
                                    <option value="5">5</option>
                                    <option value="10">10</option>
                                    <option value="20">20</option>
                                    <option value="30">30</option>
                                    <option value="50">50</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Session Length (minutes)</label>
                                <select id="session_length_minutes">
                                    <option value="10">10</option>
                                    <option value="15">15</option>
                                    <option value="20">20</option>
                                    <option value="30">30</option>
                                    <option value="45">45</option>
                                    <option value="60">60</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Break Reminder (minutes)</label>
                                <select id="break_reminder_minutes">
                                    <option value="15">15</option>
                                    <option value="25">25</option>
                                    <option value="45">45</option>
                                    <option value="60">60</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Preferred Session Time</label>
                                <select id="preferred_session_time">
                                    <option value="flexible">Flexible</option>
                                    <option value="morning">Morning</option>
                                    <option value="afternoon">Afternoon</option>
                                    <option value="evening">Evening</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>Difficulty</label>
                                <select id="difficulty_preference">
                                    <option value="auto">Auto</option>
                                    <option value="easy">Easy</option>
                                    <option value="normal">Normal</option>
                                    <option value="hard">Hard</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label><input type="checkbox" id="show_streaks" /> Show Streaks</label>
                            </div>
                            <div class="form-group">
                                <label><input type="checkbox" id="show_leaderboards" /> Show Leaderboards</label>
                            </div>
                            <div class="form-group">
                                <label><input type="checkbox" id="show_achievements" /> Show Achievements</label>
                            </div>
                            <button type="submit" class="btn btn-primary">Save Preferences</button>
                        </form>
                    </section>
                </div>
            </div>
        }
        #css {
            .settings-page { max-width: 800px; margin: 2rem auto; padding: 0 1rem; font-family: system-ui, sans-serif; }
            .settings-nav { display: flex; gap: 1rem; border-bottom: 1px solid hsl(var(--border)); margin-bottom: 2rem; }
            .settings-nav .tab { padding: 0.75rem 1.5rem; text-decoration: none; color: hsl(var(--muted-foreground)); border-bottom: 2px solid transparent; font-weight: 500; transition: color 0.15s; }
            .settings-nav .tab.active { color: hsl(217 91% 60%); border-bottom-color: hsl(217 91% 60%); }
            .settings-nav .tab:hover { color: hsl(var(--foreground)); }
            .tab-content { display: none; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 2rem; }
            .tab-content.active { display: block; }
            .tab-content h2 { margin-bottom: 1.5rem; font-size: 1.25rem; color: hsl(var(--foreground)); }
            .form-group { margin-bottom: 1.25rem; }
            .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; font-size: 0.9rem; color: hsl(var(--foreground)); }
            .form-group input, .form-group select, .form-group textarea { width: 100%; padding: 0.75rem; border: 1px solid hsl(var(--border)); border-radius: 8px; font-size: 0.95rem; background: hsl(var(--background)); color: hsl(var(--foreground)); box-sizing: border-box; }
            .form-group input:focus, .form-group select:focus, .form-group textarea:focus { outline: none; border-color: hsl(217 91% 60%); box-shadow: 0 0 0 3px hsl(217 91% 60% / 15%); }
            .form-group small { display: block; margin-top: 0.25rem; color: hsl(var(--muted-foreground)); font-size: 0.8rem; }
            .form-group textarea { resize: vertical; min-height: 80px; }
            .btn { padding: 0.75rem 1.5rem; border: none; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 0.95rem; transition: all 0.15s; }
            .btn-primary { background: hsl(217 91% 60%); color: white; }
            .btn-primary:hover { background: hsl(217 91% 50%); }
            @media (max-width: 600px) { .settings-page { padding: 0 0.5rem; } .settings-nav { gap: 0.5rem; } .settings-nav .tab { padding: 0.5rem 1rem; font-size: 0.9rem; } .tab-content { padding: 1.5rem; } }
        }
        #js {
            document.querySelectorAll('.settings-nav .tab').forEach(function(tab) {
                tab.addEventListener('click', function(e) {
                    e.preventDefault();
                    document.querySelectorAll('.settings-nav .tab').forEach(function(t) { t.classList.remove('active'); });
                    document.querySelectorAll('.tab-content').forEach(function(c) { c.classList.remove('active'); });
                    tab.classList.add('active');
                    var target = document.getElementById(tab.dataset.tab + '-section');
                    if(target) { target.classList.add('active'); }
                });
            });
            var token = localStorage.getItem('session_token');
            var headers = {};
            if(token) { headers['Authorization'] = 'Bearer ' + token; }
            fetch('/api/user/profile', { headers: headers })
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    if(data.display_name) { document.getElementById('display_name').value = data.display_name; }
                    if(data.username) { document.getElementById('username').value = data.username; }
                    if(data.bio) { document.getElementById('bio').value = data.bio; }
                    if(data.location) { document.getElementById('location').value = data.location; }
                    if(data.website) { document.getElementById('website').value = data.website; }
                    if(data.visibility) { document.getElementById('visibility').value = data.visibility; }
                }).catch(function() {});
            fetch('/api/user/settings', { headers: headers })
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    if(data.theme) { document.getElementById('theme').value = data.theme; }
                    if(data.font_size) { document.getElementById('font_size').value = data.font_size; }
                    if(data.language) { document.getElementById('language').value = data.language; }
                    if(data.timezone) { document.getElementById('timezone').value = data.timezone; }
                    if(data.date_format) { document.getElementById('date_format').value = data.date_format; }
                    if(data.email_notifications !== undefined) { document.getElementById('email_notifications').checked = data.email_notifications; }
                    if(data.push_notifications !== undefined) { document.getElementById('push_notifications').checked = data.push_notifications; }
                    if(data.compact_mode !== undefined) { document.getElementById('compact_mode').checked = data.compact_mode; }
                }).catch(function() {});
            fetch('/api/user/learning-preferences', { headers: headers })
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    if(data.daily_goal_minutes) { document.getElementById('daily_goal_minutes').value = data.daily_goal_minutes; }
                    if(data.daily_review_items) { document.getElementById('daily_review_items').value = data.daily_review_items; }
                    if(data.session_length_minutes) { document.getElementById('session_length_minutes').value = data.session_length_minutes; }
                    if(data.break_reminder_minutes) { document.getElementById('break_reminder_minutes').value = data.break_reminder_minutes; }
                    if(data.preferred_session_time) { document.getElementById('preferred_session_time').value = data.preferred_session_time; }
                    if(data.difficulty_preference) { document.getElementById('difficulty_preference').value = data.difficulty_preference; }
                    if(data.show_streaks !== undefined) { document.getElementById('show_streaks').checked = data.show_streaks; }
                    if(data.show_leaderboards !== undefined) { document.getElementById('show_leaderboards').checked = data.show_leaderboards; }
                    if(data.show_achievements !== undefined) { document.getElementById('show_achievements').checked = data.show_achievements; }
                }).catch(function() {});
            document.getElementById('profileForm').addEventListener('submit', function(e) {
                e.preventDefault();
                var body = JSON.stringify({
                    display_name: document.getElementById('display_name').value,
                    username: document.getElementById('username').value,
                    bio: document.getElementById('bio').value,
                    location: document.getElementById('location').value,
                    website: document.getElementById('website').value,
                    visibility: document.getElementById('visibility').value
                });
                fetch('/api/user/profile', { method: 'PUT', headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + localStorage.getItem('session_token') }, body: body })
                    .then(function(r) { return r.json(); })
                    .then(function(data) { alert(data.ok ? 'Profile saved!' : (data.error || 'Failed to save')); })
                    .catch(function() { alert('Network error. Please try again.'); });
            });
            document.getElementById('settingsForm').addEventListener('submit', function(e) {
                e.preventDefault();
                var body = JSON.stringify({
                    theme: document.getElementById('theme').value,
                    font_size: document.getElementById('font_size').value,
                    language: document.getElementById('language').value,
                    timezone: document.getElementById('timezone').value,
                    date_format: document.getElementById('date_format').value,
                    email_notifications: document.getElementById('email_notifications').checked,
                    push_notifications: document.getElementById('push_notifications').checked,
                    compact_mode: document.getElementById('compact_mode').checked
                });
                fetch('/api/user/settings', { method: 'PUT', headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + localStorage.getItem('session_token') }, body: body })
                    .then(function(r) { return r.json(); })
                    .then(function(data) { alert(data.ok ? 'Settings saved!' : (data.error || 'Failed to save')); })
                    .catch(function() { alert('Network error. Please try again.'); });
            });
            document.getElementById('learningForm').addEventListener('submit', function(e) {
                e.preventDefault();
                var body = JSON.stringify({
                    daily_goal_minutes: parseInt(document.getElementById('daily_goal_minutes').value),
                    daily_review_items: parseInt(document.getElementById('daily_review_items').value),
                    session_length_minutes: parseInt(document.getElementById('session_length_minutes').value),
                    break_reminder_minutes: parseInt(document.getElementById('break_reminder_minutes').value),
                    preferred_session_time: document.getElementById('preferred_session_time').value,
                    difficulty_preference: document.getElementById('difficulty_preference').value,
                    show_streaks: document.getElementById('show_streaks').checked,
                    show_leaderboards: document.getElementById('show_leaderboards').checked,
                    show_achievements: document.getElementById('show_achievements').checked
                });
                fetch('/api/user/learning-preferences', { method: 'PUT', headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + localStorage.getItem('session_token') }, body: body })
                    .then(function(r) { return r.json(); })
                    .then(function(data) { alert(data.ok ? 'Preferences saved!' : (data.error || 'Failed to save')); })
                    .catch(function() { alert('Network error. Please try again.'); });
            });
        }

        var html_out = page.toString()
        return html_out
    }

    // Public profile page with learning progress
    public func render_profile_page(username_str : *string) : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        var title = std::string_view("Profile — Underlayer")
        page.appendTitle(&title)

        #html {
            <div class="profile-page">
                <div class="profile-card">
                    <div class="profile-avatar" id="avatar"></div>
                    <h1 id="displayName">Loading...</h1>
                    <p id="bio" class="profile-bio"></p>
                    <div id="locationRow" class="profile-location" style="display:none"></div>
                    <div id="websiteRow" class="profile-website" style="display:none"></div>
                    <div id="socialRow" class="profile-social" style="display:none"></div>
                    <div class="profile-stats" id="stats"></div>
                </div>
                <div class="learning-section" id="learningSection" style="display:none">
                    <h2>Learning Progress</h2>
                    <div class="learning-summary" id="learningSummary"></div>
                    <div class="course-list" id="courseList"></div>
                </div>
            </div>
        }
        #css {
            .profile-page { max-width: 700px; margin: 2rem auto; padding: 0 1rem; font-family: system-ui, sans-serif; }
            .profile-card { text-align: center; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); padding: 2rem; border-radius: 12px; box-shadow: 0 4px 20px hsl(var(--shadow)); margin-bottom: 1.5rem; }
            .profile-avatar { width: 100px; height: 100px; border-radius: 50%; background: hsl(var(--muted)); margin: 0 auto 1rem; display: flex; align-items: center; justify-content: center; font-size: 2.5rem; font-weight: 700; color: hsl(var(--primary)); overflow: hidden; }
            .profile-avatar img { width: 100%; height: 100%; object-fit: cover; border-radius: 50%; }
            .profile-bio { color: hsl(var(--muted-foreground)); margin: 0.75rem 0; line-height: 1.5; }
            .profile-location, .profile-website, .profile-social { font-size: 0.85rem; color: hsl(var(--muted-foreground)); margin: 0.25rem 0; }
            .profile-location a, .profile-website a { color: hsl(217 91% 60%); text-decoration: none; }
            .profile-location a:hover, .profile-website a:hover { text-decoration: underline; }
            .profile-social a { color: hsl(217 91% 60%); text-decoration: none; margin: 0 0.5rem; }
            .profile-social a:hover { text-decoration: underline; }
            .profile-stats { display: flex; justify-content: center; gap: 2rem; margin-top: 1.5rem; padding-top: 1.5rem; border-top: 1px solid hsl(var(--border)); }
            .stat-item { text-align: center; }
            .stat-value { font-size: 1.5rem; font-weight: 700; color: hsl(217 91% 60%); }
            .stat-label { font-size: 0.75rem; color: hsl(var(--muted-foreground)); text-transform: uppercase; letter-spacing: 0.05em; margin-top: 0.25rem; }
            .learning-section { background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 12px; padding: 2rem; box-shadow: 0 4px 20px hsl(var(--shadow)); }
            .learning-section h2 { font-size: 1.1rem; font-weight: 600; color: hsl(var(--foreground)); margin-bottom: 1.25rem; }
            .learning-summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; }
            .summary-card { background: hsl(var(--background)); border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 1rem; text-align: center; }
            .summary-card .value { font-size: 1.25rem; font-weight: 700; color: hsl(217 91% 60%); }
            .summary-card .label { font-size: 0.75rem; color: hsl(var(--muted-foreground)); text-transform: uppercase; letter-spacing: 0.05em; margin-top: 0.25rem; }
            .course-list { display: flex; flex-direction: column; gap: 0.75rem; }
            .course-item { background: hsl(var(--background)); border: 1px solid hsl(var(--border)); border-radius: 8px; padding: 1rem 1.25rem; display: flex; align-items: center; gap: 1rem; }
            .course-info { flex: 1; min-width: 0; }
            .course-name { font-weight: 600; color: hsl(var(--foreground)); font-size: 0.95rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
            .course-meta { font-size: 0.8rem; color: hsl(var(--muted-foreground)); margin-top: 0.2rem; }
            .course-progress { width: 120px; flex-shrink: 0; }
            .progress-bar { height: 6px; background: hsl(var(--muted)); border-radius: 3px; overflow: hidden; }
            .progress-fill { height: 100%; background: hsl(217 91% 60%); border-radius: 3px; transition: width 0.3s ease; }
            .progress-text { font-size: 0.75rem; color: hsl(var(--muted-foreground)); text-align: right; margin-top: 0.25rem; }
            .course-status { font-size: 0.7rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; padding: 0.2rem 0.5rem; border-radius: 4px; flex-shrink: 0; }
            .status-active { background: hsl(217 91% 60% / 10%); color: hsl(217 91% 60%); }
            .status-completed { background: hsl(142 71% 45% / 10%); color: hsl(142 71% 45%); }
            .no-courses { text-align: center; color: hsl(var(--muted-foreground)); padding: 2rem; font-size: 0.9rem; }
            @media (max-width: 600px) { .profile-page { padding: 0 0.5rem; } .profile-card { padding: 1.5rem; } .profile-stats { gap: 1rem; } .course-item { flex-wrap: wrap; } .course-progress { width: 100%; } }
        }
        #js {
            var pathParts = window.location.pathname.split('/u/');
            var username = pathParts.length > 1 ? pathParts[1] : '';
            if(username) {
                // Fetch profile data
                fetch('/api/user/' + username)
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        if(data.error) { document.getElementById('displayName').textContent = 'User not found'; return; }
                        // Display name
                        var name = data.display_name || data.username || username;
                        document.getElementById('displayName').textContent = name;
                        // Avatar
                        var avatarEl = document.getElementById('avatar');
                        if(data.avatar_url) { avatarEl.innerHTML = '<img src="' + data.avatar_url + '" alt="Avatar" />'; }
                        else { var initials = name.charAt(0).toUpperCase(); avatarEl.textContent = initials; }
                        // Bio
                        if(data.bio) { document.getElementById('bio').textContent = data.bio; document.getElementById('bio').style.display = 'block'; }
                        // Location
                        if(data.location) { document.getElementById('locationRow').textContent = '\uD83D\uDCCD ' + data.location; document.getElementById('locationRow').style.display = 'block'; }
                        // Website
                        if(data.website) { document.getElementById('websiteRow').innerHTML = '\uD83C\uDF10 <a href="' + data.website + '" target="_blank" rel="noopener">' + data.website + '</a>'; document.getElementById('websiteRow').style.display = 'block'; }
                        // Social links
                        var socialParts = [];
                        if(data.social_twitter) { socialParts.push('<a href="https://twitter.com/' + data.social_twitter + '" target="_blank" rel="noopener">Twitter</a>'); }
                        if(data.social_github) { socialParts.push('<a href="https://github.com/' + data.social_github + '" target="_blank" rel="noopener">GitHub</a>'); }
                        if(data.social_linkedin) { socialParts.push('<a href="https://linkedin.com/in/' + data.social_linkedin + '" target="_blank" rel="noopener">LinkedIn</a>'); }
                        if(socialParts.length > 0) { document.getElementById('socialRow').innerHTML = socialParts.join(' '); document.getElementById('socialRow').style.display = 'block'; }
                    }).catch(function() {
                        document.getElementById('displayName').textContent = 'User not found';
                    });

                // Fetch stats data
                fetch('/api/user/' + username + '/stats')
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        if(data.error) { return; }
                        var statsHtml = '';
                        if(data.courses_completed !== undefined) { statsHtml += '<div class="stat-item"><div class="stat-value">' + data.courses_completed + '</div><div class="stat-label">Courses Done</div></div>'; }
                        if(data.total_concepts_mastered !== undefined) { statsHtml += '<div class="stat-item"><div class="stat-value">' + data.total_concepts_mastered + '</div><div class="stat-label">Concepts</div></div>'; }
                        if(data.total_exercises_completed !== undefined) { statsHtml += '<div class="stat-item"><div class="stat-value">' + data.total_exercises_completed + '</div><div class="stat-label">Exercises</div></div>'; }
                        var hours = data.total_time_seconds ? Math.floor(data.total_time_seconds / 3600) : 0;
                        if(hours > 0) { statsHtml += '<div class="stat-item"><div class="stat-value">' + hours + '</div><div class="stat-label">Hours</div></div>'; }
                        if(statsHtml) { document.getElementById('stats').innerHTML = statsHtml; }
                    }).catch(function() {});

                // Fetch courses data
                fetch('/api/user/' + username + '/courses')
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        if(!Array.isArray(data) || data.length === 0) {
                            document.getElementById('courseList').innerHTML = '<div class="no-courses">No courses in progress yet.</div>';
                            document.getElementById('learningSection').style.display = 'block';
                            return;
                        }
                        // Learning summary
                        var totalStarted = 0;
                        var totalMastered = 0;
                        var totalConcepts = 0;
                        data.forEach(function(c) { totalStarted += c.concepts_started || 0; totalMastered += c.concepts_mastered || 0; totalConcepts += c.total_concepts || 0; });
                        var summaryHtml = '<div class="summary-card"><div class="value">' + totalStarted + '</div><div class="label">Concepts Started</div></div>';
                        summaryHtml += '<div class="summary-card"><div class="value">' + totalMastered + '</div><div class="label">Concepts Mastered</div></div>';
                        summaryHtml += '<div class="summary-card"><div class="value">' + totalConcepts + '</div><div class="label">Total Concepts</div></div>';
                        document.getElementById('learningSummary').innerHTML = summaryHtml;
                        // Course list
                        var html = '';
                        data.forEach(function(c) {
                            var pct = c.progress_pct || 0;
                            var statusClass = c.status === 'completed' ? 'status-completed' : 'status-active';
                            var statusLabel = c.status === 'completed' ? 'Completed' : 'In Progress';
                            var meta = c.concepts_mastered + '/' + c.total_concepts + ' concepts mastered';
                            html += '<div class="course-item">';
                            html += '<div class="course-info"><div class="course-name">' + c.course_id + '</div><div class="course-meta">' + meta + '</div></div>';
                            html += '<div class="course-progress"><div class="progress-bar"><div class="progress-fill" style="width:' + pct + '%"></div></div><div class="progress-text">' + Math.round(pct) + '%</div></div>';
                            html += '<span class="course-status ' + statusClass + '">' + statusLabel + '</span>';
                            html += '</div>';
                        });
                        document.getElementById('courseList').innerHTML = html;
                        document.getElementById('learningSection').style.display = 'block';
                    }).catch(function() {
                        document.getElementById('learningSection').style.display = 'block';
                    });
            }
        }

        var html_out = page.toString()
        return html_out
    }

}
