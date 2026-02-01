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

module.exports = environment
