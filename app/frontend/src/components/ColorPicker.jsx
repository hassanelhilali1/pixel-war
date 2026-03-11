// palette de couleurs disponibles
const PRESET_COLORS = [
  '#000000', '#FFFFFF', '#808080', '#C0C0C0',
  '#FF0000', '#800000', '#FF6600', '#FF8C00',
  '#FFFF00', '#808000', '#00FF00', '#008000',
  '#00FFFF', '#008080', '#0000FF', '#000080',
  '#FF00FF', '#800080', '#FF69B4', '#A52A2A',
];

// selecteur de couleur avec palette + couleur custom
export default function ColorPicker({ color, onChange }) {
  return (
    <div className="color-picker">
      <div className="preset-colors">
        {PRESET_COLORS.map((c) => (
          <button
            key={c}
            className={`color-swatch${c === color ? ' selected' : ''}`}
            style={{ backgroundColor: c }}
            onClick={() => onChange(c)}
            title={c}
            aria-label={`Couleur ${c}`}
          />
        ))}
      </div>

      <label className="custom-color" title="Couleur personnalisée">
        Custom :
        <input
          type="color"
          value={color}
          onChange={(e) => onChange(e.target.value)}
          aria-label="Choisir une couleur personnalisée"
        />
      </label>

      <span
        className="current-color"
        style={{ backgroundColor: color }}
        title="Couleur sélectionnée"
      >
        {color.toUpperCase()}
      </span>
    </div>
  );
}
