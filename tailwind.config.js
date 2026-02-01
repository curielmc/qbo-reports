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
}

