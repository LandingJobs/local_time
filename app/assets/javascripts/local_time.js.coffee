browserIsCompatible = ->
  document.querySelectorAll and document.addEventListener

return unless browserIsCompatible()

# Older browsers do not support ISO8601 (JSON) timestamps in Date.parse
if isNaN Date.parse "2011-01-01T12:00:00-05:00"
  parse = Date.parse
  iso8601 = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(Z|[-+]?[\d:]+)$/

  Date.parse = (dateString) ->
    dateString = dateString.toString()
    if matches = dateString.match iso8601
      [_, year, month, day, hour, minute, second, zone] = matches
      offset = zone.replace(":", "") if zone isnt "Z"
      dateString = "#{year}/#{month}/#{day} #{hour}:#{minute}:#{second} GMT#{[offset]}"
    parse dateString

weekdays = "Sunday Monday Tuesday Wednesday Thursday Friday Saturday".split " "
months   = "January February March April May June July August September October November December".split " "

pad = (num) -> ('0' + num).slice -2

strftime = (time, formatString) ->
  day    = time.getDay()
  date   = time.getDate()
  month  = time.getMonth()
  year   = time.getFullYear()
  hour   = time.getHours()
  minute = time.getMinutes()
  second = time.getSeconds()

  formatString.replace /%([%aAbBcdeHIlmMpPSwyYZ])/g, ([match, modifier]) ->
    switch modifier
      when '%' then '%'
      when 'a' then weekdays[day].slice 0, 3
      when 'A' then weekdays[day]
      when 'b' then months[month].slice 0, 3
      when 'B' then months[month]
      when 'c' then time.toString()
      when 'd' then pad date
      when 'e' then date
      when 'H' then pad hour
      when 'I' then pad strftime time, '%l'
      when 'l' then (if hour is 0 or hour is 12 then 12 else (hour + 12) % 12)
      when 'm' then pad month + 1
      when 'M' then pad minute
      when 'p' then (if hour > 11 then 'PM' else 'AM')
      when 'P' then (if hour > 11 then 'pm' else 'am')
      when 'S' then pad second
      when 'w' then day
      when 'y' then pad year % 100
      when 'Y' then year
      when 'Z' then time.toString().match(/\((\w+)\)$/)?[1] ? ''


class CalendarDate
  @fromDate: (date) ->
    new this date.getFullYear(), date.getMonth() + 1, date.getDate()

  @today: ->
    @fromDate new Date

  constructor: (year, month, day) ->
    @date = new Date Date.UTC year, month - 1
    @date.setUTCDate day

    @year = @date.getUTCFullYear()
    @month = @date.getUTCMonth() + 1
    @day = @date.getUTCDate()
    @value = @date.getTime()

  equals: (calendarDate) ->
    calendarDate?.value is @value

  is: (calendarDate) ->
    @equals calendarDate

  isToday: ->
    @is @constructor.today()

  occursOnSameYearAs: (date) ->
    @year is date?.year

  occursThisYear: ->
    @occursOnSameYearAs @constructor.today()

  daysSince: (date) ->
    if date
      (@date - date.date) / (1000 * 60 * 60 * 24)

  daysPassed: ->
    @constructor.today().daysSince @


class RelativeTime
  constructor: (@date) ->
    @calendarDate = CalendarDate.fromDate @date

  toString: ->
    # Up to 1 day ago: "just now", "1 min ago", "1 hour ago"
    if ago = @timeElapsed()
      ago

    else if day = @relativeWeekday()
      if day == null
        # Today, over 1 hour ago: "3:45 PM"
        @formatTime()
      else
        # Up to 1 week: "Yesterday, 3:45 PM", "Mon, 3:45 PM"
        day

    # Older: "June 30, 3:45 PM", "June 30 2014, 10:55"
    else
      "#{@formatDate()}"

  toTimeOrDateString: ->
    if @calendarDate.isToday()
      @formatTime()
    else
      @formatDateTime()

  timeElapsed: ->
    ms  = new Date().getTime() - @date.getTime()
    sec = Math.round ms  / 1000
    min = Math.round sec / 60
    hr  = Math.round min / 60

    if ms < 0
      null
    else if sec < 60
      "just now"
    else if min == 1
      "#{min} min ago"
    else if min < 60
      "#{min} mins ago"
    else if hr == 1
      "#{hr} hour ago"
    else if hr < 24
      "#{hr} hours ago"
    else
      null

  relativeWeekday: ->
    switch @calendarDate.daysPassed()
      when 0
        null
      when 1
        "Yesterday"
      when 2,3,4,5,6
        strftime @date, "%A"

  formatDateTime: ->
    format = "%b %e"
    format += " %Y" unless @calendarDate.occursThisYear()
    format += ', %l:%M%P'
    strftime @date, format

  formatDate: ->

    if day = @relativeWeekday()

      if day == null
        'Today'
      else
        day
    else
      format = "%b %e"
      format += " %Y" unless @calendarDate.occursThisYear()
      strftime @date, format

  formatTime: ->
    strftime @date, '%l:%M%P'

relativeDate = (date) ->
  new RelativeTime(date).formatDate()

relativeTimeAgo = (date) ->
  new RelativeTime(date).toString()

relativeTimeOrDate = (date) ->
  new RelativeTime(date).toTimeOrDateString()

relativeWeekday = (date) ->
  if day = new RelativeTime(date).relativeWeekday()
    day.charAt(0).toUpperCase() + day.substring(1)


domLoaded = false

update = (callback) ->
  callback() if domLoaded

  document.addEventListener "time:elapse", callback

  if Turbolinks?.supported
    document.addEventListener "page:update", callback
  else
    jQuery?(document).on "ajaxSuccess", (event, xhr) ->
      callback() if jQuery.trim xhr.responseText

process = (selector, callback) ->
  update ->
    for element in document.querySelectorAll selector
      callback element

document.addEventListener "DOMContentLoaded", ->
  domLoaded = true
  textProperty = if "textContent" of document.body then "textContent" else "innerText"

  process "time[data-local]:not([data-localized])", (element) ->
    datetime = element.getAttribute "datetime"
    format   = element.getAttribute "data-format"
    local    = element.getAttribute "data-local"

    time = new Date Date.parse datetime
    return if isNaN time

    unless element.hasAttribute("title")
      element.setAttribute "title", strftime(time, "%B %e, %Y at %l:%M%P %Z")

    element[textProperty] =
      switch local
        when "date"
          element.setAttribute "data-localized", true
          relativeDate time
        when "time"
          element.setAttribute "data-localized", true
          strftime time, format
        when "time-ago"
          relativeTimeAgo time
        when "time-or-date"
          relativeTimeOrDate time
        when "weekday"
          relativeWeekday(time) ? ""
        when "weekday-or-date"
          relativeWeekday(time) ? relativeDate(time)

run = ->
  event = document.createEvent "Events"
  event.initEvent "time:elapse", true, true
  document.dispatchEvent event

setInterval run, 60 * 1000

# Public API
@LocalTime = {relativeDate, relativeTimeAgo, relativeTimeOrDate, relativeWeekday, run, strftime}
