########################################################################
### d3-debug.coffee : a view into the depths of d3 data structures ###
########################################################################
#
# d3-debug helps you understand the complex internal state of d3 data structures (using the Chrome JavaScript console).
# This is especially useful for debugging issues with selections, groupings, and data binding (and for learning how all of these work in the first place)
#
# Read and run the "Working Example" below for more info.
#
# Dependencies: underscore.js (and of course d3.js)
#
# This extensively uses console features from https://developers.google.com/chrome-developer-tools/docs/console#styling_console_output_with_css (equivalent in ff: https://getfirebug.com/wiki/index.php/Console_API)
#
# TODO 
# - add option to log additional information for each selection, group, and element; e.g. "opts = {evalForElement: (elt) -> elt.className}".

### Initialize state ###

# The base namespace for d3 debug operations (though they are also added directly to selections)
d3.debug = {}

# Used to optionally save all inspected objects for further exploration, see below
olog = d3.debug.olog = []
olog.enabled = false

### Working Example ###
# To see the output, run "d3.debug.workingExample" in the console, or uncomment the line indicated below (ideally on a blank page). Explore the console output - there is a lot to see!

workingExample = d3.debug.workingExample = ->
  explain = (text) -> console.log("%c// #{text}", "color: #718c00; font-size: 14px")

  explain('Enable the object log (olog), using ".olog.enable()" which saves selections during inspections for later perusal.')
  d3.debug.olog.enable()

  explain('Simplest use of ".inspect()" on a selection. Use d3.debug.olog[0] to do additional inspection later.')
  chart = d3.select('body').append("div").classed('chart', true).style(padding: '30px').inspect()

  explain('Use ".inspect" within selection method chains (even as the selection is being created and bound to data). The optional argument shows up in the output in brackets for context.')
  rows = chart.selectAll("div.row")
    .inspect("after .selectAll")
    .data([4, 8, 15, 16, 23, 42])
    .inspect("after .data") 
    .enter()
    .inspect("after .enter")
    .append("div")
    .inspect("after .append")
    .classed("row", true)

  explain('Use ".debug()" instead of ".inspect()" to also halt execution and start the debugger after the selection inspection.')
  rows.debug("rows")

  explain('To see the selection state before and after a sequence of operations use: ".inspectWrap -> @"')
  bars = rows.inspectWrap -> @
    .append("div")
    .classed("bar", true)
    .text((d) -> d)
    .style
      width: (d) -> 5*d + 'px'
      font: '12px sans-serif'
      padding: '3px'
      margin: '1px'
      color: 'white'
      'background-color': 'steelblue'
      'text-align': 'right'

  explain('Optionally provide some textual context with: ".inspectWrap \'Context\', -> @".')
  bars.inspectWrap "animation", -> @      
    .call -> @ # .call returns the same selection it was given, which is important here as the output of transition is not a selection.
      .transition()
        .delay(500)
        .duration(1000)
        .style(width: (d) -> 10*d + 'px')

  explain('Access the object log (olog) with ".olog[0].inspect()"')
  d3.debug.olog[0].inspect()

  explain('Disable the object log with ".olog.disable()"')
  d3.debug.olog.disable()

## Uncomment to automatically run the example on page load
document.addEventListener 'DOMContentLoaded', workingExample

### Utility methods and helpers ###

stringIsNumber = (n) -> !isNaN(parseFloat(n)) && isFinite(n)

sum = (arr) -> arr.reduce(((x, y) -> x + y), 0)

numNull = (arr) -> sum(1 for o in arr when _.isNull(o))

numUndefined = (arr) -> sum(1 for o in arr when _.isUndefined(o))

elementMissing = (elt) ->
  if _.isNull(elt)
    "Null"
  else if _.isUndefined(elt)
    "Undefined"
  else if !_.isElement(elt)
    "Not a DOM element"
  else if !document.contains(elt)
    "Not attached to DOM"
  else
    false

# Returns all the keys for a object that are not array indices
nonIndexKeys = d3.debug.nonIndexKeys = (obj) ->
  _.filter(Object.keys(obj), (key) -> !stringIsNumber(key))

# Generates a simple "summary string" describing an object
summaryString = d3.debug.summaryString = (obj) ->
  if _.isArray(obj)
    "#{obj.constructor.name}[#{obj.length}]"
  else if _.isElement(obj)
    if obj.attributes.class
      obj.tagName + '.' + obj.attributes.class.value.split(' ').join('.')
    else
      obj.tagName
  else if _.isObject(obj)
    obj.constructor.name
  else
    obj

# Shortcut for console output
c = console

# Generate nested console output
# (a more consise and user friendly wrapper over various existing console methods)
#
# Usage:
#   c.section "Foo", "Moo"
#   c.section "Foo", 666
#   c.section "Foo", -> val
#   c.section title: "Foo", -> val
#   c.section title: "Foo", contents: "Moo"
#   c.section title: "Foo", contents: -> val
#   c.section titleArgs: ["Foo %O", elt], contents: -> val
#   c.section titleArgs: ["Foo %O", elt], -> val
#   c.section title: "Foo", expanded: false, contents: "Moo"
#   c.section title: "Foo", expanded: false, -> val
console.section = (a, b) ->
  if _.isString(a) or !_.isObject(a)
    opts = {}
    titleArgs = [a]
    contents = b
  else
    opts = a
    if opts.title
      titleArgs = [opts.title]
    else
      titleArgs = opts.titleArgs
    contents = opts.contents or b

  if opts.expanded != false
    c.group(titleArgs...)
  else
    c.groupCollapsed(titleArgs...)
  if _.isFunction(contents)
    output = contents()
  else
    c.log(contents)
  c.groupEnd()
  output


