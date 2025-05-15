// i18n.js
(async function(){
  // 1. Charger le JSON
  const resp = await fetch('translations.json');
  const TRANSLATIONS = await resp.json();

  // 2. Détecter la langue (ex: "fr", "en", "es")
  const code = (navigator.language || navigator.userLanguage || 'en').split('-')[0];
  const lang = TRANSLATIONS[code] ? code : 'en';

  // 3. utilitaire pour accéder à une clé imbriquée
  function getNested(obj, path) {
    return path.split('.').reduce((o,k) => o?.[k], obj);
  }

  // 4. Mettre à jour <html lang="…">
  document.documentElement.lang = lang;

  // 5. Injecter le contenu innerHTML
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    const txt = getNested(TRANSLATIONS[lang], key);
    if (txt != null) el.innerHTML = txt;
  });

  // 6. Attributs spéciaux (title, placeholder, alt, value)
  ['title','placeholder','alt','value'].forEach(attr => {
    document.querySelectorAll(`[data-i18n-${attr}]`).forEach(el => {
      const key = el.getAttribute(`data-i18n-${attr}`);
      const val = getNested(TRANSLATIONS[lang], key);
      if (val != null) el.setAttribute(attr, val);
    });
  });
})();
