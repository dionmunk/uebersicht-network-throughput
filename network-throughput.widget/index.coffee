command: """
    netstat -ibn | awk '$3 ~ /^<Link/ && $1 !~ /^lo/ {ib += $7; ob += $10} END {print ib "^" ob}'
"""

refreshFrequency: '1s'

# Toggle the graph panel on/off without removing the widget
showGraph: false

historyLength: 60  # 1 min @ 1s refresh

history: []

style: """
  // grid: col 1 · row 4 · 1×1  (see LAYOUT.md)
  top 280px
  left 10px

  color var(--text, #fff)
  text-shadow: 0 1px 1px rgba(20, 1, 1, 0.2)   // inherits to all text elements
  font-family -apple-system, BlinkMacSystemFont, system-ui, sans-serif
  display: flex
  gap: 10px

  .panel
    background var(--panel-bg, rgba(#000, .15))
    -webkit-backdrop-filter: blur(var(--panel-blur, 48px))
    backdrop-filter: blur(var(--panel-blur, 48px))
    border-radius 10px
    box-sizing: border-box
    min-height: 80px       // base minimum widget height (see LAYOUT.md)

  .panel-stats
    padding 9px 10px 12px
    display: flex          // lets stats-inner fill the 80px panel height

  .panel-graph
    padding 10px

  .stats-inner
    width: 300px
    text-align: left
    position: relative
    display: flex
    flex-direction: column   // title on top, numbers + bar pushed to the bottom

  .widget-title
    font-size 10px
    text-transform uppercase
    font-weight bold
    margin-bottom: 1px

  .stats-container
    width: 100%
    margin-top: auto       // push the numbers + bar to the panel bottom
    margin-bottom 5px      // gap between the labels and the bar
    border-collapse collapse
    table-layout: fixed

  td
    font-size: 14px
    font-weight: 300
    text-align: left
    width: 50%

  .stat
    width: 50%
    padding-bottom: 4px    // space between the numbers and their labels below them
    .down
      float: left
      text-align left
    .up
      float: right
      text-align right

  .label-down
    font-size 8px
    text-transform uppercase
    font-weight bold
    float: left
    align: left

  .label-up
    font-size 8px
    text-transform uppercase
    font-weight bold
    float: right
    align: right

  .bar-container
    width: 100%
    height: 6px
    border-radius: 6px
    background: var(--level-base, rgba(#fff, .2))
    position: relative
    box-shadow: 0 1px 1px rgba(20, 1, 1, 0.10)   // base bar: matches text shadow

  // Independent cumulative layers (like cpu/memory): `up` is the full-width base
  // layer; `down` sits on top from the left at its own proportion. down + up are
  // normalised to 100%, so the exposed part of `up` (beyond down) equals upload's
  // share. down's opaque cap overhangs the seam onto the up fill behind it.
  .bar
    position: absolute
    left: 0
    top: 0
    height: 6px
    border-radius: 6px
    transition: width .2s ease-in-out
    box-shadow: 1px 0 3px rgba(0, 0, 0, 0.04)   // faint separation under the cap

  .bar-up
    z-index: 1
    background: var(--blue, rgba(#fff, .5))

  .bar-down
    z-index: 2
    background: var(--series-primary, rgba(#fff, 1))

  .graph-container
    width: 300px
    height: 53px
    position: relative
    overflow: hidden
    border: 1px solid var(--hairline, rgba(#ccc, .125))
    border-radius: 3px
    box-sizing: border-box
    padding: 1px
    background-image: radial-gradient(var(--dot-grid, rgba(#fff, .05)) 1px, transparent 1.5px)
    background-size: 10px 10px
    background-position: -4px -4px

  .peak-label
    position: absolute
    top: 3px
    font-size: 9px
    text-transform: uppercase
    font-weight: bold
    color: var(--text, #fff)
    pointer-events: none

  .peak-down
    left: 3px

  .peak-up
    right: 3px

  svg
    display: block
    width: 100%
    height: 100%

  .line-down
    fill: none
    stroke: var(--series-primary, rgba(#fff, 1))
    stroke-width: 1.5
    vector-effect: non-scaling-stroke
    stroke-linejoin: round
    stroke-linecap: round

  .area-down
    fill: var(--series-primary-fill, rgba(#fff, .3))
    stroke: none

  .line-up
    fill: none
    stroke: var(--blue, rgba(#fff, .5))
    stroke-width: 1.5
    vector-effect: non-scaling-stroke
    stroke-linejoin: round
    stroke-linecap: round

  .area-up
    fill: var(--blue-fill, rgba(#fff, .15))
    stroke: none

  .peak-arrow-down
    color: var(--series-primary, rgba(#fff, 1))

  .peak-arrow-up
    color: var(--blue, rgba(#fff, .5))
"""

