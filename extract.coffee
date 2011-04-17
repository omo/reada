#
# This file is based on readabiity.js:
# http://code.google.com/p/arc90labs-readability/
#
# Copyright (c) 2010 Arc90 Inc
# Copyright (c) 2011 MORITA Hajime
# This software is licensed under the Apache License, Version 2.0.
#

class Log
  this.print = (message) -> console.log(message)
  this.error = (message) -> console.log(message)
  this.log = (message) -> console.log(message)
  this.debug = (message) -> console.log(message)


class Score
  constructor: (node) ->
    this.value = Score.initialScoreFor(node.tagName)

  add: (n) -> this.value += n
  scale: (s) -> this.value *= s

  this.initialScoreFor = (tagName) ->
    switch tagName
      when 'DIV' then 5
      when 'PRE', 'TD', 'BLOCKQUOTE' then 3
      when 'ADDRESS', 'OL', 'UL', 'DL', 'DD', 'DT', 'LI', 'FORM' then -3
      when 'H1', 'H2', 'H3', 'H4', 'H5' then -5
      else 0

REGEXPS =
  unlikelyCandidates:    /combx|comment|community|disqus|extra|foot|header|menu|remark|rss|shoutbox|sidebar|sponsor|ad-break|agegate|pagination|pager|popup|tweet|twitter/i,
  okMaybeItsACandidate:  /and|article|body|column|main|shadow/i,  okMaybeItsACandidate:  /and|article|body|column|main|shadow/i,
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


textContentFor = (node, normalizeWs = true) ->
  return "" unless node.textContent
  text = node.textContent.replace(REGEXPS.trim, "")
  text = text.replace(REGEXPS.normalize, " ") if normalizeWs
  text

countChars = (node, ch) ->
  textContentFor(node).split(ch).length - 1

linkDensityFor = (node) ->
  linkLength = _.reduce($(node).find("a"), ((len, n) -> len + n.innerHTML.length), 0)
  textLength = node.innerHTML.length
  linkLength/textLength

classWeight = (node) ->
  weight = 0
  if node.className
    weight -= 25 if -1 < node.className.search(REGEXPS.negative)
    weight += 25 if -1 < node.className.search(REGEXPS.positive)
  if node.id
    weight -= 25 if -1 < node.id.search(REGEXPS.negative)
    weight += 25 if -1 < node.id.search(REGEXPS.positive)
  weight

fishy = (node) ->
  weight = classWeight(node)
  contentScore = if node.score then node.score.value else 0
  return true if weight + contentScore < 0
  return false if 10 <= countChars(node, ',')
  nj = $(node)
  p      = nj.find("p").length
  img    = nj.find("img").length
  li     = nj.find("li").length - 100
  input  = nj.find("input").length
  embed  = nj.find("embed").length
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

# Turn all divs that don't have children block level elements into p's
# TODO(omo): support experimental parify text node
parify = (node) ->
  return node if node.tagName != "DIV"
  return node if node.innerHTML.search(REGEXPS.divToPElements) > -1
  p = $("<p>").html(node.innerHTML)[0]
  node.parentNode.replaceChild(p, node)
  p

ensureScore = (array, node) ->
  return if !node or typeof(node.tagName) == 'undefined'
  if not node.score
    node.score = new Score(node)
    array.push(node)

propagateScore = (node, scoredList, score) ->
  parent = node.parentNode
  if parent
    ensureScore(scoredList, parent)
    parent.score.add(score)
    grandParent = parent.parentNode
    if grandParent
      ensureScore(scoredList, grandParent)
      grandParent.score.add(score/2)

scoreNode = (node) ->
  unlikely = node.className + node.id
  if unlikely.search(REGEXPS.unlikelyCandidates) != -1 and \
     unlikely.search(REGEXPS.okMaybeItsACandidate) == -1 and \
     node.tagName != "BODY"
    return 0
  unless node.tagName == "P" || node.tagName == "TD" || node.tagName == "PRE"
    return 0
  text = textContentFor(node)
  return 0 if text.length < 25
  # Add points for any commas within this paragraph
  # For every 100 characters in this paragraph, add another point. Up to 3 points.
  1 + text.split(',').length + Math.min(Math.floor(text.length / 100), 3)

reduceScorable = (scoredList, node) ->
  score = scoreNode(node)
  propagateScore(node, scoredList, score) if 0 < score
  scoredList

isAcceptableSibling = (top, sib) ->
  return true if top == sib
  threshold = Math.max(10, top.score.value * 0.2)
  return true if threshold <= scoreSibling(top, sib)
  return false if "P" != sib.tagName
  density = linkDensityFor(sib)
  text = textContentFor(sib)
  textLen = text.length
  return true if 80 < textLen and density < 0.25
  return true if textLen < 80 and density == 0 and text.search(/\.( |$)/) != -1
  false

scoreSibling = (top, sib) ->
  return 0 if !sib.score
  if sib.className == sib.className && sib.className != ""
    sib.score.value + (top.score.value * 0.2)
  else
    sib.score.value

removeFragments = (node) ->
  jn = $(node)
  jn.html(jn.html().replace(REGEXPS.killBreaks,'<br />'))
  jn.find("h1,h2,h3").find(
    (n) -> classWeight(n) < 0 or linkDensityFor(n) > 0.33
  ).remove()
  jn.find("*").removeAttr("style")
  jn.find("p").filter(-> \
    0 == $(this).find("img").length and \
    0 == $(this).find("embed").length and \
    0 == $(this).find("object").length and \
    0 == textContentFor(this, false).length).remove()
  jn.find("form").filter(-> fishy(this)).remove()
  jn.find("table").filter(-> fishy(this)).remove()
  jn.find("ul").filter(-> fishy(this)).remove()
  jn.find("div").filter(-> fishy(this)).remove()
  jn.find("object,h1,iframe,script,link,style").remove()
  jn.find("h2").remove() if jn.find("h2").length == 1
  node.innerHTML = node.innerHTML.replace(/<br[^>]*>\s*<p/gi, '<p')

asTop = (page) ->
  Log.log("not found. using page element")
  page.score = new Score(page)
  page

scoreAndSelectTop = (nodes) ->
  scored = _.reduce(nodes, reduceScorable, [])
  _.each(scored, (n) => n.score.scale(1 - linkDensityFor(n)))
  _.sortBy(scored, (n) -> n.score.value)[scored.length-1]

collectSiblings = (top) ->
  _.reduce(
    $(top.parentNode).children(),
    ((root, s) =>
      root.appendChild(s) if isAcceptableSibling(top, s)
      root),
    document.createElement("div"))

extract = (page) ->
  parified = _.map($(page).find('*'), parify)
  top = scoreAndSelectTop(parified) or asTop(page)
  root = collectSiblings(top)
  removeFragments(root)
  root

#
# Bootstrap
#
if phantom.state.length == 0
  if phantom.args.length == 0
    PhantomJs.error('Usage: xxxx.js <some URL>')
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
    extracted = extract(document.body)
    Log.print(extracted.textContent.replace(/\n{3,}/g, "\n"))
  else
    Log.error('FAIL to load the address:' + phantom.loadStatus)
  phantom.exit()
