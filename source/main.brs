' ********************************************************************
' ********************************************************************
' **  Roku NPO Nederland 1 Channel (BrightScript)
' **
' **  Dec 2013
' **  Copyright (c) 2010 Roku Inc. All Rights Reserved.
' ********************************************************************
' ********************************************************************

Sub RunUserInterface()
    o = Setup()
    o.setup()
    o.paint()
    o.eventloop()
End Sub

Sub Setup() As Object
    this = {
        port:      CreateObject("roMessagePort")
        progress:  0 'buffering progress
        paused:    false 'is the video currently paused?
        fonts:     CreateObject("roFontRegistry") 'global font registry
        canvas:    CreateObject("roImageCanvas") 'user interface
        player:    CreateObject("roVideoPlayer")
        setup:     SetupFramedCanvas
        paint:     PaintFramedCanvas
        overlay:      false
        eventloop: EventLoop
    }

    'Static help text:
    this.help = ""

    'Register available fonts:
    this.textcolor = "#fff"
    this.alttextcolor = "#DF2726"
    this.orange = "#FF6D00"
    this.gray = "#A2A2A2"

    'Setup image canvas:
    this.canvas.SetMessagePort(this.port)
    this.canvas.SetLayer(0, { Color: "#000000" })
    this.canvas.Show()

    'Resolution-specific settings:
    mode = CreateObject("roDeviceInfo").GetDisplayMode()
    if mode = "720p"
        this.layout = {
            full:   this.canvas.GetCanvasRect()
            top:    { x:   0, y:   0, w:1280, h: 130 }
            left:   { x: 150, y: 190, w: 622, h: 350 }
            right:  { x: 800, y: 227, w: 350, h: 291 }
            bottom: { x: 249, y: 630, w: 780, h: 100 }
        }
        this.background = "pkg:/images/back-hd.jpg"
    else
        this.layout = {
            full:   this.canvas.GetCanvasRect()
            top:    { x:   0, y:   0, w: 720, h:  80 }
            left:   { x: 90, y: 130, w: 320, h: 211 }
            right:  { x: 400, y: 100, w: 220, h: 210 }
            bottom: { x: 100, y: 340, w: 520, h: 140 }
        }
        this.background = "pkg:/images/back-sd.jpg"
    end if

    this.player.SetMessagePort(this.port)
    this.player.SetLoop(true)
    this.player.SetPositionNotificationPeriod(1)
    this.player.SetDestinationRect(this.layout.left)

    jsonRequest = CreateObject("roUrlTransfer")
    jsonRequest.SetURL("http://ida.omroep.nl/aapi/?stream=http://livestreams.omroep.nl/live/npo/tvlive/ned1/ned1.isml/ned1.m3u8")
    response = ParseJson(jsonRequest.GetToString())

    streamURL = response.stream

    this.player.SetContentList([{
        Stream: { url: streamURL }
        StreamFormat: "hls"
        SwitchingStrategy: "full-adaptation"
    }])
    this.player.Play()

    return this
End Sub

Sub EventLoop()
    while true
        msg = wait(0, m.port)
        if msg <> invalid
            'If this is a startup progress status message, record progress
            'and update the UI accordingly:
            if msg.isStatusMessage() and msg.GetMessage() = "startup progress"
                m.paused = false
                progress% = msg.GetIndex() / 10
                if m.progress <> progress%
                    m.progress = progress%
                    m.paint()
                end if

            'Playback progress (in seconds):

            'If the <UP> key is pressed, jump out of this context:
            else if msg.isRemoteKeyPressed()
                index = msg.GetIndex()
                print "Remote button pressed: " + index.tostr()
                if index = 4 '<left>
                    return
                else if index = 3 '<DOWN> (toggle fullscreen)
                    if m.paint = PaintFullscreenCanvas
                        m.setup = SetupFramedCanvas
                        m.paint = PaintFramedCanvas
                        rect = m.layout.left
                    else
                        m.setup = SetupFullscreenCanvas
                        m.paint = PaintFullscreenCanvas
                        rect = { x:0, y:0, w:0, h:0 } 'fullscreen
                        m.player.SetDestinationRect(0, 0, 0, 0) 'fullscreen
                    end if
                    m.setup()
                    m.player.SetDestinationRect(rect)
                else if index = 2 '<UP>
                    if m.overlay = true
                        m.overlay = false
                    else
                        m.overlay = true
                    end if
                    m.setup()
                else if index = 13  '<PAUSE/PLAY>
                    if m.paused m.player.Resume() else m.player.Pause()
                end if

            else if msg.isPaused()
                m.paused = true
                m.paint()

            else if msg.isResumed()
                m.paused = false
                m.paint()

            end if
            'Output events for debug
            print msg.GetType(); ","; msg.GetIndex(); ": "; msg.GetMessage()
            if msg.GetInfo() <> invalid print msg.GetInfo();
        end if
    end while
