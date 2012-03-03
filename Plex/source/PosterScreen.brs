'* Displays the content in a poster screen. Can be any content type.

Function createPosterScreen(item, viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)

    ' Standard properties for all our screen types
    obj.Item = item
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController
    obj.MessageHandler = invalid
    obj.MsgTimeout = 0

    obj.Show = showPosterScreen
    obj.ShowList = posterShowContentList
    obj.SetListStyle = posterSetListStyle

    obj.UseDefaultStyles = true
    obj.ListStyle = invalid
    obj.ListDisplayMode = invalid
    obj.FilterMode = invalid

    obj.OnDataLoaded = posterOnDataLoaded

    obj.styles = []

    return obj
End Function

Function showPosterScreen() As Integer
    ' Show a facade immediately to get the background 'retrieving' instead of
    ' using a one line dialog.
    facade = CreateObject("roPosterScreen")
    facade.Show()

    content = m.Item
    server = content.server

    container = createPlexContainerForUrl(server, content.sourceUrl, content.key)

    if m.FilterMode = invalid then m.FilterMode = container.ViewGroup = "secondary"
    if m.FilterMode then
        names = container.GetNames()
        keys = container.GetKeys()
    else
        names = []
        keys = []
    end if

    m.FilterMode = names.Count() > 0

    if m.FilterMode then
        m.Screen.SetListNames(names)
        m.Screen.SetFocusedList(0)
        m.Loader = createPaginatedLoader(container, 25, 25)
        m.Loader.Listener = m
        m.Loader.Port = m.Port
        m.MessageHandler = m.Loader

        for index = 0 to keys.Count() - 1
            style = CreateObject("roAssociativeArray")
            style.listStyle = invalid
            style.listDisplayMode = invalid
            m.styles[index] = style
        next

        m.Loader.LoadMoreContent(0, 0)
    else
        ' We already grabbed the full list, no need to bother with loading
        ' in chunks.

        m.Loader = createDummyLoader([container.GetMetadata()])

        style = CreateObject("roAssociativeArray")

        if container.Count() > 0 then
            contentType = container.GetMetadata()[0].ContentType
        else
            contentType = invalid
        end if

        if m.UseDefaultStyles then
            aa = getDefaultListStyle(container.ViewGroup, contentType)
            style.listStyle = aa.style
            style.listDisplayMode = aa.display
        else
            style.listStyle = m.ListStyle
            style.listDisplayMode = m.ListDisplayMode
        end if

        m.styles[0] = style
    end if

    focusedListItem = 0
    m.ShowList(focusedListItem)
    facade.Close()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roPosterScreenEvent" then
            '* Focus change on the filter bar causes content change
            if msg.isListFocused() then
                focusedListItem = msg.GetIndex()
                m.ShowList(focusedListItem)
                m.Loader.LoadMoreContent(focusedListItem, 0)
            else if msg.isListItemSelected() then
                index = msg.GetIndex()
                content = m.Loader.GetContent(focusedListItem)
                selected = content[index]
                contentType = selected.ContentType

                print "Content type in poster screen:";contentType

                if contentType = "series" OR NOT m.FilterMode then
                    breadcrumbs = [selected.Title]
                else
                    breadcrumbs = [names[index], selected.Title]
                end if

                m.ViewController.CreateScreenForItem(content, index, breadcrumbs)
            else if msg.isScreenClosed() then
                ' Make sure we don't have hang onto circular references
                m.Loader.Listener = invalid
                m.Loader = invalid
                m.MessageHandler = invalid

                m.ViewController.PopScreen(m)
                return -1
            end if
        end If
    end while
    return 0
End Function

Sub posterOnDataLoaded(row As Integer, data As Object, startItem as Integer, count As Integer)
    ' If this was the first content we loaded, set up the styles
    if startItem = 0 AND count > 0 then
        style = m.styles[row]
        if m.UseDefaultStyles then
            if data.Count() > 0 then
                aa = getDefaultListStyle(data[0].ViewGroup, data[0].contentType)
                style.listStyle = aa.style
                style.listDisplayMode = aa.display
            end if
        else
            style.listStyle = m.ListStyle
            style.listDisplayMode = m.ListDisplayMode
        end if
    end if

    m.ShowList(row, startItem = 0)

    ' Continue loading this row
    m.Loader.LoadMoreContent(row, 0)
End Sub

Sub posterShowContentList(index, focusFirstItem=true)
    content = m.Loader.GetContent(index)
    m.Screen.SetContentList(content)

    style = m.styles[index]
    if style.listStyle <> invalid then
        m.Screen.SetListStyle(style.listStyle)
    end if
    if style.listDisplayMode <> invalid then
        m.Screen.SetListDisplayMode(style.listDisplayMode)
    end if

    Print "Showing screen with "; content.Count(); " elements"
    Print "List style is "; style.listStyle; ", "; style.listDisplayMode

    m.Screen.Show()
    if focusFirstItem then m.Screen.SetFocusedListItem(0)
End Sub

Function getDefaultListStyle(viewGroup, contentType) As Object
    aa = CreateObject("roAssociativeArray")
    aa.style = "arced-square"
    aa.display = "scale-to-fit"

    if viewGroup = "episode" AND contentType = "episode" then
        aa.style = "flat-episodic"
        aa.display = "zoom-to-fill"
    else if viewGroup = "movie" OR viewGroup = "show" OR viewGroup = "season" OR viewGroup = "episode" then
        aa.style = "arced-portrait"
    end if

    return aa
End Function

Sub posterSetListStyle(style, displayMode)
    m.ListStyle = style
    m.ListDisplayMode = displayMode
    m.UseDefaultStyles = false
End Sub

