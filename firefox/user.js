// Firefox preferences for the rice.
// Copy this file and the chrome/ folder into your profile folder
// Firefox applies these on every launch.

/*** THEME ***/
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // load chrome/userChrome.css and userContent.css
user_pref("browser.tabs.allow_transparent_browser", true);              // let the transparent background show through
user_pref("browser.theme.toolbar-theme", 0);                             // dark browser UI
user_pref("ui.systemUsesDarkTheme", 1);                                  // treat the system as dark

/*** AI / ML FEATURES OFF ***/
user_pref("browser.ai.control.default", "blocked");
user_pref("browser.ai.control.linkPreviewKeyPoints", "blocked");
user_pref("browser.ai.control.pdfjsAltText", "blocked");
user_pref("browser.ai.control.sidebarChatbot", "blocked");
user_pref("browser.ai.control.smartTabGroups", "blocked");
user_pref("browser.ai.control.smartWindow", "blocked");
user_pref("browser.ai.control.speechRecognition", "blocked");
user_pref("browser.ai.control.translations", "blocked");
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.page", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("browser.ml.linkPreview.longPress", false);
user_pref("browser.smartwindow.memories.generateFromConversation", false);
user_pref("browser.smartwindow.memories.generateFromHistory", false);
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("browser.tabs.groups.smart.userEnabled", false);
user_pref("extensions.ml.enabled", false);
user_pref("pdfjs.enableAltText", false);
user_pref("browser.translations.enable", false);

/*** TELEMETRY OFF ***/
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.usage.uploadEnabled", false);

/*** PRIVACY ***/
user_pref("privacy.globalprivacycontrol.enabled", true);    // send "do not sell/share" signal to sites
user_pref("network.dns.disablePrefetch", true);             // no DNS lookups for links you haven't clicked
user_pref("network.prefetch-next", false);                  // no preloading of pages you haven't opened
user_pref("network.http.speculative-parallel-limit", 0);    // no early connections on link hover
user_pref("signon.rememberSignons", false);                 // don't offer to save passwords
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

// On shutdown: clear cache, cookies/site data and form data, keep history
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown_v2.cache", true);
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", true);
user_pref("privacy.clearOnShutdown_v2.formdata", true);
user_pref("privacy.clearOnShutdown_v2.browsingHistoryAndDownloads", false);

/*** ADDRESS BAR SUGGESTIONS ***/
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.openpage", false);
user_pref("browser.urlbar.suggest.quickactions", false);
user_pref("browser.urlbar.suggest.recentsearches", false);
user_pref("browser.urlbar.suggest.topsites", false);

/*** NEW TAB PAGE ***/
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.widgets.enabled", false);
user_pref("browser.newtabpage.activity-stream.widgets.sportsWidget.enabled", false);
user_pref("browser.newtabpage.activity-stream.widgets.system.sportsWidget.enabled", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);   // no extension recommendations
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false); // no feature recommendations

/*** TOOLBAR LAYOUT  ***/
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"_d04b0b40-3dab-4f0b-97a6-04ec3eddbfb0_-browser-action\"],\"nav-bar\":[\"back-button\",\"forward-button\",\"vertical-spacer\",\"urlbar-container\",\"downloads-button\",\"reset-pbm-toolbar-button\",\"fxa-toolbar-menu-button\",\"unified-extensions-button\",\"ublock0_raymondhill_net-browser-action\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"smartwindow-group-tabs-button\",\"ai-window-toggle\"],\"vertical-tabs\":[],\"PersonalToolbar\":[\"personal-bookmarks\"]},\"seen\":[],\"dirtyAreaCache\":[],\"currentVersion\":28,\"newElementCount\":9}");
