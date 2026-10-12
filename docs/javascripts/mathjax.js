window.MathJax = {
  tex: { inlineMath: [["\\(", "\\)"]], displayMath: [["\\[", "\\]"]], processEscapes: true, processEnvironments: true, tags: "ams" },
  options: { ignoreHtmlClass: ".*|", processHtmlClass: "arithmatex" },
};
// Перерисовка при мгновенной навигации Material. Ждём startup.promise: если вызвать clearCache()
// параллельно с первичной отрисовкой, из CSS пропадают правила глифов и формулы становятся пустыми
// (см. «Отладка», ошибка 3).
let firstPage = true;
document$.subscribe(() => {
  if (firstPage) { firstPage = false; return; }
  MathJax.startup.promise = MathJax.startup.promise.then(() => {
    MathJax.startup.output.clearCache();
    MathJax.typesetClear();
    MathJax.texReset();
    return MathJax.typesetPromise();
  });
});