### Object Log (olog) Methods ###
# olog is used to optionally save all debugged objects for further inspection

olog.enable = ->
  olog.enabled = true
  c.warn("Currently saving debugged objects! This will cause memory leaks and should not be used in production.")

olog.disable = ->
  olog.enabled = false
  c.warn("No longer saving debugged objects.")

olog.save = (obj) ->
  if olog.enabled
    c.warn("Saved to olog[#{olog.length}]")
    olog.push(obj)

### Public D3 methods ###
# These are the methods you would usually call for normal inspection

# Example Usage:
#   sel.inspect()
#   sel.inspect("Context")
#   sel.inspect(selectionPrefix: "Context")
#   sel.inspect(selectionPrefix: "Context", alsoLog: "Extra stuff to log")
d3.selection.prototype.inspect = (opts) -> d3.debug.selection(this, opts)
d3.selection.enter.prototype.inspect = (opts) ->
  opts = d3.debug.selection.processOpts(opts)
  opts['isEnterSelection'] = true
  d3.debug.selection(this, opts)

# Example Usage:
#   sel.inspectWrap(-> @attr('class','foo'))
#   sel.inspectWrap("Context", -> @attr('class','foo'))
#   sel.inspectWrap -> @
#     .attr('class','foo')
#     .attr('class','bar')
#   sel.inspectWrap "Context", -> @
#     .attr('class','foo')
#     .attr('class','bar')
d3.selection.prototype.inspectWrap = (a, b) -> d3.debug.wrap(this, a, b)

# Used just like inspect, except this also starts a "debugger" after the inspection.
d3.selection.prototype.debug = (opts) -> 
  d3.selection.prototype.inspect(opts)
  selection = s = this
  debugger
  selection
d3.selection.enter.prototype.debug = (opts) ->
  d3.selection.enter.prototype.inspect(opts)
  selection = s = this
  debugger
  selection

### d3.debug methods ###
# These are the d3.debug "private" methods used be the public methods above, which might also be used for custom debug output

d3.debug.selection = (sel, rawOpts) ->
  opts = d3.debug.selection.processOpts(rawOpts)

  enterText = if opts.isEnterSelection then "Enter Selection" else ''
  selectionPrefix = if opts.selectionPrefix then '[' + opts.selectionPrefix + '] ' else ''

  c.section titleArgs: ["%c%s%cSelection: %O%c%s", 'color: green', selectionPrefix, 'color: black', sel, 'color: purple', enterText], ->
    if opts.selectionDebug
      c.debug("%c%s", "color: blue", opts.selectionDebug) # TODO
    c.assert(_.isArray(sel))
    for group, i in sel
      d3.debug.group(group, i, opts)
    if olog.enabled || opts.alsoLog
      c.section title: "Other Details", expanded: false, ->
        if opts.alsoLog
          c.debug("Custom:", opts.alsoLog)
        olog.save(sel, '')
  sel

d3.debug.selection.processOpts = (opts) ->
  opts ||= {}
  if !_.isObject(opts)
    opts = {selectionPrefix: opts}
  opts

d3.debug.group = (group, index, opts) ->
  c.assert(_.isArray(group))
  warnings = []
  warnings.push "Empty Group" if group.length == 0
  if numNull(group)
    warnings.push "#{numNull(group)} Nulls"
  if numUndefined(group)
    warnings.push "#{numUndefined(group)} Undefined"
  if elementMissing(group.parentNode)
    warnings.push "Parent node #{elementMissing(group.parentNode)}"

  c.section
    titleArgs: ["Group<#{index}> %c#{summaryString(group.parentNode)}%c %O%c#{warnings.join(', ')}", 'color: #000099', 'color: black', group, 'color: red']
    expanded: index == 0 # Expand the first group as an example
    contents: ->
      for elt, i in group
        d3.debug.element(elt, "Element", i, opts)
      d3.debug.element(group.parentNode, "Parent")
  group

d3.debug.element = (elt, heading, index, opts) ->
  indexString = if !_.isUndefined(index) then "<#{index}>" else ''
  heading ||= "Element"

  if elementMissing(elt)
    c.section
      titleArgs: ["%c#{heading + indexString}: #{elementMissing(elt)}", 'color: red']
      expanded: false
      contents: -> c.debug(elt)
  else
    if opts and opts.isEnterSelection
      heading = "Placeholder " + heading
    else
      c.assert(_.isElement(elt))

    c.section titleArgs: ["#{heading + indexString} %c#{summaryString(elt)}%c %O %o", 'color: #000099', 'color: black', elt, elt], expanded: false, ->
      d3.debug.data(elt.__data__)
  elt

d3.debug.data = (data) ->
  dataOutput = []
  if _.isObject(data)
    dataOutput.push("Data: type='#{summaryString(data)}'")
    dataOutput.push("• data.keys=", nonIndexKeys(data))
    if _.isArray(data)
      dataOutput.push("• data[0].keys=", nonIndexKeys(data[0]))
  else
    dataOutput.push('Data:' , data)
  c.debug(dataOutput...)

d3.debug.wrap = (sel, a, b) ->
  title = "Wrapped d3 selection method call"
  if _.isFunction(a)
    op = a
  else
    title = '[' + a + '] ' + title
    op = b

  result = null
  c.section titleArgs: ['%c' + title, 'color: green; font-weight: 900'] , ->
    c.debug("Method: ", op)
    sel.inspect("* Before *")
    result = op.apply(sel)
    result.inspect("* After *")
  result
