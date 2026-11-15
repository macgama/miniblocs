// Visionneuse des captures (page MiniBlocs). Sans ce script, les liens ouvrent l'image.
(function () {
  var d = document.querySelector('.visionneuse');
  if (!d || !d.showModal) return;
  var liens = Array.prototype.slice.call(document.querySelectorAll('[data-galerie]'));
  var img = d.querySelector('img'), leg = d.querySelector('.legende'), i = 0;
  function montre(n) {
    i = (n + liens.length) % liens.length;
    var a = liens[i], petite = a.querySelector('img');
    img.src = a.getAttribute('href');
    img.alt = petite ? petite.alt : '';
    leg.textContent = img.alt;
  }
  liens.forEach(function (a, n) {
    a.addEventListener('click', function (ev) { ev.preventDefault(); montre(n); d.showModal(); });
  });
  d.querySelector('.prec').addEventListener('click', function () { montre(i - 1); });
  d.querySelector('.suiv').addEventListener('click', function () { montre(i + 1); });
  d.addEventListener('keydown', function (ev) {
    if (ev.key === 'ArrowLeft') montre(i - 1);
    if (ev.key === 'ArrowRight') montre(i + 1);
  });
  d.addEventListener('click', function (ev) { if (ev.target === d) d.close(); });
})();
