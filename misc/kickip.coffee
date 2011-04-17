
BOOKMARKLET = "function iprl5(){var d=document,z=d.createElement('scr'+'ipt'),b=d.body,l=d.location;try{if(!b)throw(0);d.title='(Saving...) '+d.title;z.setAttribute('src',l.protocol+'//www.instapaper.com/j/bUwJo5H3gnI5?u='+encodeURIComponent(l.href)+'&t='+(new Date().getTime()));b.appendChild(z);}catch(e){alert('Please wait until the page has loaded.');}}iprl5();void(0)"

check = (cond, msgfn) ->
  unless cond
    console.log(msgfn())
    phantom.exit(1)

check(phantom.loadStatus != 'fail', -> "Failed to load page:" + document.location)
console.log("state:" + phantom.state + "/" + phantom.loadStatus + " (" + document.location + ")")

switch phantom.state
  when ""
    check(phantom.args.length == 3, -> 'Usage: kickip.js <some URL> <mail> <password>')
    phantom.state = "tologin"
    phantom.open("http://www.instapaper.com/user/login")
  when "tologin"
    document.getElementById("username").value = phantom.args[1]
    document.getElementById("password").value = phantom.args[2]
    document.getElementById("log_in").click()
    phantom.state = "logined"
  when "logined"
    check(-1 == document.body.textContent.search("Sorry"), -> "Password is wrong")
    if (document.location.toString() == "http://www.instapaper.com/u")
      phantom.state = "ready"
      phantom.open(phantom.args[0])
  when "ready"
    eval(BOOKMARKLET)
    phantom.state = "saving"
  when "saving"
    waitSaving = ->
      if 0 <= document.title.indexOf("Saving")
        console.log("Saving...")
        window.setTimeout(waitSaving, 0)
      else
        phantom.state = "done"
    window.setTimeout(waitSaving, 0)
  when "done"
    console.log("done")
    window.setTimeout(-> phantom.exit())
  else
    check(false, -> "Unexpected state:" + phantom.state)
