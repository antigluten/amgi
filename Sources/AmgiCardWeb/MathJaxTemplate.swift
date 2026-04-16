import Foundation

public enum MathJaxTemplate {
    public static func wrap(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
            body {
                font-family: -apple-system, system-ui;
                font-size: 18px;
                line-height: 1.5;
                color: #f5f5f5;
                background: transparent;
                padding: 16px;
                margin: 0;
                text-align: center;
                display: flex;
                align-items: center;
                justify-content: center;
                min-height: 80vh;
            }
            .card { max-width: 600px; width: 100%; }
            hr { border: none; border-top: 1px solid rgba(255,255,255,0.2); margin: 16px 0; }
            img { max-width: 100%; height: auto; border-radius: 8px; }
            button.amgi-play {
                display: inline-flex;
                align-items: center;
                justify-content: center;
                width: 40px; height: 40px;
                border-radius: 20px;
                border: none;
                background: rgba(255,255,255,0.12);
                color: inherit;
                font-size: 18px;
                cursor: pointer;
                margin: 4px;
            }
            button.amgi-play:active { background: rgba(255,255,255,0.24); }
            @media (prefers-color-scheme: light) {
                body { color: #1a1a1a; }
                hr { border-top-color: rgba(0,0,0,0.2); }
                button.amgi-play { background: rgba(0,0,0,0.08); }
                button.amgi-play:active { background: rgba(0,0,0,0.16); }
            }
        </style>
        <script>
        window.MathJax = {
          tex: { inlineMath: [['\\\\(', '\\\\)']], displayMath: [['\\\\[', '\\\\]']] },
          svg: { fontCache: 'global' },
          startup: { typeset: true }
        };
        function amgiPlay(id) {
          const el = document.getElementById(id);
          if (!el) return;
          el.currentTime = 0;
          el.play().catch(() => {});
        }
        </script>
        <script src="amgi-asset://assets/mathjax/tex-svg.js" async></script>
        </head>
        <body><div class="card">\(body)</div></body>
        </html>
        """
    }
}
