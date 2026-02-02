const { environment } = require('@rails/webpacker')
const { VueLoaderPlugin } = require('vue-loader')

environment.plugins.prepend('VueLoaderPlugin', new VueLoaderPlugin())
environment.loaders.prepend('vue', {
  test: /\.vue$/,
  use: [{ loader: 'vue-loader' }]
})

// Override ALL postcss-loader instances: inject plugins inline, bypass config file entirely
// This prevents Webpacker's bundled postcss-preset-env (which crashes with Tailwind 3)
environment.loaders.keys().forEach((key) => {
  const loader = environment.loaders.get(key)
  if (!loader || !loader.use) return
  loader.use.forEach((rule) => {
    if (rule.loader && rule.loader.includes('postcss-loader')) {
      rule.options = {
        postcssOptions: {
          plugins: [
            require('tailwindcss'),
            require('autoprefixer')
          ]
        }
      }
    }
  })
})

// Fix: Webpack 4 can't handle .mjs ES modules — treat as JS and run through babel
environment.loaders.prepend('mjs', {
  test: /\.mjs$/,
  include: /node_modules/,
  type: 'javascript/auto',
  use: [{
    loader: 'babel-loader',
    options: {
      presets: [['@babel/preset-env', { targets: { esmodules: true }, modules: false }]],
      plugins: [
        '@babel/plugin-transform-optional-chaining',
        '@babel/plugin-transform-nullish-coalescing-operator'
      ]
    }
  }]
})

// Force Vue and related packages to use ESM builds for Webpack 4 compatibility
environment.config.resolve.alias = {
  ...environment.config.resolve.alias,
  'vue': 'vue/dist/vue.esm-bundler.js',
  'vue-router': require.resolve('vue-router/dist/vue-router.esm-bundler.js'),
  'pinia': require.resolve('pinia/dist/pinia.esm-browser.js')
}

module.exports = environment
