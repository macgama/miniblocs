// Rend un fichier SVG ou HTML en PNG avec Chromium (Playwright).
//   node rendu.js entree.svg sortie.png largeur hauteur [transparent]
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const [entree, sortie, l, h, transp] = process.argv.slice(2);
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: +l, height: +h }, deviceScaleFactor: 1 });
  const url = 'file://' + path.resolve(entree);
  await p.goto(url);
  await p.waitForLoadState('networkidle');
  await p.screenshot({ path: sortie, omitBackground: transp === 'transparent' });
  await b.close();
})();
