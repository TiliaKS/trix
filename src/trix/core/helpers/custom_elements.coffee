Trix.registerElement = (tagName, definition = {}) ->
  tagName = tagName.toLowerCase()

  definition = rewriteLifecycleCallbacks(definition)
  properties = rewriteFunctionsAsValues(definition)

  if defaultCSS = properties.defaultCSS
    delete properties.defaultCSS
    installDefaultCSSForTagName(defaultCSS, tagName)

  registerElement(tagName, properties)

installDefaultCSSForTagName = (defaultCSS, tagName) ->
  styleElement = insertStyleElementForTagName(tagName)
  styleElement.textContent = defaultCSS.replace(/%t/g, tagName)

insertStyleElementForTagName = (tagName) ->
  element = document.createElement("style")
  element.setAttribute("type", "text/css")
  element.setAttribute("data-tag-name", tagName.toLowerCase())
  document.head.insertBefore(element, document.head.firstChild)
  element

rewriteFunctionsAsValues = (definition) ->
  object = {}
  for key, value of definition
    object[key] = if typeof value is "function" then {value, writable: true} else value
  object

rewriteLifecycleCallbacks = do ->
  extract = (definition) ->
    callbacks = {}
    for key in ["initialize", "connect", "disconnect"]
      callbacks[key] = definition[key]
      delete definition[key]
    callbacks

  if window.customElements
    (definition) ->
      {initialize, connect, disconnect} = extract(definition)

      # Call `initialize` once in `connectedCallback` if defined
      if initialize or connect
        original = connect
        connect = ->
          @initialize?()
          @initialize = null
          original?.call(this)

      definition.initialize = initialize if initialize
      definition.connectedCallback = connect if connect
      definition.disconnectedCallback = disconnect if disconnect
      definition
  else
    (definition) ->
      {initialize, connect, disconnect} = extract(definition)
      definition.createdCallback = initialize if initialize
      definition.attachedCallback = connect if connect
      definition.detachedCallback = disconnect if disconnect
      definition

registerElement = do ->
  if window.customElements
    (tagName, properties) ->
      constructor = -> Reflect.construct(HTMLElement, [], constructor)
      constructor.prototype = Object.create(HTMLElement.prototype, properties)
      window.customElements.define(tagName, constructor)
      constructor
  else
    (tagName, properties) ->
      prototype = Object.create(HTMLElement.prototype, properties)
      constructor = document.registerElement(tagName, prototype: prototype)
      Object.defineProperty(prototype, "constructor", value: constructor)
      constructor
