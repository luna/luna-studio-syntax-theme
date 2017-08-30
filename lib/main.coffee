fs   = require 'fs'
path = require 'path'
packageName = require('../package.json').name


id = (a) => a

mimicDevMode = (f) =>
  atom.devMode = true
  out = f()
  atom.devMode = false
  return out

# TODO: We could use such trick to hide unnecesary settings (like custom color unless "custom" option is chosen).
#       We cannot use it unless we patch SettingsView to include name of the package in CSS class.
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

  #updateBgColor: () -> @updateCustomizableCfg 'background', ((val) -> 'rgb(' + val.red + ',' + val.green + ',' + val.blue + ')'), ((val) -> 'hsl(30, 4%, ' + val + '%)')
   updateBgColor: () ->
     val    = atom.config.get(packageName + '.backgroundColor')
     cval   = atom.config.get(packageName + '.customBackgroundColor')
     genVal = null
     if val == 'custom'
       genVal = 'rgb(' + cval.red + ',' + cval.green + ',' + cval.blue + ')'
     else
       genVal = 'hsl(30, 4%, ' + val + '%)'
     if @configCache.backgroundColor != genVal
       @configCache.backgroundColor = genVal
       @refreshTheme()

  updateContrast: () ->
    val    = atom.config.get(packageName + '.contrast')
    cval   = atom.config.get(packageName + '.customContrast')
    genVal = null
    if val == 'custom'
      genVal = cval.toString()
    else
      genVal = val
    if @configCache.contrast != genVal
      @configCache.contrast = genVal
      @refreshTheme()

  updateCustomizableCfg: (name, cf, cn) ->
    bigName = name.charAt(0).toUpperCase() + name.slice(1)
    val     = atom.config.get(packageName + '.' + name)
    cval    = atom.config.get(packageName + '.custom' + bigName)
    genVal  = null
    if val == 'custom'
      genVal = cf cval.toString()
    else
      genVal = cn val
    console.log bigName
    console.log val
    console.log cval
    console.log genVal
    # if @configCache[name] != genVal
    #   @configCache[name] = genVal
    #   @refreshTheme()

  activate: (state) ->
    @configCache = {}

    atom.config.observe (packageName + '.backgroundColor')       , @updateBgColor.bind @
    atom.config.observe (packageName + '.customBackgroundColor') , @updateBgColor.bind @

    # atom.packages.activatePackage('dev-live-reload').then (devLiveReloadPkg) =>
    @enableReloader()


  config:
    backgroundColor:
      order   : 1
      description: 'WARNING: Changing this option could take several seconds, depending on how powerful the machine you are currently running is. It is an exported variable and could be used by any other package, so all already loaded styles have to be reloaded.'
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

    contrast:
      description: 'Contrast of theme elements. Increasing this value would make the theme more readable in bright environment, but will also make your eyes hurt more in darker environment.'
      order   : 3
      type    : 'string'
      default : 'auto'
      enum    : [
        {value: 'auto'   , description: 'Automatic, depending on the theme\'s lightness'}
        {value: '0.7'    , description: 'Very Slight'}
        {value: '0.9'    , description: 'Slight'}
        {value: '1.0'    , description: 'Normal'}
        {value: '1.3'    , description: 'Strong'}
        {value: '2.0'    , description: 'Very Strong'}
        {value: 'custom' , description: 'Custom'}
      ]
    customContrast:
      order   : 4
      type    : 'number'
      default : 1.0
