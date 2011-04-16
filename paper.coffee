#
# This file is based on readabiity.js:
# http://code.google.com/p/arc90labs-readability/
#
# Copyright (c) 2010 Arc90 Inc
# Copyright (c) 2011 MORITA Hajime
# Readability is licensed under the Apache License, Version 2.0.
#
#

textContentFor = (node, normalizeWs = true) ->
  return "" if typeof(node.textContent) == "undefined" and typeof(node.innerText) == "undefined"
  textContent = node.textContent.replace(Extractor.regexps.trim, "")
  if normalizeWs
    textContent.replace(Extractor.regexps.normalize, " ")
  else
    textContent

countChars = (node, ch) ->
  textContentFor(node).split(ch).length - 1

linkDensityFor = (node) ->
  linkLength = _.reduce($(node).find("a"), ((len, n) -> len + n.innerHTML.length), 0)
  textLength = node.innerHTML.length
  linkLength/textLength

classWeight = (node) ->
  0

fishy = (node) ->
  # XXX: class weight
  weight = 0
  contentScore = if node.score then node.score.value else 0
  #Paper.debug("weight:" + weight + " consco:" + contentScore + " comma:" + countChars(node, ','))
  return true if weight + contentScore < 0
  return false if 10 <= countChars(node, ',')
  nj = $(node)
  p      = nj.find("p").length
  img    = nj.find("img").length
  li     = nj.find("li").length - 100
  input  = nj.find("input").length
  embed  = nj.find("embed").length
  #Paper.debug("p:" + p + " img:" + img + " li:" + li + " input:" + input + " embed:" + embed)
  linkDensity   = linkDensityFor(node)
  contentLength = textContentFor(node).length

  return true if img > p
  return true if li > p and node.tagName != "ul" and node.tagName != "ol"
  return true if input > Math.floor(p/3)
  return true if contentLength < 25 and (img == 0 || img > 2)
  return true if weight < 25 && linkDensity > 0.2
  return true if weight >= 25 && linkDensity > 0.5
  return true if (embed == 1 && contentLength < 75) || embed > 1
  false

class Paper
  this.print = (message) -> console.log(message)
  this.error = (message) -> console.log(message)
  this.log = (message) -> console.log(message)
  this.debug = (message) -> console.log(message)


class Score
  constructor: (node) ->
    this.value = if node then Score.initialScoreFor(node.tagName) else 0

  add: (n) -> this.value += n
  scale: (s) -> this.value *= s

  this.initialScoreFor = (tagName) ->
    switch tagName
      when 'DIV' then 5
      when 'PRE', 'TD', 'BLOCKQUOTE' then 3
      when 'ADDRESS', 'OL', 'UL', 'DL', 'DD', 'DT', 'LI', 'FORM' then -3
      when 'H1', 'H2', 'H3', 'H4', 'H5' then -5
      else 0

