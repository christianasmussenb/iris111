Class API.UIController Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

XData UrlMap
{
<Routes>
	<Route Url="/" Method="GET" Call="GetUI" />
	<Route Url="/index.html" Method="GET" Call="GetUI" />
	<Route Url="/styles.css" Method="GET" Call="GetUIStyles" />
	<Route Url="/app.js" Method="GET" Call="GetUIApp" />
    <Route Url="/health" Method="GET" Call="GetHealth" />
	<Route Url="/budget/context/:storeCode/:categoryCode" Method="GET" Call="GetBudgetContext" />
	<Route Url="/budgets" Method="GET" Call="GetBudgets" />
	<Route Url="/budgets" Method="POST" Call="PostBudget" />
	<Route Url="/pos/ingest" Method="POST" Call="PostPOSIngest" />
    <Route Url="/stores/:storeCode/categories/:categoryCode/pace" Method="GET" Call="GetPace" />
	<Route Url="/recommendations/pending/:storeCode" Method="GET" Call="GetRecommendationsPending" />
    <Route Url="/recommendations/:recommendationId/feedback" Method="POST" Call="PostFeedback" />
	<Route Url="/recommendations/:recommendationId/feedback/:decision/:acceptedBy/:notes" Method="POST" Call="PostFeedbackDetails" />
	<Route Url="/recommendations/:recommendationId/feedback/:decision" Method="POST" Call="PostFeedbackDecision" />
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

ClassMethod PostPOSIngest() As %Status
{
	Set body = ..ReadRequestBody()
	Set result = ##class(%DynamicObject).%New()

	If body = "" {
		Set %response.Status = 400
		Set result.status = "error"
		Set result.error = "POS payload is required"
		Do ..WriteJson(result)
		Quit $$$OK
	}

	Set payload = ##class(%DynamicObject).%FromJSON(body)
	If '$IsObject(payload) {
		Set %response.Status = 400
		Set result.status = "error"
		Set result.error = "Invalid POS payload JSON"
		Do ..WriteJson(result)
		Quit $$$OK
	}

	Set status = ##class(Process.POSProcessingBPL).HandlePayload(body, "REST")
	If $SYSTEM.Status.IsError(status) {
		Set %response.Status = 400
		Set result.status = "error"
		Set result.error = $SYSTEM.Status.GetErrorText(status)
		Set result.sourceId = payload.%Get("source_id")
		Do ..WriteJson(result)
		Quit $$$OK
	}

	Set result.status = "ok"
	Set result.message = "POS mock ingested and processed"
	Set result.sourceId = payload.%Get("source_id")
	Set result.storeCode = payload.%Get("store_code")
	Set result.categoryCode = payload.%Get("category_code")
	Set result.timestamp = payload.%Get("timestamp")
	Set result.internalSku = payload.%Get("internal_sku")
	Set result.qty = +payload.%Get("qty")
	Set result.price = +payload.%Get("price")
	Do ..WriteJson(result)
	Quit $$$OK
}

