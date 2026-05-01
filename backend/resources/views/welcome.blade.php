<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Dewprofi API</title>
    <style>
        :root {
            font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            color: #111827;
            background: #eef2f7;
        }

        * {
            box-sizing: border-box;
        }

        body {
            min-height: 100vh;
            margin: 0;
            display: grid;
            place-items: center;
            padding: 24px;
        }

        main {
            width: min(880px, 100%);
            border: 1px solid #d1d5db;
            border-radius: 8px;
            background: #ffffff;
            padding: clamp(24px, 5vw, 44px);
            box-shadow: 0 18px 45px rgba(15, 23, 42, 0.08);
        }

        p {
            color: #4b5563;
            line-height: 1.6;
        }

        h1 {
            margin: 0;
            font-size: clamp(2.4rem, 7vw, 5rem);
            line-height: 0.96;
            letter-spacing: 0;
        }

        .eyebrow {
            margin: 0 0 10px;
            color: #0f766e;
            font-size: 0.78rem;
            font-weight: 800;
            text-transform: uppercase;
        }

        .actions {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            margin-top: 28px;
        }

        a {
            min-height: 44px;
            display: inline-flex;
            align-items: center;
            border-radius: 6px;
            padding: 0 16px;
            color: #ffffff;
            background: #0f766e;
            font-weight: 800;
            text-decoration: none;
        }

        a.secondary {
            color: #0f172a;
            background: #e2e8f0;
        }

        code {
            border-radius: 4px;
            padding: 2px 5px;
            color: #111827;
            background: #e5e7eb;
        }
    </style>
</head>
<body>
    <main>
        <p class="eyebrow">Dewprofi Backend</p>
        <h1>API bereit.</h1>
        <p>
            Dieses Laravel-Backend stellt die Auth-API fuer das separate Dewprofi-Frontend bereit.
            Die Anwendung selbst laeuft unter <code>app.dewprofi.test</code>.
        </p>
        <div class="actions">
            <a href="http://app.dewprofi.test">Frontend oeffnen</a>
            <a class="secondary" href="/api/health">API Health</a>
        </div>
    </main>
</body>
</html>
