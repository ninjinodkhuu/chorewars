module.exports = {
  env: {
    es6: true,
    node: true,
    jest: true,
  },
  extends: [
    'eslint:recommended',
    'google',
  ],
  rules: {
    'indent': ['error', 2],
    'object-curly-spacing': ['error', 'always'],
    'max-len': ['error', { 'code': 100 }],
    'require-jsdoc': 'off',
    'valid-jsdoc': 'off',
    'camelcase': 'off',
    'no-unused-vars': ['error', { 
      'argsIgnorePattern': '^_',
      'varsIgnorePattern': '^_',
    }],
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
}