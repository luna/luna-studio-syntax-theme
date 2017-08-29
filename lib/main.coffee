fs   = require 'fs'
path = require 'path'


mimicDevMode = (f) =>
  atom.devMode = true
  out = f()
  atom.devMode = false
  return out

# TODO: We cannot use it unless we patch SettingsView to include name of the package in CSS class.
#       Then we would be able to hide unnecessary options.
# createGlobalStylesheet = () ->
#   head       = document.head
#   style      = document.createElement 'style'
#   style.type = 'text/css'
#   node       = document.createTextNode ''
#   style.appendChild node
#   head.appendChild  style
#   node

module.exports =

  isReloaderEnabled: ->
    return @reloader?

  enableReloader: ->
    atom.packages.disablePackage("dev-live-reload")
    try
      atom.packages.unloadPackage("dev-live-reload")
    catch error
      # WARNING: It works this way and somehow does not when doing `if atom.packages.isPackageActive("dev-live-reload") ...`
      #          instead of try-catch block. Probably it still unregisters something now.
    return mimicDevMode () =>
      @reloader = atom.packages.loadPackage("dev-live-reload").mainModule
      @reloader.activate()
      return @reloader

  reloadAllStyles: ->
    atom.commands.dispatch(document.querySelector("atom-workspace"), "dev-live-reload:reload-all")


  getConfigVariablesPath: ->
    basePath = path.join __dirname, '..', 'styles', 'generated'
    if not fs.existsSync basePath
      fs.mkdir basePath
    path.join basePath, "globals.less"

  getConfigVariablesContent: () ->
    """
    @cfg-bg-color: #{@configCache.backgroundColor};
    """

  refreshTheme: () ->
    fs.writeFileSync @getConfigVariablesPath(), @getConfigVariablesContent()
    # We have to manualy invoke `reloadAllStyles`, because auto reload not always sees the change (!)
    # If everything is up to date or just reloaded it has a very small time overhead
    @reloadAllStyles()

  activate: (state) ->
    @packageName = require('../package.json').name

    @configCache = {}

    atom.config.observe (@packageName + '.backgroundColor'), (value) =>
      color = null
      if value == 'custom'
        cc    = atom.config.settings[@packageName].customBackgroundColor
        color = 'rgb(' + cc.red + ',' + cc.green + ',' + cc.blue + ')'
      else
        color = 'hsl(30, 4%, ' + value + '%)'
      if @configCache.backgroundColor != color
        @configCache.backgroundColor = color
        @refreshTheme()

    # atom.packages.activatePackage('dev-live-reload').then (devLiveReloadPkg) =>
    @enableReloader()


  config:
    backgroundColor:
      description: 'Changing background color could take several seconds, depending on how powerful machine you are currently running is. It is an exported variable and could be used by any other package and theme, so all styles need to be reloaded.'
      order   : 1
      type    : 'string'
      default : '7'
      enum    : [
        {value: '7'     , description: 'Very Dark'}
        {value: '10'    , description: 'Dark'}
        {value: '15'    , description: 'Dark Gray'}
        {value: '20'    , description: 'Gray (work in progress)'}
        {value: '25'    , description: 'Light Gray (work in progress)'}
        {value: '70'    , description: 'Light (work in progress)'}
        {value: '90'    , description: 'Very Light (work in progress)'}
        {value: 'custom', description: 'Custom'}
      ]
    customBackgroundColor:
      order   : 2
      type    : 'color'
      default : 'black'
