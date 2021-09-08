module.exports = {
  env: {
    browser: true,
    node: true,
    es2021: true,
  },
  extends: "eslint:recommended",
  parserOptions: {
    ecmaVersion: 12,
    sourceType: "module",
  },
  rules: {
    indent: ["error", 4],
    "linebreak-style": "off",
    quotes: ["error", "double"],
    semi: ["error", "always"],
  },
  plugins: ["only-warn"],
};
