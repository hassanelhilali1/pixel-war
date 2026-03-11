module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.js'],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/**/__tests__/**',
  ],
  coverageThreshold: {
    // pool.js et migrate.js sont mockés → exclus de la couverture attendue
    'src/routes/': { lines: 95, functions: 95, branches: 90 },
  },
};