End Sub

Sub SetupFullscreenCanvas()
    m.canvas.AllowUpdates(false)
    m.paint()
    m.canvas.AllowUpdates(true)
End Sub

Sub PaintFullscreenCanvas()

    jsonRequest = CreateObject("roUrlTransfer")
    jsonRequest.SetURL("http://nltvnow.herokuapp.com/now")
    response = ParseJson(jsonRequest.GetToString())
    title = response.NED1[0].title

    list = []
    mode = CreateObject("roDeviceInfo").GetDisplayMode()
    if m.progress < 100
        color = "#000000" 'opaque black
        list.Push({
            Text: "Laden..." + m.progress.tostr() + "%"
            TextAttrs: { font: "huge" }
            TargetRect: m.layout.full
        })
    else if m.overlay
        color = "#00000000" 'transparent black
        if mode = "720p"
            list.Push({
                url: "pkg:/images/header_overlay.png"
                TargetRect: { x: 0, y: 0, w: 1280, h: 122 }
            })
            list.Push({
                url: "pkg:/images/logo_channel.png"
                TargetRect: { x: 26, y: 18, w: 89, h: 89 }
            })
            list.Push({
                Text: "Nu"
                TextAttrs: { font: "medium", halign: "left", valign: "center", color: m.textcolor }
                TargetRect: { x: 153, y: 0, w: 50, h: 122 }
            })
            list.Push({
                Text: title
                TextAttrs: { font: "medium", halign: "left", valign: "center", color: m.alttextcolor }
                TargetRect: { x: 193, y: 0, w: 954, h: 122 }
            })
            if m.paused
                color = "#80000000" 'semi-transparent black
                list.Push({
                    url: "pkg:/images/pause_icon_large.png"
                    TargetRect: { x: 580, y: 300, w: 120, h: 120 }
                })
            end if
        else
            list.Push({
                url: "pkg:/images/header_overlay.png"
                TargetRect: { x: 0, y: 0, w: 720, h: 81 }
            })
            list.Push({
                url: "pkg:/images/logo_channel.png"
                TargetRect: { x: 17, y: 12, w: 58, h: 58 }
            })
            list.Push({
                Text: "Nu"
                TextAttrs: { font: "medium", halign: "left", valign: "center", color: m.textcolor }
                TargetRect: { x: 101, y: 0, w: 30, h: 81 }
            })
            list.Push({
                Text: title
                TextAttrs: { font: "medium", halign: "left", valign: "center", color: m.alttextcolor }
                TargetRect: { x: 131, y: 0, w: 589, h: 81 }
            })
            if m.paused
                color = "#80000000" 'semi-transparent black
                list.Push({
                    url: "pkg:/images/pause_icon_large.png"
                    TargetRect: { x: 325, y: 205, w: 70, h: 70 }
                })
            end if
        end if
    else if m.paused
        color = "#80000000" 'semi-transparent black
        if mode = "720p"
            list.Push({
                url: "pkg:/images/pause_icon_large.png"
                TargetRect: { x: 580, y: 300, w: 120, h: 120 }
            })
        else
            list.Push({
                url: "pkg:/images/pause_icon_large.png"
                TargetRect: { x: 325, y: 205, w: 70, h: 70 }
            })
        end if
    else
        color = "#00000000" 'fully transparent
    end if

    m.canvas.SetLayer(0, { Color: color, CompositionMode: "Source" })
    m.canvas.SetLayer(1, list)
End Sub


Sub SetupFramedCanvas()
    m.canvas.AllowUpdates(false)
    m.canvas.Clear()
    m.canvas.SetLayer(0, [
        { 'Background:
            Url: m.background
            CompositionMode: "Source"
        },
        { 'Help text:
            Text: m.help
            TargetRect: m.layout.right
            TextAttrs: { halign: "left", valign: "center", color: m.textcolor }
        }
    ])
    m.paint()
    m.canvas.AllowUpdates(true)
