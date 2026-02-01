/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/javascript/**/*.{vue,js}',
  ],
  theme: {
    extend: {},
  },
  plugins: [require('daisyui')],
  daisyui: {
    themes: [
      {
        ecfobooks: {
          "primary": "#336699",          // Steel blue — matches myecfo.com
          "primary-content": "#ffffff",
          "secondary": "#1d3853",        // Dark navy accent
          "secondary-content": "#ffffff",
          "accent": "#2f669a",           // Mid blue
          "accent-content": "#ffffff",
          "neutral": "#173552",          // Darkest navy
          "neutral-content": "#d4e8f7",
          "base-100": "#ffffff",         // White background
          "base-200": "#f0f4f8",         // Light blue-gray
          "base-300": "#d4e8f7",         // Lightest blue
          "base-content": "#1d3853",     // Dark navy text
          "info": "#4a7fb0",             // Info blue
          "info-content": "#ffffff",
          "success": "#279247",          // Green (from myecfo articles)
          "success-content": "#ffffff",
          "warning": "#d69e2e",          // Warm yellow
          "warning-content": "#1d3853",
          "error": "#c00000",            // Red (from myecfo articles)
          "error-content": "#ffffff",
        },
      },
    ],
  },
}
