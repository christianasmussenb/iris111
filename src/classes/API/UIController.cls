Class API.UIController Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

XData UrlMap
{
<Routes>
    <Route Url="/health" Method="GET" Call="GetHealth" />
    <Route Url="/stores/:storeCode/categories/:categoryCode/pace" Method="GET" Call="GetPace" />
	<Route Url="/recommendations/pending/:storeCode" Method="GET" Call="GetRecommendationsPending" />
    <Route Url="/recommendations/:recommendationId/feedback" Method="POST" Call="PostFeedback" />
    <Route Url="/dashboard/store/:storeCode" Method="GET" Call="GetDashboard" />
	<Route Url="/ui" Method="GET" Call="GetUI" />
	<Route Url="/ui/index.html" Method="GET" Call="GetUI" />
	<Route Url="/ui/styles.css" Method="GET" Call="GetUIStyles" />
	<Route Url="/ui/app.js" Method="GET" Call="GetUIApp" />
</Routes>
}

ClassMethod GetHealth() As %Status
{
	Set data = ..BuildHealthData()
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod BuildHealthData() As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set data.status = "ok"
	Set data.timestamp = $ZDATETIME($HOROLOG, 3, 1)
	Set data.version = "iris111-api-1"
	Quit data
}

ClassMethod GetPace(storeCode As %String, categoryCode As %String) As %Status
{
	Set data = ..BuildPaceData(storeCode, categoryCode)
	Do ..AuditRequest("Gold.CategoryPace", storeCode _ "|" _ categoryCode, "READ_PACE", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod BuildPaceData(storeCode As %String, categoryCode As %String, paceDate As %Date = "", paceHour As %Integer = -1) As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set queryDate = $Select(paceDate'="":paceDate, 1:$P($HOROLOG, ",", 1))
	Set queryHour = $Select(paceHour>-1:paceHour, 1:+$Piece($ZTIME($HOROLOG, 3), ":", 1))

	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT PaceId, PaceDate, PaceHour, StoreCode, CategoryCode, UnitsSold, RevenueSold, UnitsBudget, RevenueBudget, UnitsCumulative, RevenueCumulative, PctPaceUnits, PctPaceRevenue, VarianceUnits, VarianceRevenue, LastUpdated FROM Gold.CategoryPace WHERE PaceDate = ? AND PaceHour = ? AND StoreCode = ? AND CategoryCode = ?")
	If $SYSTEM.Status.IsError(sc) Quit data
	Set rs = stmt.%Execute(queryDate, queryHour, storeCode, categoryCode)
	If rs.%Next() {
		Set data.paceId = rs.%GetData(1)
		Set data.paceDate = rs.%GetData(2)
		Set data.paceHour = rs.%GetData(3)
		Set data.storeCode = rs.%GetData(4)
		Set data.categoryCode = rs.%GetData(5)
		Set data.unitsSold = rs.%GetData(6)
		Set data.revenueSold = rs.%GetData(7)
		Set data.unitsBudget = rs.%GetData(8)
		Set data.revenueBudget = rs.%GetData(9)
		Set data.unitsCumulative = rs.%GetData(10)
		Set data.revenueCumulative = rs.%GetData(11)
		Set data.pctPaceUnits = rs.%GetData(12)
		Set data.pctPaceRevenue = rs.%GetData(13)
		Set data.varianceUnits = rs.%GetData(14)
		Set data.varianceRevenue = rs.%GetData(15)
		Set data.lastUpdated = rs.%GetData(16)
	} Else {
		Set data.error = "PACE_NOT_FOUND"
	}
	Quit data
}

ClassMethod GetRecommendationsPending(storeCode As %String) As %Status
{
	Set data = ..BuildPendingRecommendationsData(storeCode)
	Do ..AuditRequest("Ops.Recommendation", storeCode, "READ_PENDING_RECOMMENDATIONS", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod BuildPendingRecommendationsData(storeCode As %String) As %DynamicArray
{
	Set items = ##class(%DynamicArray).%New()
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT RecommendationId, StoreCode, CategoryCode, RuleFired, RuleWindowType, RuleThreshold, RuleObservedValue, RulePriority, RuleSeverity, BusinessMessage, ExecutionState, RelatedPaceId, ActionCode, ActionDescription, Status, TriggeredAt, AcceptedBy, AcceptedAt, ExecutedAt, EffectivenessScore, Notes FROM Ops.Recommendation WHERE StoreCode = ? AND Status = 'PENDING' ORDER BY TriggeredAt DESC")
	If $SYSTEM.Status.IsError(sc) Quit items
	Set rs = stmt.%Execute(storeCode)
	While rs.%Next() {
		Do items.%Push(..RecommendationRowToObject(rs))
	}
	Quit items
}

ClassMethod GetDashboard(storeCode As %String) As %Status
{
	Set data = ..BuildDashboardData(storeCode)
	Do ..AuditRequest("Gold.CategoryPace", storeCode, "READ_DASHBOARD", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod GetUI() As %Status
{
	Set %response.ContentType = "text/html; charset=utf-8"
	Do %response.Write(..BuildUIHtml())
	Quit $$$OK
}

ClassMethod GetUIStyles() As %Status
{
	Set %response.ContentType = "text/css; charset=utf-8"
	Do %response.Write(..ReadTextFile("/iris/frontend/styles.css"))
	Quit $$$OK
}

ClassMethod GetUIApp() As %Status
{
	Set %response.ContentType = "application/javascript; charset=utf-8"
	Do %response.Write(..ReadTextFile("/iris/frontend/app.js"))
	Quit $$$OK
}

ClassMethod BuildUIHtml() As %String
{
	Set html = ..ReadTextFile("/iris/frontend/index.html")
	If html = "" Quit "<!doctype html><html lang=""es""><head><meta charset=""utf-8""><title>IRIS111</title></head><body><p>UI unavailable.</p></body></html>"
	If html [ "<base href=""/api/ui/"" />" Quit html
	Set html = $Replace(html, "<head>", "<head><base href=""/api/ui/"" />", 1)
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

ClassMethod BuildDashboardData(storeCode As %String) As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set data.storeCode = storeCode
	Set data.date = $P($HOROLOG, ",", 1)
	Set data.categories = ##class(%DynamicArray).%New()
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT PaceId, PaceDate, PaceHour, StoreCode, CategoryCode, UnitsSold, RevenueSold, UnitsBudget, RevenueBudget, UnitsCumulative, RevenueCumulative, PctPaceUnits, PctPaceRevenue, VarianceUnits, VarianceRevenue, LastUpdated FROM Gold.CategoryPace WHERE PaceDate = ? AND StoreCode = ? ORDER BY CategoryCode, PaceHour")
	If $SYSTEM.Status.IsError(sc) Quit data
	Set rs = stmt.%Execute(data.date, storeCode)
	While rs.%Next() {
		Do data.categories.%Push(..PaceRowToObject(rs))
	}
	Quit data
}

ClassMethod PostFeedback(recommendationId As %String) As %Status
{
	Set feedbackStatus = $Get(%request.Data("status"))
	Set acceptedBy = $Get(%request.Data("acceptedBy"))
	Set notes = $Get(%request.Data("notes"))
	Set data = ..ApplyFeedback(recommendationId, feedbackStatus, acceptedBy, notes)
	Do ..AuditRequest("Ops.Recommendation", recommendationId, "UPDATE_FEEDBACK", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod ApplyFeedback(recommendationId As %String, feedbackStatus As %String, acceptedBy As %String = "", notes As %String = "") As %DynamicObject
{
	Set result = ##class(%DynamicObject).%New()
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID FROM Ops.Recommendation WHERE RecommendationId = ?")
	If $SYSTEM.Status.IsError(sc) {
		Set result.error = "RECOMMENDATION_QUERY_FAILED"
		Quit result
	}
	Set rs = stmt.%Execute(recommendationId)
	If 'rs.%Next() {
		Set result.error = "RECOMMENDATION_NOT_FOUND"
		Quit result
	}

	Set recommendation = ##class(Ops.Recommendation).%OpenId(rs.%GetData(1))
	If '$IsObject(recommendation) {
		Set result.error = "RECOMMENDATION_OPEN_FAILED"
		Quit result
	}

	Set beforeState = ..RecommendationToObject(recommendation)

	Set normalizedStatus = $ZCONVERT($Get(feedbackStatus), "U")
	If normalizedStatus = "" Set normalizedStatus = "PENDING"
	Set recommendation.Status = normalizedStatus
	Set recommendation.Notes = $Select(notes'="":notes, 1:recommendation.Notes)
	Set recommendation.ExecutionState = $Select(normalizedStatus = "ACCEPTED":"ACCEPTED", normalizedStatus = "REJECTED":"REJECTED", normalizedStatus = "MODIFIED":"MODIFIED", 1:recommendation.ExecutionState)
	If normalizedStatus = "ACCEPTED" {
		Set recommendation.AcceptedBy = acceptedBy
		Set recommendation.AcceptedAt = $ZDATETIME($HOROLOG, 3, 1)
	}
	If normalizedStatus = "MODIFIED" {
		Set recommendation.AcceptedBy = acceptedBy
		Set recommendation.AcceptedAt = $ZDATETIME($HOROLOG, 3, 1)
	}
	If normalizedStatus = "EXECUTED" {
		Set recommendation.ExecutedAt = $ZDATETIME($HOROLOG, 3, 1)
	}
	Set sc = recommendation.%Save()
	If $SYSTEM.Status.IsError(sc) {
		Set result.error = "RECOMMENDATION_SAVE_FAILED"
		Quit result
	}

	Set afterState = ..RecommendationToObject(recommendation)
	Set result.before = beforeState
	Set result.after = afterState
	Set result.saved = 1
	Quit result
}

ClassMethod RecommendationRowToObject(row As %SQL.StatementResult) As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set data.RecommendationId = row.%GetData(1)
	Set data.StoreCode = row.%GetData(2)
	Set data.CategoryCode = row.%GetData(3)
	Set data.RuleFired = row.%GetData(4)
	Set data.RuleWindowType = row.%GetData(5)
	Set data.RuleThreshold = row.%GetData(6)
	Set data.RuleObservedValue = row.%GetData(7)
	Set data.RulePriority = row.%GetData(8)
	Set data.RuleSeverity = row.%GetData(9)
	Set data.BusinessMessage = row.%GetData(10)
	Set data.ExecutionState = row.%GetData(11)
	Set data.RelatedPaceId = row.%GetData(12)
	Set data.ActionCode = row.%GetData(13)
	Set data.ActionDescription = row.%GetData(14)
	Set data.Status = row.%GetData(15)
	Set data.TriggeredAt = row.%GetData(16)
	Set data.AcceptedBy = row.%GetData(17)
	Set data.AcceptedAt = row.%GetData(18)
	Set data.ExecutedAt = row.%GetData(19)
	Set data.EffectivenessScore = row.%GetData(20)
	Set data.Notes = row.%GetData(21)
	Quit data
}

ClassMethod RecommendationToObject(recommendation As Ops.Recommendation) As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set data.RecommendationId = recommendation.RecommendationId
	Set data.StoreCode = recommendation.StoreCode
	Set data.CategoryCode = recommendation.CategoryCode
	Set data.RuleFired = recommendation.RuleFired
	Set data.RuleWindowType = recommendation.RuleWindowType
	Set data.RuleThreshold = recommendation.RuleThreshold
	Set data.RuleObservedValue = recommendation.RuleObservedValue
	Set data.RulePriority = recommendation.RulePriority
	Set data.RuleSeverity = recommendation.RuleSeverity
	Set data.BusinessMessage = recommendation.BusinessMessage
	Set data.ExecutionState = recommendation.ExecutionState
	Set data.RelatedPaceId = recommendation.RelatedPaceId
	Set data.ActionCode = recommendation.ActionCode
	Set data.ActionDescription = recommendation.ActionDescription
	Set data.Status = recommendation.Status
	Set data.TriggeredAt = recommendation.TriggeredAt
	Set data.AcceptedBy = recommendation.AcceptedBy
	Set data.AcceptedAt = recommendation.AcceptedAt
	Set data.ExecutedAt = recommendation.ExecutedAt
	Set data.EffectivenessScore = recommendation.EffectivenessScore
	Set data.Notes = recommendation.Notes
	Quit data
}

ClassMethod PaceRowToObject(row As %SQL.StatementResult) As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set data.PaceId = row.%GetData(1)
	Set data.PaceDate = row.%GetData(2)
	Set data.PaceHour = row.%GetData(3)
	Set data.StoreCode = row.%GetData(4)
	Set data.CategoryCode = row.%GetData(5)
	Set data.UnitsSold = row.%GetData(6)
	Set data.RevenueSold = row.%GetData(7)
	Set data.UnitsBudget = row.%GetData(8)
	Set data.RevenueBudget = row.%GetData(9)
	Set data.UnitsCumulative = row.%GetData(10)
	Set data.RevenueCumulative = row.%GetData(11)
	Set data.PctPaceUnits = row.%GetData(12)
	Set data.PctPaceRevenue = row.%GetData(13)
	Set data.VarianceUnits = row.%GetData(14)
	Set data.VarianceRevenue = row.%GetData(15)
	Set data.LastUpdated = row.%GetData(16)
	Quit data
}

ClassMethod AuditRequest(entityName As %String, entityId As %String, actionType As %String, beforeState As %String = "", afterState As %String = "", createdBy As %String = "API.UIController") As %Status
{
	Set audit = ##class(Ops.AuditLog).%New()
	Set audit.EventId = $SYSTEM.Util.CreateGUID()
	Set audit.EntityName = entityName
	Set audit.EntityId = entityId
	Set audit.ActionType = actionType
	Set audit.BeforeState = beforeState
	Set audit.AfterState = afterState
	Set audit.CreatedAt = $ZDATETIME($HOROLOG, 3, 1)
	Set audit.CreatedBy = createdBy
	Quit audit.%Save()
}

ClassMethod WriteJson(payload) As %Status
{
	Set %response.ContentType = "application/json"
	Do %response.Write(payload.%ToJSON())
	Quit $$$OK
}

}
