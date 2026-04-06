<?php 
declare(strict_types=1);
require_once __DIR__ . '/../config.php';

// Remove remember-me token from DB if it exists
if (!empty($_COOKIE['remember_token'])) {
    $pdo = get_pdo();
    $pdo->prepare('DELETE FROM remember_tokens WHERE token_hash = :hash')
        ->execute([':hash' => hash('sha256', $_COOKIE['remember_token'])]);

    // Expire the cookie immediately
    setcookie('remember_token', '', [
        'expires'  => time() - 3600,
        'path'     => '/',
        'secure'   => true,
        'httponly' => true,
        'samesite' => 'Strict',
    ]);
}

// Destroy session data
$_SESSION = [];

// Expire the session cookie
if (ini_get('session.use_cookies')) {
    $params = session_get_cookie_params();
    setcookie(
        session_name(), '', time() - 42000,
        $params['path'], $params['domain'],
        $params['secure'], $params['httponly']
    );
}

session_destroy();

// Back to login
redirect('login.php');