End Sub

Sub PaintFramedCanvas()
    jsonRequest = CreateObject("roUrlTransfer")
    jsonRequest.SetURL("http://nltvnow.herokuapp.com/now")
    guide = ParseJson(jsonRequest.GetToString())

    list = []
    mode = CreateObject("roDeviceInfo").GetDisplayMode()
    if m.progress < 100  'Video is aan het laden...
        list.Push({
            Color: "#80000000"
            TargetRect: m.layout.left
        })
        list.Push({
            Text: "Laden..." + m.progress.tostr() + "%"
            TargetRect: m.layout.left
        })
    else  'Video is currently playing
        if m.paused
            list.Push({
                Color: "#80000000"
                TargetRect: m.layout.left
                CompositionMode: "Source"
            })
            if mode = "720p"
                list.Push({
                    url: "pkg:/images/pause_icon_small.png"
                    TargetRect: { x: 430, y: 334, w: 61, h: 61 }
                })
            else
                list.Push({
                    url: "pkg:/images/pause_icon_small.png"
                    TargetRect: { x: 230, y: 214, w: 40, h: 40 }
                })
            end if
        else if m.overlay
            list.Push({
                Color: "#00000000"
                TargetRect: m.layout.left
                CompositionMode: "Source"
            })
        else  'not paused
            list.Push({
                Color: "#00000000"
                TargetRect: m.layout.left
                CompositionMode: "Source"
            })
        end if
        if mode = "720p"
            list.Push({
                Text: "Nu"
                TargetRect: { x: 859, y: 200, w: 70, h: 80 }
                TextAttrs: { font: "small", halign: "right", valign: "center", color: m.orange }
            })
            list.Push({
                Text: guide.NED1[0].title
                TargetRect: { x: 951, y: 200, w: 250, h: 80 }
                TextAttrs: { font: "small", halign: "left", valign: "center", color: m.textcolor }
            })
            list.Push({
                Text: guide.NED1[1].start_time
                TargetRect: { x: 859, y: 300, w: 70, h: 80 }
                TextAttrs: { font: "small", halign: "right", valign: "center", color: m.gray }
            })
            list.Push({
                Text: guide.NED1[1].title
                TargetRect: { x: 951, y: 300, w: 250, h: 80 }
                TextAttrs: { font: "small", halign: "left", valign: "center", color: m.gray }
            })
            list.Push({
                Text: guide.NED1[2].start_time
                TargetRect: { x: 859, y: 400, w: 70, h: 80 }
                TextAttrs: { font: "small", halign: "right", valign: "center", color: m.gray }
            })
            list.Push({
                Text: guide.NED1[2].title
                TargetRect: { x: 951, y: 400, w: 250, h: 80 }
                TextAttrs: { font: "small", halign: "left", valign: "center", color: m.gray }
            })
        else
            list.Push({
                Text: "Nu"
                TargetRect: { x: 443, y: 132, w: 50, h: 55 }
                TextAttrs: { font: "s", halign: "right", valign: "center", color: m.orange }
            })
            list.Push({
                Text: guide.NED1[0].title
                TargetRect: { x: 499, y: 132, w: 193, h: 55 }
                TextAttrs: { font: "s", halign: "left", valign: "center", color: m.textcolor }
            })
            list.Push({
                Text: guide.NED1[1].start_time
                TargetRect: { x: 443, y: 193, w: 50, h: 55 }
                TextAttrs: { font: "s", halign: "right", valign: "center", color: m.gray }
            })
            list.Push({
                Text: guide.NED1[1].title
                TargetRect: { x: 499, y: 193, w: 193, h: 55 }
                TextAttrs: { font: "s", halign: "left", valign: "center", color: m.gray }
            })
            list.Push({
                Text: guide.NED1[2].start_time
                TargetRect: { x: 443, y: 254, w: 50, h: 55 }
                TextAttrs: { font: "s", halign: "right", valign: "center", color: m.gray }
            })
            list.Push({
                Text: guide.NED1[2].title
                TargetRect: { x: 499, y: 254, w: 193, h: 55 }
                TextAttrs: { font: "s", halign: "left", valign: "center", color: m.gray }
            })
        end if
    end if
    m.canvas.SetLayer(1, list)
End Sub
