import { useState, useEffect } from 'react';
import { Outlet } from 'react-router-dom';
import { AuthService } from '../services/auth';

export function Layout() {
  const [userEmail, setUserEmail] = useState<string>('');
  const userId = AuthService.getCurrentUserId();

  useEffect(() => {
    AuthService.getCurrentUserEmailAsync().then(setUserEmail);
  }, []);

  const handleLogout = () => {
    AuthService.signOut();
    window.location.href = '/login';
  };

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: 'var(--bg-dark)',
      color: 'var(--text-primary)'
    }}>
      <header style={{
        background: 'var(--bg-card)',
        backdropFilter: 'var(--glass-blur)',
        borderBottom: '1px solid var(--glass-border)',
        padding: '1rem 2rem'
      }}>
        <div style={{
          maxWidth: '800px',
          margin: '0 auto',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center'
        }}>
          <h1 style={{ 
            fontSize: '1.5rem', 
            fontWeight: 700,
            background: 'linear-gradient(135deg, var(--accent-primary) 0%, var(--accent-secondary) 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent'
          }}>CloudStack Tasks</h1>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <div style={{ textAlign: 'right' }}>
              <div style={{ color: 'var(--text-primary)', fontSize: '0.95rem' }}>{userEmail}</div>
              <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>{userId}</div>
            </div>
            <button
              onClick={handleLogout}
              style={{
                padding: '0.5rem 1rem',
                background: 'transparent',
                border: '1px solid var(--danger-color)',
                borderRadius: '8px',
                color: 'var(--danger-color)',
                cursor: 'pointer',
                fontWeight: 600
              }}
            >
              Logout
            </button>
          </div>
        </div>
      </header>

      <main style={{
        maxWidth: '800px',
        margin: '2rem auto',
        padding: '0 1rem'
      }}>
        <Outlet />
      </main>
    </div>
  );
}
