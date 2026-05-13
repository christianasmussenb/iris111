Class UI.StoreActionConsole Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
	Set %response.ContentType = "text/html; charset=utf-8"
	Do %response.Write(..BuildPageHtml())
	Quit $$$OK
}

ClassMethod BuildPageHtml() As %String
{
	Set html = ..ReadTextFile("/iris/frontend/index.html")
	If html = "" Quit "<!doctype html><html lang=""es""><head><meta charset=""utf-8""><title>IRIS111</title></head><body><p>UI unavailable.</p></body></html>"

	Set css = ..ReadTextFile("/iris/frontend/styles.css")
	Set js = ..ReadTextFile("/iris/frontend/app.js")
	Set html = $Replace(html, "<link rel=""stylesheet"" href=""./styles.css"" />", "<style>"_css_"</style>")
	Set html = $Replace(html, "<script src=""./app.js""></script>", "<script>"_js_"</script>")
	Quit html
}

ClassMethod ReadTextFile(filePath As %String) As %String
{
	Set stream = ##class(%Stream.FileCharacter).%New()
	Set sc = stream.LinkToFile(filePath)
	If $SYSTEM.Status.IsError(sc) Quit ""
	Set content = ""
	While 'stream.AtEnd {
		Set content = content _ stream.Read(32767)
	}
	Quit content
}

}