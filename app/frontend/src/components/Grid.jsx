import { memo, useCallback } from 'react';

const CELL_SIZE = 12; // px

/**
 * Grille de pixels.
 * Optimisée avec React.memo pour éviter les re-renders inutiles.
 */
const Grid = memo(function Grid({ grid, gridSize, onPixelClick, disabled }) {
  const handleClick = useCallback(
    (e) => {
      if (disabled) return;
      const cell = e.target.closest('[data-x]');
      if (!cell) return;
      onPixelClick(parseInt(cell.dataset.x, 10), parseInt(cell.dataset.y, 10));
    },
    [onPixelClick, disabled]
  );

  return (
    <div className="grid-wrapper">
      <div
        className="grid-canvas"
        style={{
          gridTemplateColumns: `repeat(${gridSize}, ${CELL_SIZE}px)`,
          gridTemplateRows:    `repeat(${gridSize}, ${CELL_SIZE}px)`,
          width:  gridSize * CELL_SIZE,
          height: gridSize * CELL_SIZE,
          opacity: disabled ? 0.7 : 1,
        }}
        onClick={handleClick}
        role="grid"
        aria-label={`Grille Pixel War ${gridSize}×${gridSize}`}
      >
        {Array.from({ length: gridSize * gridSize }, (_, i) => {
          const x = i % gridSize;
          const y = Math.floor(i / gridSize);
          const color = grid[`${x},${y}`] || '#FFFFFF';
          return (
            <div
              key={i}
              className="pixel"
              data-x={x}
              data-y={y}
              style={{ width: CELL_SIZE, height: CELL_SIZE, backgroundColor: color }}
              role="gridcell"
              aria-label={`Pixel (${x},${y}) — ${color}`}
            />
          );
        })}
      </div>
    </div>
  );
});

export default Grid;
