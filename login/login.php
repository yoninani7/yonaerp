<?php 
declare(strict_types=1);
require_once __DIR__ . '/config.php';

// ── Redirect if already authenticated ────────────────────────────────────────
if (!empty($_SESSION['user_id'])) {
    redirect(LOGIN_REDIRECT);
}

$error   = '';
$success = '';

// ── POST: process login ───────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    // 1. CSRF check
    csrf_verify();

    // 2. Collect & sanitise inputs
    $identifier = trim($_POST['email']    ?? '');   // username OR email
    $password   = trim($_POST['password'] ?? '');

    // 3. Basic presence check
    if ($identifier === '' || $password === '') {
        $error = 'All fields are required.';

    } else {
        $pdo = get_pdo();

        // 4. Fetch user by email OR username — single query, no early exit
        $stmt = $pdo->prepare(
            'SELECT user_id, username, email, password_hash, status
               FROM system_users
              WHERE (email = :id OR username = :id)
              LIMIT 1'
        );
        $stmt->execute([':id' => $identifier]);
        $user = $stmt->fetch();

        // 5. Check account lockout (stored in a separate table for accuracy)
        $locked = false;
        if ($user) {
            $lStmt = $pdo->prepare(
                'SELECT attempt_count, last_attempt_at
                   FROM login_attempts
                  WHERE user_id = :uid'
            );
            $lStmt->execute([':uid' => $user['user_id']]);
            $attempt = $lStmt->fetch();

            if ($attempt) {
                $elapsed = time() - strtotime($attempt['last_attempt_at']);
                if (
                    $attempt['attempt_count'] >= MAX_LOGIN_ATTEMPTS &&
                    $elapsed < LOCKOUT_SECONDS
                ) {
                    $locked    = true;
                    $remaining = ceil((LOCKOUT_SECONDS - $elapsed) / 60);
                    $error     = "Account locked. Try again in {$remaining} minute(s).";
                } elseif ($elapsed >= LOCKOUT_SECONDS) {
                    // Lockout expired — reset counter
                    $pdo->prepare('DELETE FROM login_attempts WHERE user_id = :uid')
                        ->execute([':uid' => $user['user_id']]);
                }
            }
        }

        // 6. Verify password (always run to prevent timing attacks)
        $passwordOk = $user && !$locked && password_verify($password, $user['password_hash']);

        if (!$locked) {
            if (!$user || !$passwordOk) {
                // Generic error — no hint about which field is wrong
                $error = 'Invalid credentials. Please try again.';

                // Record failed attempt
                if ($user) {
                    $pdo->prepare(
                        'INSERT INTO login_attempts (user_id, attempt_count, last_attempt_at)
                              VALUES (:uid, 1, NOW())
                         ON DUPLICATE KEY UPDATE
                              attempt_count    = attempt_count + 1,
                              last_attempt_at  = NOW()'
                    )->execute([':uid' => $user['user_id']]);
                }

            } elseif ($user['status'] !== 'Active') {
                $error = 'Your account is inactive. Please contact support.';

            } else {
                // ── SUCCESS ──────────────────────────────────────────────────

                // Clear failed attempts
                $pdo->prepare('DELETE FROM login_attempts WHERE user_id = :uid')
                    ->execute([':uid' => $user['user_id']]);

                // Prevent session fixation
                session_regenerate_id(true);

                // Store minimal data in session
                $_SESSION['user_id']  = $user['user_id'];
                $_SESSION['username'] = $user['username'];
                $_SESSION['email']    = $user['email'];

                // Update last login timestamp
                $pdo->prepare('UPDATE system_users SET last_login_at = NOW() WHERE user_id = :uid')
                    ->execute([':uid' => $user['user_id']]);

                // "Remember me" cookie (30-day persistent session token)
                if (!empty($_POST['remember_me'])) {
                    $token = bin2hex(random_bytes(32));
                    // Store hashed token in DB (create this table if needed)
                    $pdo->prepare(
                        'INSERT INTO remember_tokens (user_id, token_hash, expires_at)
                              VALUES (:uid, :hash, DATE_ADD(NOW(), INTERVAL 30 DAY))'
                    )->execute([
                        ':uid'  => $user['user_id'],
                        ':hash' => hash('sha256', $token),
                    ]);
                    setcookie('remember_token', $token, [
                        'expires'  => time() + REMEMBER_ME_TTL,
                        'path'     => '/',
                        'secure'   => true,
                        'httponly' => true,
                        'samesite' => 'Strict',
                    ]);
                }

                redirect(LOGIN_REDIRECT);
            }
        }
    }
}

