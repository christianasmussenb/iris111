Class Service.POSEventService
{

Include %occStatus

ClassMethod Ingest(payload As %String, sourceChannel As %String = "REST") As %Status
{
	If payload = "" {
		Quit $$$ERROR($$$GeneralError, "POS payload is required")
	}

	If ..IsLikelyJson(payload)=0 {
		Quit $$$ERROR($$$GeneralError, "POS payload must be JSON-like")
	}

	Set event = ##class(Bronze.POSEvent).%New()
	Set event.SourceId = $SYSTEM.Util.CreateGUID()
	Set event.ReceivedAt = $ZDATETIME($HOROLOG, 3, 1)
	Set event.SourceChannel = sourceChannel
	Set event.Payload = payload

	Set status = event.%Save()
	Quit status
}

ClassMethod IsLikelyJson(payload As %String) As %Boolean
{
	Set trimmed = $ZSTRIP(payload, "<>", " ")
	If trimmed = "" {
		Quit 0
	}

	Quit ($Extract(trimmed, 1) = "{" && $Extract(trimmed, $Length(trimmed)) = "}") || ($Extract(trimmed, 1) = "[" && $Extract(trimmed, $Length(trimmed)) = "]")
}

}
