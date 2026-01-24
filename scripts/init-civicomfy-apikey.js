// Auto-configure Civitai API key from environment
// Cookie name: civitaiDownloaderSettings (JSON format)
(function() {
    const API_KEY = '__CIVITAI_API_KEY__';
    if (API_KEY && API_KEY !== '__CIVITAI_API_KEY__' && API_KEY !== '') {
        const COOKIE_NAME = 'civitaiDownloaderSettings';

        // Try to load existing settings
        let settings = {};
        const existingCookie = document.cookie
            .split('; ')
            .find(row => row.startsWith(COOKIE_NAME + '='));
        if (existingCookie) {
            try {
                settings = JSON.parse(decodeURIComponent(existingCookie.split('=')[1]));
            } catch (e) {}
        }

        // Set API key if not already set
        if (!settings.apiKey) {
            settings.apiKey = API_KEY;
            const expires = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toUTCString();
            document.cookie = COOKIE_NAME + '=' + encodeURIComponent(JSON.stringify(settings))
                + '; expires=' + expires + '; path=/; SameSite=Lax';
            console.log('[Civicomfy] API key configured from environment');
        }
    }
})();