ClassMethod GetBudgetContext(storeCode As %String, categoryCode As %String) As %Status
{
	Set data = ..BuildBudgetContextData(storeCode, categoryCode)
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod GetBudgets() As %Status
{
	Set budgetDate = $Get(%request.Data("budgetDate"))
	If budgetDate = "" Set budgetDate = $Get(%request.Data("budget_date"))
	Set storeCode = $Get(%request.Data("storeCode"))
	If storeCode = "" Set storeCode = $Get(%request.Data("store_code"))
	Set categoryCode = $Get(%request.Data("categoryCode"))
	If categoryCode = "" Set categoryCode = $Get(%request.Data("category_code"))
	Set internalSKU = $Get(%request.Data("internalSku"))
	If internalSKU = "" Set internalSKU = $Get(%request.Data("internal_sku"))
	Set data = ..BuildBudgetsData(budgetDate, storeCode, categoryCode, internalSKU)
	Do ..AuditRequest("MD.SalesBudget", "LIST", "READ_BUDGETS", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod PostBudget() As %Status
{
	Set body = ..ReadRequestBody()
	Set result = ##class(%DynamicObject).%New()

	If body = "" {
		Set %response.Status = 400
		Set result.status = "error"
		Set result.error = "Budget payload is required"
		Do ..WriteJson(result)
		Quit $$$OK
	}

	Set payload = ##class(%DynamicObject).%FromJSON(body)
	If '$IsObject(payload) {
		Set %response.Status = 400
		Set result.status = "error"
		Set result.error = "Invalid budget payload JSON"
		Do ..WriteJson(result)
		Quit $$$OK
	}

	Set status = ..SaveBudgetPayload(payload, .result)
	If $SYSTEM.Status.IsError(status) {
		Set %response.Status = 400
		Set result.status = "error"
		If result.error = "" Set result.error = $SYSTEM.Status.GetErrorText(status)
		Do ..WriteJson(result)
		Quit $$$OK
	}

	Do ..WriteJson(result)
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
	Set sc = stmt.%Prepare("SELECT RecommendationId, StoreCode, CategoryCode, RuleFired, RuleWindowType, RuleThreshold, RuleObservedValue, RulePriority, RuleSeverity, BusinessMessage, ExecutionState, RelatedPaceId, ActionCode, ActionDescription, Status, TriggeredAt, AcceptedBy, AcceptedAt, ExecutedAt, EffectivenessScore, Notes FROM Ops.Recommendation WHERE StoreCode = ? AND Status = 'PENDING' AND ExecutionState = 'NEW' ORDER BY TriggeredAt DESC")
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
	Write ..BuildUIHtml()
	Quit $$$OK
}

ClassMethod GetUIStyles() As %Status
{
	Set %response.ContentType = "text/css; charset=utf-8"
	Write ..ReadTextFile("/iris/frontend/styles.css")
	Quit $$$OK
}

ClassMethod GetUIApp() As %Status
{
	Set %response.ContentType = "application/javascript; charset=utf-8"
	Write ..ReadTextFile("/iris/frontend/app.js")
	Quit $$$OK
}

ClassMethod BuildUIHtml() As %String
{
	Set html = ..ReadTextFile("/iris/frontend/index.html")
	If html = "" Quit "<!doctype html><html lang=""es""><head><meta charset=""utf-8""><title>IRIS111</title></head><body><p>UI unavailable.</p></body></html>"
	If html [ "<base href=""/csp/store-console/"" />" Quit html
	Set html = $Replace(html, "<head>", "<head><base href=""/csp/store-console/"" />", 1)
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

ClassMethod ReadRequestBody() As %String
{
	Set content = ""
	While '(%request.Content.AtEnd) {
		Set content = content _ %request.Content.Read(32767)
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

ClassMethod BuildBudgetContextData(storeCode As %String, categoryCode As %String) As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set data.storeCode = storeCode
	Set data.categoryCode = categoryCode
	Set data.timestamp = $ZDATETIME($HOROLOG, 3, 1)
	Set data.budgetDate = ""
	Set data.targetUnits = 0
	Set data.targetRevenue = 0

	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT BudgetDate, TargetUnits, TargetRevenue FROM MD.SalesBudget WHERE StoreCode = ? AND CategoryCode = ? AND (InternalSKU IS NULL OR InternalSKU = '') ORDER BY BudgetDate DESC")
	If $SYSTEM.Status.IsError(sc) Quit data
	Set rs = stmt.%Execute(storeCode, categoryCode)
	If rs.%Next() {
		Set data.budgetDate = $ZDATE(rs.%GetData(1), 3)
		Set data.targetUnits = rs.%GetData(2)
		Set data.targetRevenue = rs.%GetData(3)
	}
	Quit data
}

ClassMethod BuildBudgetsData(budgetDate As %String = "", storeCode As %String = "", categoryCode As %String = "", internalSKU As %String = "") As %DynamicArray
{
	Set items = ##class(%DynamicArray).%New()

	Set stmt = ##class(%SQL.Statement).%New()
	Set sql = "SELECT %ID, BudgetDate, StoreCode, CategoryCode, InternalSKU, TargetUnits, TargetRevenue, LoadedAt FROM MD.SalesBudget ORDER BY BudgetDate DESC, StoreCode, CategoryCode, InternalSKU"
	Set sc = stmt.%Prepare(sql)
	If $SYSTEM.Status.IsError(sc) Quit items
	Set rs = stmt.%Execute()
	While rs.%Next() {
		Set row = ..BudgetRowToObject(rs)
		If budgetDate'="", row.budgetDate'=budgetDate {
			Continue
		}
		If storeCode'="", row.storeCode'=storeCode {
			Continue
		}
		If categoryCode'="", row.categoryCode'=categoryCode {
			Continue
		}
		If internalSKU'="", row.internalSku'=internalSKU {
			Continue
		}
		Do items.%Push(row)
	}
	Quit items
}

ClassMethod SaveBudgetPayload(payload As %DynamicObject, Output result As %DynamicObject) As %Status
{
	Set result = ##class(%DynamicObject).%New()
	Set budgetDate = payload.%Get("budget_date")
	If budgetDate = "" Set budgetDate = payload.%Get("budgetDate")
	Set storeCode = payload.%Get("store_code")
	If storeCode = "" Set storeCode = payload.%Get("storeCode")
	Set categoryCode = payload.%Get("category_code")
	If categoryCode = "" Set categoryCode = payload.%Get("categoryCode")
	Set internalSKU = payload.%Get("internal_sku")
	If internalSKU = "" Set internalSKU = payload.%Get("internalSku")
	Set targetUnitsText = payload.%Get("target_units")
	If targetUnitsText = "" Set targetUnitsText = payload.%Get("targetUnits")
	Set targetUnits = +targetUnitsText
	Set targetRevenueText = payload.%Get("target_revenue")
	If targetRevenueText = "" Set targetRevenueText = payload.%Get("targetRevenue")
	Set targetRevenue = +targetRevenueText

	If budgetDate = "" {
		Set result.error = "Budget date is required"
		Quit $SYSTEM.Status.Error(5001, "Budget date is required")
	}

	Set budgetDateH = $ZDATEH(budgetDate, 3)
	If budgetDateH = "" {
		Set result.error = "Budget date is invalid"
		Quit $SYSTEM.Status.Error(5001, "Budget date is invalid")
	}

	If storeCode = "" || categoryCode = "" {
		Set result.error = "Store and category are required"
		Quit $SYSTEM.Status.Error(5001, "Store and category are required")
	}

	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID FROM MD.SalesBudget WHERE BudgetDate = ? AND StoreCode = ? AND CategoryCode = ? AND InternalSKU = ?")
	If $SYSTEM.Status.IsError(sc) {
		Set result.error = "Budget lookup failed"
		Quit sc
	}
	Set rs = stmt.%Execute(budgetDateH, storeCode, categoryCode, internalSKU)
	Set loadedAt = $ZDATETIME($HOROLOG, 3, 1)
	If rs.%Next() {
		Set rowId = rs.%GetData(1)
		Set stmt = ##class(%SQL.Statement).%New()
		Set sc = stmt.%Prepare("UPDATE MD.SalesBudget SET TargetUnits = ?, TargetRevenue = ?, LoadedAt = ?, InternalSKU = ? WHERE %ID = ?")
		If $SYSTEM.Status.IsError(sc) {
			Set result.error = "Budget update failed"
			Quit sc
		}
		Set sc = stmt.%Execute(targetUnits, targetRevenue, loadedAt, internalSKU, rowId)
		If $SYSTEM.Status.IsError(sc) {
			Set result.error = "Budget update failed"
			Quit sc
		}
	} Else {
		Set stmt = ##class(%SQL.Statement).%New()
		Set sc = stmt.%Prepare("INSERT INTO MD.SalesBudget (BudgetDate, StoreCode, CategoryCode, InternalSKU, TargetUnits, TargetRevenue, LoadedAt) VALUES (?, ?, ?, ?, ?, ?, ?)")
		If $SYSTEM.Status.IsError(sc) {
			Set result.error = "Budget insert failed"
			Quit sc
		}
		Set sc = stmt.%Execute(budgetDateH, storeCode, categoryCode, internalSKU, targetUnits, targetRevenue, loadedAt)
		If $SYSTEM.Status.IsError(sc) {
			Set result.error = "Budget insert failed"
			Quit sc
		}
	}

	Set result.status = "ok"
	Set result.message = "Budget saved"
	Set result.budgetDate = budgetDate
	Set result.storeCode = storeCode
	Set result.categoryCode = categoryCode
	Set result.internalSku = internalSKU
	Set result.targetUnits = targetUnits
	Set result.targetRevenue = targetRevenue
	Quit $$$OK
}
ClassMethod BudgetRowToObject(row As %SQL.StatementResult) As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set data.rowId = row.%GetData(1)
	Set data.budgetDate = $ZDATE(row.%GetData(2), 3)
	Set data.storeCode = row.%GetData(3)
	Set data.categoryCode = row.%GetData(4)
	Set data.internalSku = row.%GetData(5)
	Set data.targetUnits = row.%GetData(6)
	Set data.targetRevenue = row.%GetData(7)
	Set data.loadedAt = row.%GetData(8)
	Quit data
}

ClassMethod PostFeedback(recommendationId As %String) As %Status
{
	Set feedbackStatus = $Get(%request.Data("decision"))
	If feedbackStatus = "" Set feedbackStatus = $Get(%request.Data("status"))
	Set acceptedBy = $Get(%request.Data("acceptedBy"))
	Set notes = $Get(%request.Data("notes"))
	Set data = ..ApplyFeedback(recommendationId, feedbackStatus, acceptedBy, notes)
	Do ..AuditRequest("Ops.Recommendation", recommendationId, "UPDATE_FEEDBACK", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod PostFeedbackDecision(recommendationId As %String, decision As %String) As %Status
{
	Set feedbackStatus = decision
	Set acceptedBy = $Get(%request.Data("acceptedBy"))
	Set notes = $Get(%request.Data("notes"))
	Set data = ..ApplyFeedback(recommendationId, feedbackStatus, acceptedBy, notes)
	Do ..AuditRequest("Ops.Recommendation", recommendationId _ "/" _ decision, "UPDATE_FEEDBACK", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod PostFeedbackDetails(recommendationId As %String, decision As %String, acceptedBy As %String, notes As %String) As %Status
{
	Set data = ..ApplyFeedback(recommendationId, decision, acceptedBy, notes)
	Do ..AuditRequest("Ops.Recommendation", recommendationId _ "/" _ decision, "UPDATE_FEEDBACK", "", data.%ToJSON())
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
	Set defaultAcceptedBy = $Select(acceptedBy'="":acceptedBy, 1:"store.manager")
	Set updatedAcceptedBy = $Select((normalizedStatus = "ACCEPTED")!(normalizedStatus = "MODIFIED"):defaultAcceptedBy, 1:recommendation.AcceptedBy)
	Set updatedAcceptedAt = $Select((normalizedStatus = "ACCEPTED")!(normalizedStatus = "MODIFIED"):$ZDATETIME($HOROLOG, 3, 1), 1:recommendation.AcceptedAt)
	Set updatedExecutedAt = $Select(normalizedStatus = "EXECUTED":$ZDATETIME($HOROLOG, 3, 1), 1:recommendation.ExecutedAt)
	Set updatedNotes = $Select(notes'="":notes, 1:recommendation.Notes)
	Set updatedExecutionState = $Select(normalizedStatus = "ACCEPTED":"ACCEPTED", normalizedStatus = "REJECTED":"REJECTED", normalizedStatus = "MODIFIED":"MODIFIED", normalizedStatus = "EXECUTED":"EXECUTED", 1:recommendation.ExecutionState)

	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("UPDATE Ops.Recommendation SET ""Status"" = ?, ExecutionState = ?, AcceptedBy = ?, AcceptedAt = ?, ExecutedAt = ?, Notes = ? WHERE RecommendationId = ?")
	If $SYSTEM.Status.IsError(sc) {
		Set result.error = "RECOMMENDATION_UPDATE_FAILED"
		Quit result
	}
	Set sc = stmt.%Execute(normalizedStatus, updatedExecutionState, updatedAcceptedBy, updatedAcceptedAt, updatedExecutedAt, updatedNotes, recommendationId)
	If $SYSTEM.Status.IsError(sc) {
		Set result.error = "RECOMMENDATION_UPDATE_FAILED"
		Quit result
	}
	Set recommendation = ##class(Ops.Recommendation).%OpenId(rs.%GetData(1))
	If '$IsObject(recommendation) {
		Set result.error = "RECOMMENDATION_OPEN_FAILED"
		Quit result
	}

	Set afterState = ..RecommendationToObject(recommendation)
	Set afterState.Status = normalizedStatus
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
	Write payload.%ToJSON()
	Quit $$$OK
}

}
