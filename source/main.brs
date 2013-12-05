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
            left:   { x: 150, y: 197, w: 622, h: 350 }
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
    list = []
    if m.progress < 100
        color = "#000000" 'opaque black
        list.Push({
            Text: "Laden..." + m.progress.tostr() + "%"
            TextAttrs: { font: "huge" }
            TargetRect: m.layout.full
        })
    else if m.overlay
        color = "#00000000" 'transparent black
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
            Text: "NOS Journaal"
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
    else if m.paused
        color = "#80000000" 'semi-transparent black
        list.Push({
            url: "pkg:/images/pause_icon_large.png"
            TargetRect: { x: 580, y: 300, w: 120, h: 120 }
        })
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
    list = []
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
            list.Push({
                url: "pkg:/images/pause_icon_small.png"
                TargetRect: { x: 430, y: 341, w: 61, h: 61 }
            })
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
        list.Push({
            Text: "Nu"
            TargetRect: { x: 919, y: 271, w: 50, h: 35 }
            TextAttrs: { font: "s", halign: "right", valign: "center", color: m.textcolor }
        })
        list.Push({
            Text: "Lingo (TROS)"
            TargetRect: { x: 981, y: 271, w: 210, h: 35 }
            TextAttrs: { font: "s", halign: "left", valign: "center", color: m.orange }
        })
        list.Push({
            Text: "19:27"
            TargetRect: { x: 919, y: 306, w: 50, h: 35 }
            TextAttrs: { font: "s", halign: "right", valign: "center", color: m.gray }
        })
        list.Push({
            Text: "Een huis vol (NCRV)"
            TargetRect: { x: 981, y: 306, w: 210, h: 35 }
            TextAttrs: { font: "s", halign: "left", valign: "center", color: m.gray }
        })
        list.Push({
            Text: "Nu"
            TargetRect: { x: 919, y: 366, w: 50, h: 35 }
            TextAttrs: { font: "s", halign: "right", valign: "center", color: m.textcolor }
        })
        list.Push({
            Text: "Lingo (TROS)"
            TargetRect: { x: 981, y: 366, w: 210, h: 35 }
            TextAttrs: { font: "s", halign: "left", valign: "center", color: m.orange }
        })
        list.Push({
            Text: "19:27"
            TargetRect: { x: 919, y: 401, w: 50, h: 35 }
            TextAttrs: { font: "s", halign: "right", valign: "center", color: m.gray }
        })
        list.Push({
            Text: "Een huis vol (NCRV)"
            TargetRect: { x: 981, y: 401, w: 210, h: 35 }
            TextAttrs: { font: "s", halign: "left", valign: "center", color: m.gray }
        })
        list.Push({
            Text: "Nu"
            TargetRect: { x: 919, y: 461, w: 50, h: 35 }
            TextAttrs: { font: "s", halign: "right", valign: "center", color: m.textcolor }
        })
        list.Push({
            Text: "Lingo (TROS)"
            TargetRect: { x: 981, y: 461, w: 210, h: 35 }
            TextAttrs: { font: "s", halign: "left", valign: "center", color: m.orange }
        })
        list.Push({
            Text: "19:27"
            TargetRect: { x: 919, y: 496, w: 50, h: 35 }
            TextAttrs: { font: "s", halign: "right", valign: "center", color: m.gray }
        })
        list.Push({
            Text: "Een huis vol (NCRV)"
            TargetRect: { x: 981, y: 496, w: 210, h: 35 }
            TextAttrs: { font: "s", halign: "left", valign: "center", color: m.gray }
        })
    end if
    m.canvas.SetLayer(1, list)
End Sub