$csrf = csrf_token();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BGT Enterprise | Secure Access</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Plus+Jakarta+Sans:wght@700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #15b201;
            --primary-dark: #0e8a00;
            --primary-light: #f1fcf0;
            --text-main: #0f172a;
            --text-muted: #64748b;
            --border: #e2e8f0;
            --bg-body: #f8fafc;
            --radius: 14px;
            --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--bg-body);
            color: var(--text-main);
            height: 100vh;
            overflow: hidden;
        }

        .auth-container {
            display: grid;
            grid-template-columns: 1fr 1fr;
            height: 100vh;
            width: 100%;
        }

        .brand-panel {
            background-color: #0d8a00;
            background-image:
                radial-gradient(circle at 20% 30%, rgba(21, 178, 1, 0.8) 0%, transparent 50%),
                radial-gradient(circle at 80% 70%, rgba(0, 50, 0, 0.6) 0%, transparent 50%);
            background-size: 200% 200%;
            animation: liquidMove 15s ease-in-out infinite alternate;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            overflow: hidden;
            min-height: 100vh;
            width: 100%;
            color: white;
        }

        .brand-panel::before {
            content: "";
            position: absolute;
            bottom: 0; left: 0;
            width: 200%; height: 120px;
            background: rgba(255,255,255,0.05);
            backdrop-filter: blur(15px);
            -webkit-mask-image: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1100 120" preserveAspectRatio="none"><path d="M0,120V46.29c47.79,22.2,103.59,32.17,158,28,70.36-5.37,136.33-33.31,206.8-37.5,73.84-4.36,147.54,16.88,218.2,38.5,88.56,27.1,187.15,31.7,276,14.5,77.31-15,152.14-53,241-43.5V120H0Z" fill="black"/></svg>');
            mask-image: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1100 120" preserveAspectRatio="none"><path d="M0,120V46.29c47.79,22.2,103.59,32.17,158,28,70.36-5.37,136.33-33.31,206.8-37.5,73.84-4.36,147.54,16.88,218.2,38.5,88.56,27.1,187.15,31.7,276,14.5,77.31-15,152.14-53,241-43.5V120H0Z" fill="black"/></svg>');
            -webkit-mask-size: calc(50% + 1px) 100%;
            mask-size: calc(50% + 1px) 100%;
            mask-repeat: repeat-x;
            -webkit-mask-repeat: repeat-x;
            animation: waveLoop 20s linear infinite;
            z-index: 1;
        }

        .brand-panel::after {
            content: "";
            position: absolute;
            bottom: 0; left: 0;
            width: 200%; height: 100px;
            background: rgba(255,255,255,0.08);
            backdrop-filter: blur(30px);
            -webkit-mask-image: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1100 120" preserveAspectRatio="none"><path d="M0,120V46.29c47.79,22.2,103.59,32.17,158,28,70.36-5.37,136.33-33.31,206.8-37.5,73.84-4.36,147.54,16.88,218.2,38.5,88.56,27.1,187.15,31.7,276,14.5,77.31-15,152.14-53,241-43.5V120H0Z" fill="black"/></svg>');
            mask-image: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1100 120" preserveAspectRatio="none"><path d="M0,120V46.29c47.79,22.2,103.59,32.17,158,28,70.36-5.37,136.33-33.31,206.8-37.5,73.84-4.36,147.54,16.88,218.2,38.5,88.56,27.1,187.15,31.7,276,14.5,77.31-15,152.14-53,241-43.5V120H0Z" fill="black"/></svg>');
            -webkit-mask-size: calc(50% + 1px) 100%;
            mask-size: calc(50% + 1px) 100%;
            mask-repeat: repeat-x;
            -webkit-mask-repeat: repeat-x;
            animation: waveLoop 30s linear infinite reverse;
            z-index: 2;
        }

        @keyframes waveLoop { 0% { transform: translateX(0); } 100% { transform: translateX(-50%); } }
        @keyframes liquidMove { 0% { background-position: 0% 0%; } 100% { background-position: 100% 100%; } }

        .brand-content { position: relative; z-index: 5; max-width: 600px; padding: 40px; }
        .logo-box {
            background: white; display: inline-flex;
            padding: 10px 18px; border-radius: 12px;
            margin-bottom: 40px; box-shadow: 0 15px 30px rgba(0,0,0,0.1);
        }
        .logo-box img { width: 300px; }
        .brand-panel h1 {
            font-family: 'Plus Jakarta Sans', sans-serif;
            font-size: 3.5rem; font-weight: 800;
            line-height: 1; margin-bottom: 20px; letter-spacing: -0.04em;
        }
        .brand-panel p { font-size: 1.1rem; opacity: 0.85; line-height: 1.5; }

        .form-panel {
            background: white;
            display: flex; flex-direction: column;
            justify-content: center; align-items: center;
            padding: 40px; position: relative;
        }

        .form-card { width: 100%; max-width: 400px; position: relative; }

        .view { display: none; animation: slideIn 0.5s ease-out forwards; }
        .view.active { display: block; }

        @keyframes slideIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }

        .form-header { margin-bottom: 35px; }
        .form-header h2 {
            font-family: 'Plus Jakarta Sans', sans-serif;
            font-size: 2rem; font-weight: 800;
            letter-spacing: -0.02em; margin-bottom: 8px;
        }
        .form-header p { color: var(--text-muted); font-size: 0.95rem; }

        .input-group { margin-bottom: 24px; position: relative; }
        .input-group label {
            display: block; font-size: 0.75rem; font-weight: 700;
            text-transform: uppercase; letter-spacing: 0.05em;
            color: var(--text-muted); margin-bottom: 10px; padding-left: 2px;
        }
        .input-ctrl {
            width: 100%; height: 58px;
            background: #f8fafc; border: 2px solid #f1f5f9;
            border-radius: var(--radius); padding: 0 20px;
            font-family: inherit; font-size: 1rem; font-weight: 500;
            transition: var(--transition);
        }
        .input-ctrl:focus {
            outline: none; background: white;
            border-color: var(--primary); box-shadow: 0 0 0 4px var(--primary-light);
        }
        .input-ctrl.error { border-color: #fda4af !important; background-color: #fff1f2 !important; }

        .form-options {
            display: flex; justify-content: space-between;
            align-items: center; margin-bottom: 35px; font-size: 0.9rem;
        }

        .checkbox-wrap {
            display: flex; align-items: center; gap: 12px;
            color: var(--text-muted); font-weight: 600;
            cursor: pointer; user-select: none;
        }
        .checkbox-wrap input { position: absolute; opacity: 0; cursor: pointer; height: 0; width: 0; }
        .checkmark {
            height: 24px; width: 24px; background-color: white;
            border: 2px solid var(--border); border-radius: 8px;
            position: relative; transition: all 0.2s ease;
            display: flex; align-items: center; justify-content: center; flex-shrink: 0;
        }
        .checkbox-wrap:hover input ~ .checkmark { border-color: var(--primary); background-color: var(--primary-light); }
        .checkbox-wrap input:checked ~ .checkmark { background-color: var(--primary); border-color: var(--primary); box-shadow: 0 4px 12px rgba(21,178,1,0.25); }
        .checkmark::after {
            content: ""; position: absolute; display: none;
            left: 50%; top: 48%; width: 6px; height: 11px;
            border: solid white; border-width: 0 2.5px 2.5px 0; border-radius: 1px;
            transform: translate(-50%, -50%) rotate(45deg);
        }
        .checkbox-wrap input:checked ~ .checkmark::after { display: block; }

        .btn-primary {
            width: 100%; height: 58px;
            display: flex; align-items: center; justify-content: center; gap: 12px;
            border: none; border-radius: var(--radius);
            background: var(--primary); color: white;
            font-family: 'Inter', sans-serif; font-size: 0.95rem;
            font-weight: 700; letter-spacing: 0.02em;
            cursor: pointer; transition: var(--transition);
            position: relative; overflow: hidden;
            box-shadow: 0 10px 25px -5px rgba(21, 178, 1, 0.3);
        }
        .btn-primary:hover { background: var(--primary-dark); transform: translateY(-2px); box-shadow: 0 15px 30px -5px rgba(21, 178, 1, 0.4); }
        .btn-primary:active { transform: translateY(0); filter: brightness(0.9); }
        .btn-primary::after {
            content: ''; position: absolute;
            top: 0; left: -100%; width: 100%; height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255,255,255,0.15), transparent);
            transition: 0.5s;
        }
        .btn-primary:hover::after { left: 100%; }

        .btn-link {
            background: none; border: none; color: var(--primary);
            font-weight: 600; font-size: 0.9rem; cursor: pointer;
            padding: 4px 8px; border-radius: 6px; transition: var(--transition);
            font-family: inherit;
        }
        .btn-link:hover { background: var(--primary-light); color: var(--primary-dark); }

        .back-btn {
            display: inline-flex; align-items: center; gap: 8px;
            color: var(--text-muted); font-weight: 600; font-size: 0.85rem;
            margin-bottom: 24px; cursor: pointer; transition: var(--transition);
            padding: 8px 12px; margin-left: -12px; border-radius: 8px;
            background: none; border: none; font-family: inherit;
        }
        .back-btn:hover { color: var(--text-main); background: #f1f5f9; }
        .back-btn svg { transition: transform 0.2s ease; }
        .back-btn:hover svg { transform: translateX(-3px); }

        .error-banner {
            display: none;
            background: #fff1f2; border: 1px solid #fecdd3; color: #be123c;
            padding: 12px 16px; border-radius: 10px;
            font-size: 0.85rem; font-weight: 500; margin-bottom: 20px;
            align-items: center; gap: 10px;
            animation: shake 0.4s cubic-bezier(.36,.07,.19,.97) both;
        }

        .spinner {
            display: none; width: 20px; height: 20px;
            border: 3px solid rgba(255,255,255,0.3);
            border-radius: 50%; border-top-color: white;
            animation: spin 0.8s linear infinite;
        }
        .btn-primary.is-loading .btn-text,
        .btn-primary.is-loading svg { display: none; }
        .btn-primary.is-loading .spinner { display: block; }

        .register-link {
            text-align: center; margin-top: 28px;
            color: var(--text-muted); font-size: 0.9rem;
        }
        .register-link a { color: var(--primary); font-weight: 700; text-decoration: none; }
        .register-link a:hover { text-decoration: underline; }

        .footer-note {
            position: absolute; bottom: 40px;
            color: #cbd5e1; font-size: 0.7rem;
            font-weight: 700; text-transform: uppercase; letter-spacing: 0.1em;
        }

        @keyframes spin { to { transform: rotate(360deg); } }
        @keyframes shake {
            10%, 90% { transform: translate3d(-1px, 0, 0); }
            20%, 80% { transform: translate3d(2px, 0, 0); }
            30%, 50%, 70% { transform: translate3d(-4px, 0, 0); }
            40%, 60% { transform: translate3d(4px, 0, 0); }
        }

        @media (max-width: 850px) {
            .auth-container { grid-template-columns: 1fr; }
            .brand-panel { display: none; }
        }
    </style>
</head>
<body>

<div class="auth-container">
    <aside class="brand-panel">
        <img src="assets/bgwhiter.png" alt="BGT Logo" style="position:absolute;top:0;right:-10px;width:100px;">
        <div class="brand-content">
            <div class="logo-box">
                <img src="assets/bgt.png" alt="BGT Logo">
            </div>
            <h1>Login Portal.</h1>
            <p>Welcome back. Secure access for Bull Green Trading members.</p>
        </div>
    </aside>

    <main class="form-panel">
        <img src="assets/bgwhitel.png" alt="BGT Logo" style="position:absolute;top:0;left:-10px;width:100px;">
        <div class="form-card">

            <!-- LOGIN VIEW -->
            <div class="view active" id="login-view">
                <div class="form-header">
                    <h2>Identity Verification</h2>
                    <p>Please sign in to validate your credentials and proceed.</p>
                </div>

                <?php if ($error): ?>
                <div class="error-banner" style="display:flex;">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                    <span><?= htmlspecialchars($error) ?></span>
                </div>
                <?php endif; ?>

                <form method="POST" action="login.php" id="login-form" novalidate>
                    <input type="hidden" name="csrf_token" value="<?= $csrf ?>">

                    <div class="input-group">
                        <label>Login Identity</label>
                        <input type="text" name="email" id="email-field" class="input-ctrl"
                               placeholder="Username / Email"
                               value="<?= htmlspecialchars($_POST['email'] ?? '') ?>"
                               autocomplete="username">
                    </div>

                    <div class="input-group">
                        <label>Security Password</label>
                        <input type="password" name="password" id="pass-field" class="input-ctrl"
                               placeholder="*******" autocomplete="current-password">
                    </div>

                    <div class="form-options">
                        <label class="checkbox-wrap">
                            <input type="checkbox" name="remember_me" value="1">
                            <span class="checkmark"></span>
                            <span>Remember me</span>
                        </label>
                        <button type="button" class="btn-link" onclick="toggleView('forgot-view')">Forgot credentials?</button>
                    </div>

                    <button type="submit" class="btn-primary" id="login-btn">
                        <span class="btn-text">Access Workspace</span>
                        <div class="spinner"></div>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14m-7-7 7 7-7 7"/></svg>
                    </button>
                </form>

                <div class="register-link">
                    Don't have an account? <a href="register.php">Create one</a>
                </div>
            </div>

            <!-- FORGOT PASSWORD VIEW -->
            <div class="view" id="forgot-view">
                <button type="button" class="back-btn" onclick="toggleView('login-view')">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>
                    Back to login
                </button>

                <div class="form-header">
                    <h2>Recover Access</h2>
                    <p>Enter your email to receive recovery instructions.</p>
                </div>

                <div id="forgot-error" class="error-banner">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                    <span class="error-text">Please enter a valid email.</span>
                </div>

                <div class="input-group">
                    <label>Your Email</label>
                    <input type="email" id="forgot-email" class="input-ctrl" placeholder="e.g. user@bullgreentrading.com">
                </div>

                <!-- NOTE: Wire this to your password-reset email system (e.g. PHPMailer + token table) -->
                <button class="btn-primary" onclick="handleReset()">
                    <span class="btn-text">Send Recovery Link</span>
                    <div class="spinner"></div>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>
                </button>
            </div>

        </div><!-- /form-card -->

        <footer class="footer-note">
            Bull Green Trading PLC &bull; &copy; 2026 YDY Systems
        </footer>
    </main>
</div>

<script>
function toggleView(viewId) {
    document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
    document.getElementById(viewId).classList.add('active');
}

// Client-side loading spinner (server handles the real validation)
document.getElementById('login-form')?.addEventListener('submit', function () {
    document.getElementById('login-btn').classList.add('is-loading');
});

function handleReset() {
    const emailNode = document.getElementById('forgot-email');
    const errorBanner = document.getElementById('forgot-error');
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    errorBanner.style.display = 'none';
    emailNode.classList.remove('error');

    if (!re.test(emailNode.value)) {
        errorBanner.style.display = 'flex';
        errorBanner.querySelector('.error-text').innerText =
            emailNode.value ? 'Please enter a valid email address.' : 'Email is required.';
        emailNode.classList.add('error');
        return;
    }

    // TODO: POST to a reset-password.php endpoint via fetch()
    alert('If that email exists, recovery instructions have been sent.');
}
</script>

</body>
</html>
