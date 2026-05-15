Class Service.POSReplayBatch
{

ClassMethod Run(mode As %String = "dry-run") As %Status
{
	Set normalizedMode = $ZCONVERT($ZSTRIP(mode, "<>", " "), "U")
	If normalizedMode = "" Set normalizedMode = "DRY-RUN"
	If normalizedMode'="DRY-RUN", normalizedMode'="APPLY" Quit $SYSTEM.Status.Error(5001, "Batch mode must be dry-run or apply")

	Set apply = normalizedMode = "APPLY"
	Set phase = $Select(apply: "apply", 1: "dry-run")

	Write !, "POS replay batch mode: ", phase, !

	Set status = ..CorrectBronzePayloadTimestamps(apply, .bronzeInspected, .bronzeChanged, .bronzeUnchanged)
	If $SYSTEM.Status.IsError(status) Quit status

	Set status = ..GetDerivedRowCounts(.silverCount, .goldCount)
	If $SYSTEM.Status.IsError(status) Quit status

	If apply {
		Set status = ..DeleteDerivedRows()
		If $SYSTEM.Status.IsError(status) Quit status

		Set status = ..ReplayBronzeEvents(.replayedCount)
		If $SYSTEM.Status.IsError(status) Quit status
	} Else {
		Set replayedCount = bronzeInspected
	}

	Write !, "bronze_inspected=", bronzeInspected, !
	Write !, "bronze_changed=", bronzeChanged, !
	Write !, "bronze_unchanged=", bronzeUnchanged, !
	Write !, "silver_rows=", silverCount, !
	Write !, "gold_rows=", goldCount, !
	Write !, "bronze_replay_count=", replayedCount, !
	Write !, "phase_complete=", phase, !
	Quit $$$OK
}

ClassMethod CorrectBronzePayloadTimestamps(apply As %Boolean, Output inspectedCount As %Integer, Output changedCount As %Integer, Output unchangedCount As %Integer) As %Status
{
	Set inspectedCount = 0
	Set changedCount = 0
	Set unchangedCount = 0
	Set returnStatus = $$$OK

	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID, SourceId, ReceivedAt, Payload FROM Bronze.POSEvent ORDER BY ReceivedAt, SourceId")
	If $SYSTEM.Status.IsError(sc) Quit sc

	Set rs = stmt.%Execute()
	While rs.%Next() {
		If returnStatus '= 1 {
			Continue
		}

		Set inspectedCount = inspectedCount + 1
		Set bronzeRowId = rs.%GetData(1)
		Set sourceId = rs.%GetData(2)
		Set receivedAt = rs.%GetData(3)
		Set payloadText = rs.%GetData(4)

		Set payload = ##class(%DynamicObject).%FromJSON(payloadText)
		If '$IsObject(payload) {
			Set returnStatus = $SYSTEM.Status.Error(5001, "Invalid Bronze payload JSON for source " _ sourceId)
			Continue
		}

		Set currentTimestamp = payload.%Get("timestamp")
		If currentTimestamp '= receivedAt {
			Set changedCount = changedCount + 1
			If apply {
				Set payload.timestamp = receivedAt
				Set event = ##class(Bronze.POSEvent).%OpenId(bronzeRowId)
				If '$IsObject(event) {
					Set returnStatus = $SYSTEM.Status.Error(5001, "Unable to open Bronze.POSEvent row " _ bronzeRowId)
					Continue
				}
				Set event.Payload = payload.%ToJSON()
				Set sc = event.%Save()
				If $SYSTEM.Status.IsError(sc) {
					Set returnStatus = sc
					Continue
				}
			}
		} Else {
			Set unchangedCount = unchangedCount + 1
		}
	}

	Quit returnStatus
}

ClassMethod GetDerivedRowCounts(Output silverCount As %Integer, Output goldCount As %Integer) As %Status
{
	Set silverCount = ..CountRows("SELECT COUNT(*) FROM Silver.Sale")
	Set goldCount = ..CountRows("SELECT COUNT(*) FROM Gold.SalesCadence")
	Quit $$$OK
}

ClassMethod CountRows(sql As %String) As %Integer
{
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare(sql)
	If $SYSTEM.Status.IsError(sc) Quit 0
	Set rs = stmt.%Execute()
	If 'rs.%Next() Quit 0
	Quit +rs.%GetData(1)
}

ClassMethod DeleteDerivedRows() As %Status
{
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("DELETE FROM Silver.Sale")
	If $SYSTEM.Status.IsError(sc) Quit sc
	Do stmt.%Execute()

	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("DELETE FROM Gold.SalesCadence")
	If $SYSTEM.Status.IsError(sc) Quit sc
	Do stmt.%Execute()

	Quit $$$OK
}

ClassMethod ReplayBronzeEvents(Output replayedCount As %Integer) As %Status
{
	Set replayedCount = 0
	Set returnStatus = $$$OK

	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID, SourceId, SourceChannel, Payload FROM Bronze.POSEvent ORDER BY ReceivedAt, SourceId")
	If $SYSTEM.Status.IsError(sc) Quit sc

	Set rs = stmt.%Execute()
	While rs.%Next() {
		If returnStatus '= 1 {
			Continue
		}

		Set replayedCount = replayedCount + 1
		Set bronzeId = rs.%GetData(2)
		Set payload = rs.%GetData(4)

		Set status = ##class(Process.POSProcessingBPL).NormalizeSale(payload, bronzeId, .saleId, .storeCode, .categoryCode, .internalSKU, .saleDate, .saleHour, .quantity, .unitPrice, .lineTotal)
		If $SYSTEM.Status.IsError(status) {
			Set returnStatus = status
			Continue
		}

		Set status = ##class(Process.POSProcessingBPL).UpdateCadence(storeCode, categoryCode, internalSKU, saleDate, saleHour, quantity, lineTotal, .paceId, .unitsBudget, .revenueBudget, .unitsCumulative, .revenueCumulative, .varianceUnits)
		If $SYSTEM.Status.IsError(status) {
			Set returnStatus = status
			Continue
		}
	}

	Quit returnStatus
}

}