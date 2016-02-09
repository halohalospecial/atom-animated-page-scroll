{CompositeDisposable} = require 'atom'
TweenMax = require 'gsap'

module.exports = AnimatedPageScroll =
  config:
    scrollDuration:
      type: 'number'
      default: 0.2
      minimum: 0
      maximum: 1
      description: 'Scroll duration in seconds.'
      order: 1

  activate: (state) ->
    @animations = {}
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'animated-page-scroll:page-up': => @pageUp()
      'animated-page-scroll:page-down': => @pageDown()

  deactivate: ->
    @subscriptions.dispose()
    for _, animation of @animations
      animation.onDidChangeCursorPositionSubscription?.dispose()
      animation.tween.kill()
    @animations = {}

  serialize: ->

  pageUp: ->
    @scrollPage -1

  pageDown: ->
    console.log 'pageDown' # # #
    @scrollPage 1

  scrollPage: (direction) ->
    editor = atom.workspace.getActiveTextEditor()
    # numRowsToScroll can be positive or negative depending on the direction.
    numRowsToScroll = (@animations[editor.id]?.numRowsToScroll || 0) + (editor.getRowsPerPage() * direction)
    targetScroll = {top: editor.getLineHeightInPixels() * (editor.getCursorScreenPosition().row - 2 + numRowsToScroll)}

    if @animations[editor.id]
      # If an animation was already started for the editor, update the tween target.
      @animations[editor.id].numRowsToScroll = numRowsToScroll
      @animations[editor.id].tween.updateTo targetScroll, true

    else
      editorView = atom.views.getView(editor)
      scroller = {top: editorView.getScrollTop()}

      @animations[editor.id] =
        # Stop animation when a cursor was moved.
        onDidChangeCursorPositionSubscription: editor.onDidChangeCursorPosition (_) =>
          @stopAnimation @animations[editor.id]

        numRowsToScroll: numRowsToScroll

        tween: TweenMax.to scroller, @getScrollDuration(),
          top: targetScroll.top
          ease: Power2.easeOut

          onUpdate: =>
            editorView.setScrollTop scroller.top

            # Stop animation upon scrolling to the top or bottom.
            animation = @animations[editor.id]
            if (animation.numRowsToScroll < 0 && editorView.getScrollTop() <= 0) || (animation.numRowsToScroll > 0 && editorView.getScrollBottom() >= editor.getLineHeightInPixels() * editor.getScreenLineCount())
              @stopAnimation animation

          onComplete: =>
            @animations[editor.id].onDidChangeCursorPositionSubscription.dispose()
            editor.moveDown @animations[editor.id].numRowsToScroll
            delete @animations[editor.id]

  stopAnimation: (animation) ->
    animation.tween.seek animation.tween.duration(), false

  getScrollDuration: ->
    atom.config.get('animated-page-scroll.scrollDuration')