render: -> """
  <div class="panel panel-stats">
    <div class="stats-inner">
      <div class="widget-title">Network</div>
      <table class="stats-container">
        <tr>
          <td class="stat"><span class="down"></span></td>
          <td class="stat"><span class="up"></span></td>
        </tr>
        <tr>
          <td class="label"><span class="label-down">down</span></td>
          <td class="label"><span class="label-up">up</span></td>
        </tr>
      </table>
      <div class="bar-container">
        <div class="bar bar-down"></div>
        <div class="bar bar-up"></div>
      </div>
    </div>
  </div>
  #{if @showGraph then """
  <div class="panel panel-graph">
    <div class="graph-container">
      <svg preserveAspectRatio="none" viewBox="0 0 59 100">
        <polygon class="area-down" points=""></polygon>
        <polygon class="area-up" points=""></polygon>
        <polyline class="line-down" points=""></polyline>
        <polyline class="line-up" points=""></polyline>
      </svg>
      <div class="peak-label peak-down"></div>
      <div class="peak-label peak-up"></div>
    </div>
  </div>
  """ else ""}
"""

update: (output, domEl) ->
  usage = (bytes) ->
    kb = bytes / 1024
    usageFormat kb

  usageFormat = (kb) ->
    if kb > 1024
      mb = kb / 1024
      "#{parseFloat(mb.toFixed(1))} MB/s"
    else
      "#{parseFloat(kb.toFixed(2))} KB/s"

  updateStat = (sel, currBytes) ->
    $(domEl).find(".#{sel}").text usage(currBytes)

  parts = output.split "^"
  ib = Number(parts[0])
  ob = Number(parts[1])
  return unless isFinite(ib) and isFinite(ob)

  now = Date.now()
  unless @prev
    @prev = {ib, ob, t: now}
    return

  elapsed = (now - @prev.t) / 1000
  return if elapsed <= 0

  downBytes = Math.max(0, (ib - @prev.ib) / elapsed)
  upBytes   = Math.max(0, (ob - @prev.ob) / elapsed)
  @prev = {ib, ob, t: now}

  totalBytes = downBytes + upBytes
  if totalBytes > 0
    updateStat 'down', downBytes
    updateStat 'up',   upBytes
    # Cumulative layers: down on top at its share, up the full-width base behind it.
    $(domEl).find('.bar-down').css 'width', "#{downBytes / totalBytes * 100}%"
    $(domEl).find('.bar-up').css   'width', '100%'
  else
    $(domEl).find(".down").text usage(0)
    $(domEl).find(".up").text   usage(0)

  return unless @showGraph

  @history ?= []
  @history.push {down: downBytes, up: upBytes}
  @history.shift() while @history.length > @historyLength

  return if @history.length < 2

  minScale = 10 * 1024
  maxY = minScale
  peakDown = 0
  peakUp   = 0
  for s in @history
    maxY = Math.max(maxY, s.down, s.up)
    peakDown = Math.max(peakDown, s.down)
    peakUp   = Math.max(peakUp,   s.up)

  N = @historyLength
  offset = N - 1 - (@history.length - 1)
  buildPoints = (samples, getValue) ->
    samples.map((s, i) -> "#{offset + i},#{100 - (getValue(s) / maxY * 100)}").join(" ")

  downPoints = buildPoints(@history, (s) -> s.down)
  upPoints   = buildPoints(@history, (s) -> s.up)
  $(domEl).find('.line-down').attr('points', downPoints)
  $(domEl).find('.line-up').attr('points',   upPoints)

  # Close each line into a polygon by dropping straight down to the baseline at
  # both ends — the fill becomes the area under the curve.
  lastX = offset + @history.length - 1
  $(domEl).find('.area-down').attr('points', "#{downPoints} #{lastX},100 #{offset},100")
  $(domEl).find('.area-up').attr('points',   "#{upPoints} #{lastX},100 #{offset},100")
  $(domEl).find('.peak-down').html "<span class='peak-arrow-down'>⬇</span> #{usage(peakDown)}"
  $(domEl).find('.peak-up').html   "#{usage(peakUp)} <span class='peak-arrow-up'>⬆</span>"
