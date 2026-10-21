// Loads Embedded Messaging from a same-origin static resource because the LWR site CSP blocks inline scripts.
(function () {
    var site = 'https://YOUR_MYDOMAIN.my.site.com/YOUR_ESW_SITE_PATH';
    if (window.__hcpChatLoading) { return; }
    window.__hcpChatLoading = true;
    var s = document.createElement('script');
    s.src = site + '/assets/js/bootstrap.min.js';
    s.onload = function () {
        try {
            window.embeddedservice_bootstrap.settings.language = 'en_US';
            window.embeddedservice_bootstrap.init('YOUR_ORG_ID', 'HCP_Portal_Agent', site,
                { scrt2URL: 'https://YOUR_MYDOMAIN.my.salesforce-scrt.com' });
        } catch (e) { console.error('Error loading Embedded Messaging: ', e); }
    };
    document.head.appendChild(s);
})();
