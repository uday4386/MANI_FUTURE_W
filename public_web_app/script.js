(function () {
  var toggle = document.querySelector("[data-nav-toggle]");
  var nav = document.querySelector("[data-nav]");
  var LANG_KEY = "samanyudu_lang";
  var currentLang = localStorage.getItem(LANG_KEY) || "en";

  if (toggle && nav) {
    toggle.addEventListener("click", function () {
      var isOpen = nav.classList.toggle("open");
      toggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
    });
  }

  
  function injectLanguageControl() {
    if (document.querySelector("[data-lang-control]")) return;
    var footerMeta = document.querySelector(".site-footer .footer-grid section:last-child");
    if (!footerMeta) return;

    var wrap = document.createElement("div");
    wrap.className = "lang-switch";
    wrap.setAttribute("data-lang-control", "true");

    var label = document.createElement("label");
    label.setAttribute("for", "site-language");
    label.textContent = currentLang === "te" ? "భాష" : "Language";

    var select = document.createElement("select");
    select.id = "site-language";
    select.setAttribute("data-lang-select", "true");

    var optEn = document.createElement("option");
    optEn.value = "en";
    optEn.textContent = "English";

    var optTe = document.createElement("option");
    optTe.value = "te";
    optTe.textContent = "తెలుగు";

    select.appendChild(optEn);
    select.appendChild(optTe);
    select.value = currentLang;

    select.addEventListener("change", function (event) {
      currentLang = event.target.value === "te" ? "te" : "en";
      localStorage.setItem(LANG_KEY, currentLang);
      
      // Set Google Translate cookie
      document.cookie = "googtrans=/en/" + currentLang + "; path=/";
      document.cookie = "googtrans=/en/" + currentLang + "; domain=" + window.location.hostname + "; path=/";
      window.location.reload();
    });

    wrap.appendChild(label);
    wrap.appendChild(select);
    footerMeta.insertBefore(wrap, footerMeta.lastElementChild);
  }

  function injectGoogleTranslate() {
    // Hide the Google Translate UI
    var style = document.createElement("style");
    style.innerHTML = "body { top: 0 !important; } .skiptranslate { display: none !important; } #google_translate_element { display: none !important; }";
    document.head.appendChild(style);

    var gtContainer = document.createElement("div");
    gtContainer.id = "google_translate_element";
    document.body.appendChild(gtContainer);

    window.googleTranslateElementInit = function() {
      new google.translate.TranslateElement({
        pageLanguage: 'en',
        includedLanguages: 'en,te',
        autoDisplay: false
      }, 'google_translate_element');
    };

    var script = document.createElement("script");
    script.type = "text/javascript";
    script.src = "//translate.google.com/translate_a/element.js?cb=googleTranslateElementInit";
    document.head.appendChild(script);
    
    // Ensure cookie matches currentLang on load
    if (currentLang === "te" && document.cookie.indexOf("googtrans=/en/te") === -1) {
      document.cookie = "googtrans=/en/te; path=/";
      document.cookie = "googtrans=/en/te; domain=" + window.location.hostname + "; path=/";
    }
  }
        function apiBase() {
    if (window.SAMANYUDU_API_BASE) return window.SAMANYUDU_API_BASE;
    var saved = localStorage.getItem("samanyudu_api_base");
    if (saved) return saved;
    return "https://api.samanyudutv.in/api";
  }

  function normalize(item) {
    return {
      id: item.id,
      title: item.title || "Untitled",
      summary: item.description || "",
      category: item.type || "General",
      area: item.area || "",
      image: item.image_url || "",
      breaking: !!item.is_breaking,
      dateText: formatDate(item.timestamp),
      timestamp: item.timestamp || ""
    };
  }

  function formatDate(ts) {
    if (!ts) return "";
    var d = new Date(ts);
    if (isNaN(d.getTime())) return "";
    return d.toLocaleDateString("en-IN", { year: "numeric", month: "long", day: "numeric" });
  }

  function categoryMatch(news, page) {
    var c = (news.category || "").toLowerCase();
    if (page === "politics") return c.indexOf("polit") >= 0 || c.indexOf("రాజకీయ") >= 0;
    if (page === "local") return c.indexOf("local") >= 0 || c.indexOf("స్థానిక") >= 0;
    if (page === "sports") return c.indexOf("sport") >= 0 || c.indexOf("క్రీడ") >= 0;
    return true;
  }

  function buildCard(news) {
    var preview = truncateText(news.summary || "", 190);
    var img = news.image
      ? '<img src="' + news.image + '" alt="' + escapeHtml(news.title) + '" loading="lazy">'
      : "";
    var imgWrap = '<div class="news-image">' + img + "</div>";

    return (
      '<article class="news-card">' +
      '<a href="/articles/index.html?id=' + encodeURIComponent(news.id) + '" aria-label="' + escapeHtml(news.title) + '">' + imgWrap + "</a>" +
      '<div class="news-content">' +
      '<div class="news-meta">' +
      '<span class="chip">' + escapeHtml(news.category) + "</span>" +
      (news.dateText ? '<span>' + escapeHtml(news.dateText) + "</span>" : "") +
      (news.area ? '<span>' + escapeHtml(news.area) + "</span>" : "") +
      "</div>" +
      '<h2 class="news-title"><a href="/articles/index.html?id=' + encodeURIComponent(news.id) + '">' + escapeHtml(news.title) + "</a></h2>" +
      '<p class="news-summary">' + escapeHtml(preview) + "</p>" +
      "</div>" +
      "</article>"
    );
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function truncateText(text, limit) {
    var value = String(text || "").trim();
    if (value.length <= limit) return value;
    return value.slice(0, limit).trimEnd() + "...";
  }

  async function fetchNews() {
    var resp = await fetch(apiBase() + "/news", { headers: { "Accept": "application/json" } });
    if (!resp.ok) throw new Error("news fetch failed");
    var rows = await resp.json();
    if (!Array.isArray(rows)) return [];
    
    // Safety Filter: Only allow published news or legacy items with no status
    var publishedOnly = rows.filter(function(item) {
        var s = (item.status || "").toLowerCase();
        return s === "published" || s === "" || item.status === null;
    });

    return publishedOnly.map(normalize);
  }

  async function renderListPage(pageType) {
    var grid = document.getElementById("news-grid");
    if (!grid) return;

    grid.innerHTML = "";
    try {
      var all = await fetchNews();
      var filtered = all.filter(function (n) { return categoryMatch(n, pageType); });

      if (!filtered.length) {
        grid.innerHTML = '<article class="content-card"><p>' + ("No news published yet.") + "</p></article>";
      } else {
        grid.innerHTML = filtered.map(buildCard).join("");
      }

      var br = document.getElementById("breaking-text");
      if (br) {
        var bItem = all.find(function (n) { return n.breaking; }) || filtered[0] || all[0];
        br.textContent = bItem ? bItem.title : ("No news published yet.");
      }
    } catch (e) {
      grid.innerHTML = '<article class="content-card"><p>' + ("Unable to load news right now.") + "</p></article>";
      var brFallback = document.getElementById("breaking-text");
      if (brFallback) brFallback.textContent = ("Unable to load news right now.");
    }
  }

  async function renderArticlePage() {
    var root = document.getElementById("article-root");
    if (!root) return;

    root.innerHTML = '<article class="content-card"><p>' + ("Loading article...") + "</p></article>";
    var params = new URLSearchParams(window.location.search);
    var id = params.get("id");

    if (!id) {
      root.innerHTML = '<article class="content-card"><p>' + ("Article not found.") + '</p><p><a href="/">' + ("Back to Home") + "</a></p></article>";
      return;
    }

    try {
      var all = await fetchNews();
      var match = all.find(function (n) { return String(n.id) === String(id); });

      if (!match) {
        root.innerHTML = '<article class="content-card"><p>' + ("Article not found.") + '</p><p><a href="/">' + ("Back to Home") + "</a></p></article>";
        return;
      }

      var img = match.image
        ? '<img src="' + match.image + '" alt="' + escapeHtml(match.title) + '" loading="lazy">'
        : "";
      var hero = '<div class="article-hero article-hero--image">' + img + "</div>";

      root.innerHTML =
        '<article class="content-card">' +
        '<p class="news-meta"><span class="chip">' + escapeHtml(match.category) + "</span>" +
        (match.dateText ? '<span>' + escapeHtml(match.dateText) + "</span>" : "") +
        (match.area ? '<span>' + escapeHtml(match.area) + "</span>" : "") +
        "</p>" +
        '<h1 class="page-title">' + escapeHtml(match.title) + "</h1>" +
        hero +
        '<section class="article-body"><p>' + escapeHtml(match.summary || "") + "</p></section>" +
        '<p><a href="/">' + ("Back to Home") + "</a></p>" +
        "</article>";
    } catch (e) {
      root.innerHTML = '<article class="content-card"><p>' + ("Unable to load news right now.") + '</p><p><a href="/">' + ("Back to Home") + "</a></p></article>";
    }
  }

  async function init() {
    injectLanguageControl();
    injectGoogleTranslate();
        renderNewsPage();
  }


  function renderNewsPage() {
    var page = (document.body && document.body.dataset && document.body.dataset.page) || "";
    if (page === "home") return renderListPage("home");
    if (page === "latest") return renderListPage("latest");
    if (page === "politics") return renderListPage("politics");
    if (page === "local") return renderListPage("local");
    if (page === "sports") return renderListPage("sports");
    if (page === "article") return renderArticlePage();
  }

  init();

  // Auto-refresh news every 60 seconds without page refresh
  setInterval(function () {
    var page = (document.body && document.body.dataset && document.body.dataset.page) || "";
    // Only auto-poll on listing pages, not while reading a specific article
    if (page && page !== "article") {
      renderNewsPage();
    }
  }, 60000);

  var form = document.querySelector("[data-contact-form]");
  if (form) {
    form.addEventListener("submit", function (event) {
      event.preventDefault();
      if (currentLang === "te") {
        alert("ధన్యవాదాలు. మీ సందేశం నమోదు అయింది. అత్యవసర అభ్యర్థనలకు samanyudu@gmail.com కి మెయిల్ చేయండి.");
      } else {
        alert("Thank you. Your message has been noted. Please email samanyudu@gmail.com for urgent requests.");
      }
      form.reset();
    });
  }
})();

