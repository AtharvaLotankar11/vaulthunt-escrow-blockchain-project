import nextCoreWebVitals from "eslint-config-next/core-web-vitals";

const eslintConfig = [
  ...nextCoreWebVitals,
  {
    // generated files and build output are not linted
    ignores: [".next/**", "node_modules/**", "src/contracts/**", "next-env.d.ts"],
  },
];

export default eslintConfig;
