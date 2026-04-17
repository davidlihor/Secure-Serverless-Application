import { Outlet } from 'react-router-dom';

export function AuthLayout() {
  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '1rem',
      position: 'relative',
      zIndex: 1
    }}>
      <div style={{ width: '100%', maxWidth: '480px' }}>
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <h1 style={{
            fontSize: '3rem',
            fontWeight: 700,
            fontFamily: "'Outfit', sans-serif",
            background: 'linear-gradient(135deg, var(--accent-primary) 0%, var(--accent-secondary) 50%, var(--accent-tertiary) 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
            letterSpacing: '-0.02em'
          }}>CloudStack</h1>
          <p style={{
            color: 'var(--text-secondary)',
            marginTop: '0.5rem',
            fontSize: '1.25rem'
          }}>Task Management App</p>
        </div>
        <Outlet />
      </div>
    </div>
  );
}
