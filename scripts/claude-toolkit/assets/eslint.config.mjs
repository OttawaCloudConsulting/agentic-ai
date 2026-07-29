// eslint.config.mjs — baseline flat config for consumer repos.
//
// Only needed when the consumer's pre-commit runs `npx eslint` on staged JS/TS.
// A repo with no prior JS and no eslint config errors ("couldn't find
// eslint.config.*") the moment the toolkit's hooks/*.js are added. This provides
// the required config with Node globals so tooling scripts lint cleanly. No
// rules are enforced yet — add them when the repo grows real application JS/TS.
// Copy manually to the consumer repo root; the installer does not install this
// (it would clobber an existing eslint setup).
export default [
  // CommonJS tooling scripts (hooks/*.js use require/module).
  {
    files: ['**/*.{js,cjs}'],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: 'commonjs',
      globals: {
        process: 'readonly',
        require: 'readonly',
        module: 'writable',
        __dirname: 'readonly',
        console: 'readonly',
      },
    },
  },
  // ESM files (.mjs, e.g. this config) — parse import/export correctly.
  {
    files: ['**/*.mjs'],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: 'module',
      globals: {
        process: 'readonly',
        console: 'readonly',
      },
    },
  },
];
