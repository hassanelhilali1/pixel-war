import { useState, useEffect, useCallback, useRef } from 'react';
import { io } from 'socket.io-client';
import Grid from './components/Grid.jsx';
import ColorPicker from './components/ColorPicker.jsx';

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || '';
const GRID_SIZE   = parseInt(import.meta.env.VITE_GRID_SIZE || '50', 10);

// cree une grille vide (tout en blanc)
function emptyGrid() {
  const g = {};
  for (let y = 0; y < GRID_SIZE; y++)
    for (let x = 0; x < GRID_SIZE; x++)
      g[`${x},${y}`] = '#FFFFFF';
  return g;
}

export default function App() {
  const [grid,          setGrid]          = useState(emptyGrid);
  const [selectedColor, setSelectedColor] = useState('#FF0000');
  const [connected,     setConnected]     = useState(false);
  const [placing,       setPlacing]       = useState(false);
  const socketRef = useRef(null);

  // charge la grille depuis l'API au demarrage
  useEffect(() => {
    fetch(`${BACKEND_URL}/api/grid`)
      .then((r) => r.json())
      .then((pixels) => {
        setGrid((prev) => {
          const next = { ...prev };
          pixels.forEach(({ x, y, color }) => { next[`${x},${y}`] = color; });
          return next;
        });
      })
      .catch(console.error);
  }, []);

  // connexion websocket pour les mises a jour en temps reel
  useEffect(() => {
    const socket = io(BACKEND_URL || window.location.origin, {
      transports: ['websocket', 'polling'],
    });
    socketRef.current = socket;

    socket.on('connect',    () => setConnected(true));
    socket.on('disconnect', () => setConnected(false));

    // quand un autre joueur pose un pixel
    socket.on('pixel:update', ({ x, y, color }) => {
      setGrid((prev) => ({ ...prev, [`${x},${y}`]: color }));
    });

    return () => socket.disconnect();
  }, []);

  // quand on clique sur un pixel de la grille
  const handlePixelClick = useCallback(
    async (x, y) => {
      if (placing) return;
      setPlacing(true);
      try {
        const res = await fetch(`${BACKEND_URL}/api/pixel`, {
          method:  'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body:    JSON.stringify({ x, y, color: selectedColor }),
        });
        if (!res.ok) console.error('Pixel update failed:', await res.text());
      } catch (err) {
        console.error('Network error:', err);
      } finally {
        setPlacing(false);
      }
    },
    [selectedColor, placing]
  );

  return (
    <div className="app">
      <header className="app-header">
        <h1> Pixel War 2026</h1>
        <div className="header-right">
          <span className={`badge ${connected ? 'badge-ok' : 'badge-err'}`}>
            {connected ? ' Connecté' : ' Déconnecté'}
          </span>
          <span className="grid-info">Grille {GRID_SIZE}×{GRID_SIZE}</span>
        </div>
      </header>

      <ColorPicker color={selectedColor} onChange={setSelectedColor} />

      <Grid
        grid={grid}
        gridSize={GRID_SIZE}
        onPixelClick={handlePixelClick}
        disabled={placing}
      />

      <footer className="app-footer">
        ISIMA Pixel War 2026 — DevOps Cloud-Native
      </footer>
    </div>
  );
}
