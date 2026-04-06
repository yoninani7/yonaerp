<?php
/**
 * config.php — Database connection & global security settings
 * Include this file at the top of every PHP page that needs DB access.
 */

declare(strict_types=1);

// ── Environment ──────────────────────────────────────────────────────────────
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_NAME', 'ydy_hrm');   // ← change
define('DB_USER', 'root');         // ← change
define('DB_PASS', '');     // ← change
define('DB_CHARSET', 'utf8mb4');

// Redirect users here after a successful login
define('LOGIN_REDIRECT', 'index.html');

// How long (seconds) a "remember me" session cookie lasts (30 days)
define('REMEMBER_ME_TTL', 60 * 60 * 24 * 30);

// Max failed login attempts before locking the account
define('MAX_LOGIN_ATTEMPTS', 5);

// Lockout duration in seconds (15 minutes)
define('LOCKOUT_SECONDS', 900);

// ── Session hardening ─────────────────────────────────────────────────────────
if (session_status() === PHP_SESSION_NONE) {
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        // 'secure'   => true,          // HTTPS only — set to false on local dev
        'httponly' => true,          // JS cannot read the cookie
        'samesite' => 'Strict',
    ]);
    session_start();
}

// ── PDO singleton ─────────────────────────────────────────────────────────────
function get_pdo(): PDO
{
    static $pdo = null;

    if ($pdo === null) {
        $dsn = sprintf(
            'mysql:host=%s;port=%s;dbname=%s;charset=%s',
            DB_HOST, DB_PORT, DB_NAME, DB_CHARSET
        );
        $options = [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,   // real prepared statements
        ];

        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
        } catch (PDOException $e) {
            // Never expose DB errors to the browser
            error_log('DB connection failed: ' . $e->getMessage());
            http_response_code(500);
            exit('A server error occurred. Please try again later.');
        }
    }

    return $pdo;
}

// ── CSRF helpers ──────────────────────────────────────────────────────────────

/**
 * Generate (or retrieve existing) CSRF token for the current session.
 */
function csrf_token(): string
{
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

/**
 * Validate the CSRF token submitted with a form.
 * Exits with 403 on mismatch — safe to call from any POST handler.
 */
function csrf_verify(): void
{
    $submitted = $_POST['csrf_token'] ?? '';
    if (!hash_equals(csrf_token(), $submitted)) {
        http_response_code(403);
        exit('Invalid CSRF token.');
    }
}

// ── Utility ───────────────────────────────────────────────────────────────────

/**
 * Safely redirect and terminate execution.
 */
function redirect(string $url): never
{
    header('Location: ' . $url);
    exit;
}

/**
 * Return a sanitised string (removes leading/trailing whitespace + HTML entities).
 */
function clean(string $value): string
{
    return htmlspecialchars(trim($value), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
