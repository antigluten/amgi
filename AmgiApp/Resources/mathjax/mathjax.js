(() => {
  const packages = ["noerrors", "mathtools"];
  const packagesForLoading = packages.map((name) => `[tex]/${name}`);

  window.MathJax = {
    tex: {
      inlineMath: [["\\(", "\\)"]],
      displayMath: [["\\[", "\\]"]],
      processEscapes: false,
      processEnvironments: false,
      processRefs: false,
      packages: {
        "[+]": packages,
        "[-]": ["textmacros"],
      },
    },
    loader: {
      load: packagesForLoading,
      paths: {
        mathjax: "amgi-asset://assets/mathjax/vendor",
      },
    },
    startup: {
      typeset: false,
    },
  };
})();
