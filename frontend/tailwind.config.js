/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'sentinel-bg': '#0A0E1D',
        'sentinel-sidebar': '#10172A',
        'sentinel-card': '#151F35',
        'sentinel-elevated': '#1B2942',
        'sentinel-cyan': '#00D9D9',
        'sentinel-blue': '#477BFF',
        'sentinel-success': '#21C997',
        'sentinel-warning': '#F5B942',
        'sentinel-critical': '#FF5268',
        'sentinel-text': '#F4F7FF',
        'sentinel-muted': '#9AA9C4',
      },
      fontFamily: {
        sans: ['Inter', '-apple-system', 'BlinkMacSystemFont', 'sans-serif'],
        display: ['"Exo 2"', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'monospace'],
      },
      boxShadow: {
        'sentinel-glow': '0 0 20px rgba(0, 217, 217, 0.25)',
        'sentinel-critical-glow': '0 0 20px rgba(255, 82, 104, 0.35)',
        'sentinel-card': '0 8px 32px 0 rgba(0, 0, 0, 0.45)',
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
    },
  },
  plugins: [],
};