class Extractor

  this.regexps = {
    unlikelyCandidates:    /combx|comment|community|disqus|extra|foot|header|menu|remark|rss|shoutbox|sidebar|sponsor|ad-break|agegate|pagination|pager|popup|tweet|twitter/i,
    okMaybeItsACandidate:  /and|article|body|column|main|shadow/i,
    positive: /article|body|content|entry|hentry|main|page|pagination|post|text|blog|story/i,
    negative: /combx|comment|com-|contact|foot|footer|footnote|masthead|media|meta|outbrain|promo|related|scroll|shoutbox|sidebar|sponsor|shopping|tags|tool|widget/i,
    extraneous:       /print|archive|comment|discuss|e[\-]?mail|share|reply|all|login|sign|single/i,
    divToPElements:   /<(a|blockquote|dl|div|img|ol|p|pre|table|ul)/i,
    replaceBrs:       /(<br[^>]*>[ \n\r\t]*){2,}/gi,
    replaceFonts:     /<(\/?)font[^>]*>/gi,
    trim:             /^\s+|\s+$/g,
    normalize:        /\s{2,}/g,
    killBreaks:       /(<br\s*\/?>(\s|&nbsp;?)*){1,}/g,
    videos:           /http:\/\/(www\.)?(youtube|vimeo)\.com/i,
    skipFootnoteLink: /^\s*(\[?[a-z0-9]{1,2}\]?|^|edit|citation needed)\s*$/i,
    nextLink:         /(next|weiter|continue|>([^\|]|$)|ﾂｻ([^\|]|$))/i, # Match: next, continue, >, >>, ﾂｻ but not >|, ﾂｻ| as those usually mean last.
    prevLink:         /(prev|earl|old|new|<|ﾂｫ)/i
  }

  constructor: (page) ->
    this.page = page
    this.root = document.createElement("div")

  extract: ->
    top = this.scoreAndSelectTop_()
    collected = this.collectSiblings_(top)
    this.removeFragments_(collected)
    collected

  pageAsTop_: ->
    Paper.log("not found. using page element")
    this.page.score = new Score(this.page)
    this.page

  scoreAndSelectTop_: ->
    all = $(this.page).find('*')
    parified = _.map(all, _.bind(this.parify_, this))
    scored = _.reduce(parified, this.reduceScorable_, [], this)
    _.each(scored, (n) => n.score.scale(1 - linkDensityFor(n)))
    #Paper.debug(n.tagName + ":" + n.score.value) for n in scored
    _.sortBy(scored, (n) -> n.score.value)[scored.length-1] or this.pageAsTop_()

  # Turn all divs that don't have children block level elements into p's
  # TODO(omo): support experimental parify text node
  parify_: (node) ->
    return node if node.tagName != "DIV"
    return node if node.innerHTML.search(Extractor.regexps.divToPElements) > -1
    p = document.createElement('p')
    p.innerHTML = node.innerHTML
    node.parentNode.replaceChild(p, node)
    p

  cleanupPageText_: (text) ->
    r = Extractor.regexps
    text.replace(r.replaceBrs, '</p><p>').replace(r.replaceFonts, '<$1span>')

  reduceScorable_: (scorables, node) ->
    r = Extractor.regexps
    unlikely = node.className + node.id
    if unlikely.search(r.unlikelyCandidates) != -1 and \
       unlikely.search(r.okMaybeItsACandidate) == -1 and \
       node.tagName != "BODY"
      return scorables
    unless node.tagName == "P" || node.tagName == "TD" || node.tagName == "PRE"
      return scorables

    innerText = textContentFor(node)
    contentScore = this.scoreContent_(innerText)
    return scorables if 0 == contentScore

    parent = node.parentNode
    if parent
      this.pushUniqueScorable_(scorables, parent)
      parent.score.add(contentScore)
      grandParent = parent.parentNode
      if grandParent
        this.pushUniqueScorable_(scorables, grandParent)
        grandParent.score.add(contentScore/2)
    scorables

  pushUniqueScorable_: (array, node) ->
    return if !node or typeof(node.tagName) == 'undefined'
    if not node.score
      node.score = new Score(node)
      array.push(node)

  scoreContent_: (text) ->
    return 0 if text.length < 25
    # Add points for any commas within this paragraph
    # For every 100 characters in this paragraph, add another point. Up to 3 points.
    1 + text.split(',').length + Math.min(Math.floor(text.length / 100), 3)

  collectSiblings_: (top) ->
    (_.reduce(
      $(top.parentNode).children(),
      ((root, s) =>
        root.appendChild(s) if this.isAcceptableSibling_(top, s)
        root),
      $("<div>")[0]))

  isAcceptableSibling_: (top, sib) ->
    return true if top == sib
    threshold = Math.max(10, top.score.value * 0.2)
    return false if this.scoreSibling_(top, sib) <= threshold
    return false if "P" != node.tagName
    density = linkDensityFor(sib)
    text = textContentFor(sib)
    textLen = text.length
    return true if 80 < textLen and density < 0.25
    return true if textLen < 80 and linkDensity == 0 and text.search(/\.( |$)/) != -1
    false

  scoreSibling_: (top, sib) ->
    return 0 if !sib.score
    if sib.className == sib.className && sib.className != ""
      sib.score.value + (top.score.value * 0.2)
    else
      sib.score.value

  cleanHeaders_: (node) ->
    $(node).find("h1,h2,h3").find(
      (n) -> classWeight(n) < 0 or linkDensityFor(n) > 0.33
    ).remove()

  removeFragments_: (node) ->
    node.innerHTML = node.innerHTML.replace(Extractor.regexps.killBreaks,'<br />')
    this.cleanHeaders_(node)
    jn = $(node).find("*")
    js = jn.removeAttr("style")
    jn = jn.remove("object,h1,iframe,script")
    jn = jn.remove("h2") if jn.find("h2").length == 1
    jn = jn.find("form").filter(-> fishy(this)).remove()
    jn = jn.find("table").filter(-> fishy(this)).remove()
    jn = jn.find("ul").filter(-> fishy(this)).remove()
    jn = jn.find("div").filter(-> fishy(this)).remove()
    jn = jn.find("p").filter(-> \
      0 < $(this).find("img").length or
      0 < $(this).find("embed").length or
      0 < $(this).find("object").length or
      0 < textContentFor(this, false).length).remove()
    node.innerHTML = node.innerHTML.replace(/<br[^>]*>\s*<p/gi, '<p')
#
# Bootstrap
#
if phantom.state.length == 0
  if phantom.args.length == 0
    PhantomJs.error('Usage: loadspeed.js <some URL>')
    phantom.exit()
  else
    address = phantom.args[0]
    phantom.state = "loading"
    console.log('Loading ' + address)
    phantom.open(address)
else
  if phantom.loadStatus == 'success'
    console.log('Page title is ' + document.title)
    console.log("no body") unless document.body
    extr = new Extractor(document.body)
    extracted = extr.extract()
    Paper.debug("extracted size:" + $(extracted).children().length)
    _.each($(extracted).children(),
      (n) -> Paper.debug(n.tagName + ":" + n.textContent))


  else
    Paper.error('FAIL to load the address:' + phantom.loadStatus)
  phantom.exit()
