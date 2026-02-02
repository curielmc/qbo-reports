const { environment } = require('@rails/webpacker')
const { VueLoaderPlugin } = require('vue-loader')

environment.plugins.prepend('VueLoaderPlugin', new VueLoaderPlugin())
environment.loaders.prepend('vue', {
  test: /\.vue$/,
  use: [{ loader: 'vue-loader' }]
})

// Fix postcss-loader v4 options format (Webpacker 5 passes old `config` key)
environment.loaders.keys().forEach((key) => {
  const loader = environment.loaders.get(key)
  if (!loader || !loader.use) return
  loader.use.forEach((rule) => {
    if (rule.loader && rule.loader.includes('postcss-loader') && rule.options && rule.options.config) {
      rule.options = {
        postcssOptions: {
          config: rule.options.config.path
        }
      }
    }
  })
})

// Fix: Webpack 4 can't handle named exports from .mjs ES modules (vue-router, etc.)
environment.loaders.prepend('mjs', {
  test: /\.mjs$/,
  include: /node_modules/,
  type: 'javascript/auto'
})

// Force Vue to use ESM build so vue-router can import named exports
environment.config.resolve.alias = {
  ...environment.config.resolve.alias,
  'vue': 'vue/dist/vue.esm-bundler.js'
}

module.exports = environment
