fs   = require 'fs'
path = require 'path'
packageName = require('../package.json').name


id = (a) => a

mimicDevMode = (f) =>
  atom.devMode = true
  out = f()
  atom.devMode = false
  return out

`
function HSVtoRGB(h, s, v) {
    var r, g, b, i, f, p, q, t;
    if (arguments.length === 1) {
        s = h.s, v = h.v, h = h.h;
    }
    i = Math.floor(h * 6);
    f = h * 6 - i;
    p = v * (1 - s);
    q = v * (1 - f * s);
    t = v * (1 - (1 - f) * s);
    switch (i % 6) {
        case 0: r = v, g = t, b = p; break;
        case 1: r = q, g = v, b = p; break;
        case 2: r = p, g = v, b = t; break;
        case 3: r = p, g = q, b = v; break;
        case 4: r = t, g = p, b = v; break;
        case 5: r = v, g = p, b = q; break;
    }
    return {
        red:   Math.round(r * 255),
        green: Math.round(g * 255),
        blue:  Math.round(b * 255)
    };
}
`

HSVtoRGBstr = (h,s,v) -> rgbToStr (HSVtoRGB h,s,v)

rgbToStr = (c) -> "rgb(" + c.red + "," + c.green + "," + c.blue + ")"

jsToCssVar = (name) -> name.replace /([A-Z])/g, (g) -> "-" + g[0].toLowerCase()

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

getConfig    = (sel) -> atom.config.get('luna-syntax.' + sel)
getAllConfig = (sel) -> atom.config.getAll('luna-syntax.' + sel)[0].value

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
    code = """
    @cfg-bg-color: #{@configCache['background.color']};
    @cfg-contrast: #{@configCache['accessibility.contrast']};
    """
    synColors = getAllConfig 'syntax'
    for name, color of synColors
      if name.endsWith 'Color'
        code += "\n@cfg-#{jsToCssVar name}: #{rgbToStr color};"

    code += "\n@cfg-adaptive-colors: #{getConfig('syntax.adaptiveColors')};"
    code
    # @cfg-contrast: #{@configCache['accessibility.contrast']};

  refreshTheme: () ->
    fs.writeFileSync @getConfigVariablesPath(), @getConfigVariablesContent()
    # We have to manualy invoke `reloadAllStyles`, because auto reload not always sees the change (!)
    # If everything is up to date or just reloaded it has a very small time overhead
    @reloadAllStyles()

  updateBgColor: () -> @updateCustomizableCfg 'background.color',
    ((val) -> 'rgb(' + val.red + ',' + val.green + ',' + val.blue + ')'),
    ((val) -> 'hsl(30, 4%, ' + val + '%)')

  updateContrast: () -> @updateCustomizableCfg 'accessibility.contrast',
    ((val) -> val.toString()), ((val) -> if val == 'auto' then '"auto"' else val)


  updateCustomizableCfg: (scfgPath, cf, cn) ->
    cfgPath = scfgPath.split '.'
    name    = cfgPath.pop()
    tgt     = cfgPath.join '.'
    bigName = name.charAt(0).toUpperCase() + name.slice(1)
    val     = atom.config.get(packageName + '.' + tgt + '.' + name)
    cval    = atom.config.get(packageName + '.' + tgt + '.custom' + bigName)
    genVal  = null
    if val == 'custom'
      genVal = cf cval
    else
      genVal = cn val
    if @configCache[scfgPath] != genVal
      @configCache[scfgPath] = genVal
      @refreshTheme()

  activate: (state) ->
    @configCache = {}

    atom.config.observe (packageName + '.background.color')       , @updateBgColor.bind @
    atom.config.observe (packageName + '.background.customColor') , @updateBgColor.bind @

    atom.config.observe (packageName + '.accessibility.contrast')       , @updateContrast.bind @
    atom.config.observe (packageName + '.accessibility.customContrast') , @updateContrast.bind @

    atom.config.observe (packageName + '.syntax') , @refreshTheme.bind @

    # atom.packages.activatePackage('dev-live-reload').then (devLiveReloadPkg) =>
    @enableReloader()


  config:
    background:
      order : 1
      type  : 'object'
      properties:
        color:
          order   : 1
          description: 'WARNING: Changing this option could take several seconds, depending on how powerful the machine you are currently running is. It is an exported variable and could be used by any other package, so all already loaded styles have to be reloaded.'
          type    : 'string'
          default : '8.5'
          enum    : [
            {value: '7'     , description: 'Very Dark'}
            {value: '8.5'   , description: 'Dark'}
            {value: '10'    , description: 'Dark Gray'}
            {value: '15'    , description: 'Gray (work in progress)'}
            {value: '20'    , description: 'Light Gray (work in progress)'}
            {value: '70'    , description: 'Light (work in progress)'}
            {value: '90'    , description: 'Very Light (work in progress)'}
            {value: 'custom', description: 'Custom'}
          ]
        customColor:
          order   : 2
          type    : 'color'
          default : 'black'

    accessibility:
      order : 2
      type  : 'object'
      properties:
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

    syntax:
      order : 3
      type  : 'object'
      properties:
        adaptiveColors:
          order       : 1
          description : "Blend font color with editor's background accent color."
          type        : 'boolean'
          default     : true
        baseColor         : {order: 2, type:'color', default:HSVtoRGBstr 0   , 0   , 0.6 }
        operatorColor     : {order: 3, type:'color', default:HSVtoRGBstr 0   , 0   , 0.5 }
        secondaryColor    : {order: 4, type:'color', default:HSVtoRGBstr 0   , 0   , 0.3 }
        numberColor       : {order: 5, type:'color', default:HSVtoRGBstr 0.58, 0.3 , 0.62}
        stringColor       : {order: 6, type:'color', default:HSVtoRGBstr 0.09, 0.62, 0.6 }
        stringEscapeColor : {order: 7, type:'color', default:HSVtoRGBstr 0.09, 0.62, 0.4 }
        definitionColor   : {order: 8, type:'color', default:HSVtoRGBstr 0   , 0.55, 0.6 }
        constructorColor  : {order: 9, type:'color', default:HSVtoRGBstr 0   , 0.55, 0.6 }
        commentColor      : {order:10, type:'color', default:HSVtoRGBstr 0   , 0   , 0.3 }
        sequenceColor     : {order:11, type:'color', default:HSVtoRGBstr 0   , 0   , 0.5 }
