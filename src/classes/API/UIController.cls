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
	<Route Url="/categories" Method="GET" Call="GetCategories" />
	<Route Url="/budget/context/:storeCode/:categoryCode" Method="GET" Call="GetBudgetContext" />
	<Route Url="/categories/:categoryCode/skus" Method="GET" Call="GetCategorySkus" />
	<Route Url="/budgets" Method="GET" Call="GetBudgets" />
	<Route Url="/budgets" Method="POST" Call="PostBudget" />
	<Route Url="/pos/ingest" Method="POST" Call="PostPOSIngest" />
	<Route Url="/pos/raw/:storeCode" Method="GET" Call="GetPosRaw" />
    <Route Url="/stores/:storeCode/categories/:categoryCode/pace" Method="GET" Call="GetPace" />
	<Route Url="/sales/hourly/:storeCode" Method="GET" Call="GetHourlySales" />
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

ClassMethod GetCategories() As %Status
{
	Set data = ..BuildCategoriesData()
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
	Set internalSKU = ..GetRequestValue(%request, "internalSku", "internal_sku")
	Set data = ..BuildBudgetContextData(storeCode, categoryCode, internalSKU)
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod GetCategorySkus(categoryCode As %String) As %Status
{
	Set search = ..GetRequestValue(%request, "search")
	Set limit = +..GetRequestValue(%request, "limit")
	If limit <= 0 Set limit = 50
	If limit > 200 Set limit = 200
	Set data = ..BuildCategorySkuData(categoryCode, search, limit)
	Do ..AuditRequest("MD.SKU", categoryCode, "READ_SKUS", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod GetBudgets() As %Status
{
	Set budgetDate = ..GetRequestValue(%request, "budgetDate", "budget_date")
	Set storeCode = ..GetRequestValue(%request, "storeCode", "store_code")
	Set categoryCode = ..GetRequestValue(%request, "categoryCode", "category_code")
	Set internalSKU = ..GetRequestValue(%request, "internalSku", "internal_sku")
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

ClassMethod BuildCategoriesData() As %DynamicArray
{
	Set items = ##class(%DynamicArray).%New()
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT CategoryCode, CategoryName FROM MD.Category ORDER BY CategoryName, CategoryCode")
	If $SYSTEM.Status.IsError(sc) Quit items
	Set rs = stmt.%Execute()
	While rs.%Next() {
		Set item = ##class(%DynamicObject).%New()
		Set item.categoryCode = rs.%GetData(1)
		Set item.categoryName = rs.%GetData(2)
		Do items.%Push(item)
	}
	Quit items
}

ClassMethod NormalizeDateInput(dateValue As %String, Output normalizedDate As %Date) As %Status
{
	Set normalizedDate = ""
	If dateValue = "" Quit $$$OK
	If dateValue?1N.N {
		Set normalizedDate = +dateValue
		Quit $$$OK
	}
	Set normalizedDate = $ZDATEH(dateValue, 3)
	Quit $$$OK
}

ClassMethod GetPace(storeCode As %String, categoryCode As %String) As %Status
{
	Set internalSKU = $Get(%request.Data("internalSku"))
	If internalSKU = "" Set internalSKU = $Get(%request.Data("internal_sku"))
	If internalSKU'="" Set internalSKU = $ZCONVERT($ZSTRIP(internalSKU, "<>", " "), "U")
	Set paceDate = $Get(%request.Data("paceDate"))
	If paceDate = "" Set paceDate = $Get(%request.Data("pace_date"))
	Do ..NormalizeDateInput(paceDate, .paceDate)
	Set paceHourRaw = $Get(%request.Data("paceHour"))
	If paceHourRaw = "" Set paceHourRaw = $Get(%request.Data("pace_hour"))
	Set paceHour = +paceHourRaw
	If paceHourRaw = "" Set paceHour = -1
	Set data = ..BuildPaceData(storeCode, categoryCode, internalSKU, paceDate, paceHour)
	Do ..AuditRequest("Gold.SalesCadence", storeCode _ "|" _ categoryCode _ "|" _ $Select(internalSKU'="":internalSKU, 1:"__CATEGORY__"), "READ_PACE", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod BuildPaceData(storeCode As %String, categoryCode As %String, internalSKU As %String = "", paceDate As %Date = "", paceHour As %Integer = -1) As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set queryDate = $Select(paceDate'="":paceDate, 1:$P($HOROLOG, ",", 1))
	Set queryHour = $Select(paceHour>-1:paceHour, 1:+$Piece($ZTIME($HOROLOG, 3), ":", 1))
	Set querySKU = $Select(internalSKU'="":$ZCONVERT(internalSKU, "U"), 1:"__CATEGORY__")

	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT CadenceId, CadenceDate, CadenceHour, StoreCode, CategoryCode, InternalSKU, UnitsSold, RevenueSold, UnitsBudget, RevenueBudget, UnitsCumulative, RevenueCumulative, VarianceUnits, VarianceRevenue, LastUpdated FROM Gold.SalesCadence WHERE CadenceDate = ? AND CadenceHour <= ? AND StoreCode = ? AND CategoryCode = ? AND InternalSKU = ? ORDER BY CadenceHour DESC")
	If $SYSTEM.Status.IsError(sc) Quit data
	Set rs = stmt.%Execute(queryDate, queryHour, storeCode, categoryCode, querySKU)
	If rs.%Next() {
		Set data.paceId = rs.%GetData(1)
		Set data.paceDate = rs.%GetData(2)
		Set data.paceHour = rs.%GetData(3)
		Set data.storeCode = rs.%GetData(4)
		Set data.categoryCode = rs.%GetData(5)
		Set data.internalSku = $Select(rs.%GetData(6) = "__CATEGORY__":"", 1:rs.%GetData(6))
		Set data.unitsSold = rs.%GetData(7)
		Set data.revenueSold = rs.%GetData(8)
		Set data.unitsBudget = rs.%GetData(9)
		Set data.revenueBudget = rs.%GetData(10)
		Set data.unitsCumulative = rs.%GetData(11)
		Set data.revenueCumulative = rs.%GetData(12)
		Set data.pctPaceUnits = ..PercentOf(rs.%GetData(11), rs.%GetData(9))
		Set data.pctPaceRevenue = ..PercentOf(rs.%GetData(12), rs.%GetData(10))
		Set data.varianceUnits = rs.%GetData(13)
		Set data.varianceRevenue = rs.%GetData(14)
		Set data.lastUpdated = rs.%GetData(15)
	} ElseIf internalSKU'="" {
		Set data = ..BuildPaceData(storeCode, categoryCode, "", paceDate, paceHour)
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
	Set cadenceDate = ..GetRequestValue(%request, "paceDate", "cadenceDate")
	If cadenceDate = "" Set cadenceDate = ..GetRequestValue(%request, "date")
	Do ..NormalizeDateInput(cadenceDate, .cadenceDate)
	Set data = ..BuildDashboardData(storeCode, cadenceDate)
	Do ..AuditRequest("Gold.SalesCadence", storeCode, "READ_DASHBOARD", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod GetPosRaw(storeCode As %String) As %Status
{
	Set categoryCode = ..GetRequestValue(%request, "categoryCode", "category_code")
	Set internalSKU = ..GetRequestValue(%request, "internalSku", "internal_sku")
	Set paceDate = ..GetRequestValue(%request, "paceDate", "pace_date")
	Do ..NormalizeDateInput(paceDate, .paceDate)
	Set limitRaw = ..GetRequestValue(%request, "limit", "maxItems")
	Set limit = +limitRaw
	If limit < 1 Set limit = 10
	If limit > 20 Set limit = 20
	Set data = ..BuildPosRawData(storeCode, categoryCode, internalSKU, paceDate, limit)
	Do ..AuditRequest("Bronze.POSEvent", storeCode _ $Select(categoryCode'="":"|" _ categoryCode, 1:""), "READ_RAW_POS", "", data.%ToJSON())
	Do ..WriteJson(data)
	Quit $$$OK
}

ClassMethod GetHourlySales(storeCode As %String) As %Status
{
	Set saleDate = ..GetRequestValue(%request, "date", "day")
	If saleDate = "" Set saleDate = ..GetRequestValue(%request, "saleDate")
	Do ..NormalizeDateInput(saleDate, .saleDate)
	Set categoryCode = ..GetRequestValue(%request, "categoryCode", "category_code")
	Set internalSKU = ..GetRequestValue(%request, "internalSku", "internal_sku")
	Set data = ..BuildHourlySalesData(storeCode, saleDate, categoryCode, internalSKU)
	Do ..AuditRequest("Silver.Sale", storeCode _ "|" _ $Select(saleDate'="":$ZDATE(saleDate, 3), 1:"") _ "|" _ categoryCode _ "|" _ $Select(internalSKU'="":internalSKU, 1:"__CATEGORY__"), "READ_HOURLY_SALES", "", data.%ToJSON())
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

ClassMethod GetRequestValue(request As %CSP.Request, name As %String, fallbackName As %String = "") As %String
{
	Set value = ..GetQueryParam(request, name)
	If value = "", fallbackName'="" Set value = ..GetQueryParam(request, fallbackName)
	Quit value
}

ClassMethod GetQueryParam(request As %CSP.Request, name As %String) As %String
{
	Set queryString = $Get(request.CgiEnvs("QUERY_STRING"))
	If queryString = "" Quit ""
	Set count = $Length(queryString, "&")
	Set value = ""
	For index = 1:1:count {
		Set pair = $Piece(queryString, "&", index)
		If pair'="" {
			Set pairName = $Piece(pair, "=", 1)
			If pairName=name Set value = $Piece(pair, "=", 2, 999)
		}
	}
	Quit value
}

ClassMethod BuildDashboardData(storeCode As %String, cadenceDate As %String = "") As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set data.storeCode = storeCode
	Set data.date = $Select(cadenceDate'="":cadenceDate, 1:$P($HOROLOG, ",", 1))
	Set data.categories = ##class(%DynamicArray).%New()
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT CadenceId, CadenceDate, CadenceHour, StoreCode, CategoryCode, InternalSKU, UnitsSold, RevenueSold, UnitsBudget, RevenueBudget, UnitsCumulative, RevenueCumulative, VarianceUnits, VarianceRevenue, LastUpdated FROM Gold.SalesCadence WHERE CadenceDate = ? AND StoreCode = ? AND InternalSKU = '__CATEGORY__' ORDER BY CategoryCode, CadenceHour")
	If $SYSTEM.Status.IsError(sc) Quit data
	Set rs = stmt.%Execute(data.date, storeCode)
	While rs.%Next() {
		Do data.categories.%Push(..PaceRowToObject(rs))
	}
	Quit data
}

ClassMethod BuildPosRawData(storeCode As %String, categoryCode As %String = "", internalSKU As %String = "", paceDate As %String = "", limit As %Integer = 10) As %DynamicArray
{
	Set items = ##class(%DynamicArray).%New()
	Set normalizedSKU = $Select(internalSKU'="":$ZCONVERT(internalSKU, "U"), 1:"")
	Set selectedDate = $Select(paceDate'="":$ZDATE(paceDate, 3), 1:"")
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID, SourceId, ReceivedAt, SourceChannel, Payload FROM Bronze.POSEvent ORDER BY ReceivedAt DESC")
	If $SYSTEM.Status.IsError(sc) Quit items
	Set rs = stmt.%Execute()
	While rs.%Next() {
		Set payload = rs.%GetData(5)
		Set json = ##class(%DynamicObject).%FromJSON(payload)
		If '$IsObject(json) {
			Continue
		}
		If storeCode'="", json.%Get("store_code")'=storeCode {
			Continue
		}
		If categoryCode'="", json.%Get("category_code")'=categoryCode {
			Continue
		}
		Set payloadSKU = $Select(json.%Get("internal_sku")'="":$ZCONVERT(json.%Get("internal_sku"), "U"), 1:"")
		If normalizedSKU'="", payloadSKU'=normalizedSKU {
			Continue
		}
		If selectedDate'="" {
			Set eventDate = $Extract(json.%Get("timestamp"), 1, 10)
			If eventDate'=selectedDate {
				Continue
			}
		}
		Set bronzeSourceId = rs.%GetData(2)
		Set saleRow = ..GetRelatedSilverSale(bronzeSourceId)
		Set goldRows = ..GetRelatedGoldRows(storeCode, categoryCode, json.%Get("internal_sku"), json.%Get("timestamp"))
		Do items.%Push(..PosRawRowToObject(rs, json, saleRow, goldRows))
		If items.%Size() >= limit {
			Quit
		}
	}
	Quit items
}

ClassMethod BuildHourlySalesData(storeCode As %String, saleDate As %Date = "", categoryCode As %String = "", internalSKU As %String = "") As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set effectiveDate = $Select(saleDate'="":saleDate, 1:$P($HOROLOG, ",", 1))
	Set effectiveDateText = $ZDATE(effectiveDate, 3)
	Set effectiveCategoryCode = $Select(categoryCode'="":categoryCode, 1:"__CATEGORY__")
	Set normalizedSKU = $Select(internalSKU'="":$ZCONVERT($ZSTRIP(internalSKU, "<>", " "), "U"), 1:"")
	Set data.storeCode = storeCode
	Set data.saleDate = effectiveDateText
	Set data.categoryCode = categoryCode
	Set data.internalSku = normalizedSKU
	Set data.points = ##class(%DynamicArray).%New()
	Set data.summary = ##class(%DynamicObject).%New()
	Set data.summary.totalUnits = 0
	Set data.summary.totalRevenue = 0
	Set data.summary.totalTransactions = 0
	Set data.summary.maxUnits = 0
	Set data.summary.maxRevenue = 0
	Set data.summary.peakHour = 0
	Set data.summary.peakHourUnits = 0
	Set data.summary.peakHourRevenue = 0
	Set data.summary.totalBudgetUnits = ##class(Process.POSProcessingBPL).GetBudgetUnits(effectiveDate, storeCode, effectiveCategoryCode, normalizedSKU)
	Set data.summary.totalBudgetRevenue = ##class(Process.POSProcessingBPL).GetBudgetRevenue(effectiveDate, storeCode, effectiveCategoryCode, normalizedSKU)

	Set startStamp = effectiveDateText _ " 00:00:00"
	Set endStamp = $ZDATE(effectiveDate + 1, 3) _ " 00:00:00"
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT SaleTimestamp, Qty, Price, CategoryCode, InternalSKU FROM Silver.Sale WHERE StoreCode = ? AND SaleTimestamp >= ? AND SaleTimestamp < ? ORDER BY SaleTimestamp")
	If $SYSTEM.Status.IsError(sc) {
		Set data.error = "SALES_QUERY_FAILED"
		Quit data
	}

	Set hourUnits = 0
	Set hourRevenue = 0
	Set hourTransactions = 0
	Set cumulativeUnits = 0
	For hour = 0:1:23 {
		Set hourUnits(hour) = 0
		Set hourRevenue(hour) = 0
		Set hourTransactions(hour) = 0
	}

	Set rs = stmt.%Execute(storeCode, startStamp, endStamp)
	While rs.%Next() {
		Set rowCategory = rs.%GetData(4)
		If categoryCode'="", rowCategory'=categoryCode {
			Continue
		}
		Set rowSKU = $Select(rs.%GetData(5)'="":$ZCONVERT($ZSTRIP(rs.%GetData(5), "<>", " "), "U"), 1:"")
		If normalizedSKU'="", rowSKU'=normalizedSKU {
			Continue
		}
		Set saleTimestamp = rs.%GetData(1)
		Set saleHour = +$Extract(saleTimestamp, 12, 13)
		If saleHour < 0 Continue

		Set units = +rs.%GetData(2)
		Set revenue = units * (+rs.%GetData(3))
		Set hourUnits(saleHour) = +hourUnits(saleHour) + units
		Set hourRevenue(saleHour) = +hourRevenue(saleHour) + revenue
		Set hourTransactions(saleHour) = +hourTransactions(saleHour) + 1
		Set data.summary.totalUnits = +data.summary.totalUnits + units
		Set data.summary.totalRevenue = +data.summary.totalRevenue + revenue
		Set data.summary.totalTransactions = +data.summary.totalTransactions + 1

		If +hourUnits(saleHour) > +data.summary.maxUnits {
			Set data.summary.maxUnits = +hourUnits(saleHour)
			Set data.summary.peakHour = saleHour
			Set data.summary.peakHourUnits = +hourUnits(saleHour)
			Set data.summary.peakHourRevenue = +hourRevenue(saleHour)
		}
	}

	For hour = 0:1:23 {
		Set point = ##class(%DynamicObject).%New()
		Set point.hour = hour
		Set point.label = $Piece("00,01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23", ",", hour + 1)
		Set cumulativeUnits = +cumulativeUnits + +hourUnits(hour)
		Set point.hourUnits = +hourUnits(hour)
		Set point.units = +cumulativeUnits
		Set point.revenue = +hourRevenue(hour)
		Set point.transactions = +hourTransactions(hour)
		Set point.budgetUnits = ##class(Process.POSProcessingBPL).ExpectedBudgetAtHour(data.summary.totalBudgetUnits, hour)
		Set point.budgetRevenue = ##class(Process.POSProcessingBPL).ExpectedBudgetAtHour(data.summary.totalBudgetRevenue, hour)
		Do data.points.%Push(point)
		If +hourUnits(hour) > +data.summary.maxUnits {
			Set data.summary.maxUnits = +hourUnits(hour)
			Set data.summary.peakHour = hour
			Set data.summary.peakHourUnits = +hourUnits(hour)
			Set data.summary.peakHourRevenue = +hourRevenue(hour)
		}
	}

	Quit data
}

ClassMethod GetRelatedSilverSale(bronzeSourceId As %String) As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT SaleId, SaleTimestamp, StoreCode, InternalSKU, Qty, Price, CategoryCode, SourceEventId FROM Silver.Sale WHERE SourceEventId = ? ORDER BY SaleTimestamp DESC")
	If $SYSTEM.Status.IsError(sc) {
		Set data.error = "SILVER_QUERY_FAILED"
		Quit data
	}
	Set rs = stmt.%Execute(bronzeSourceId)
	If rs.%Next() {
		Set data.saleId = rs.%GetData(1)
		Set data.saleTimestamp = rs.%GetData(2)
		Set data.storeCode = rs.%GetData(3)
		Set data.internalSku = rs.%GetData(4)
		Set data.qty = rs.%GetData(5)
		Set data.price = rs.%GetData(6)
		Set data.categoryCode = rs.%GetData(7)
		Set data.sourceEventId = rs.%GetData(8)
		Set data.lineTotal = (+data.qty) * (+data.price)
		Quit data
	}
	Set data.error = "SILVER_NOT_FOUND"
	Quit data
}

ClassMethod GetRelatedGoldRows(storeCode As %String, categoryCode As %String, internalSKU As %String, timestamp As %String) As %DynamicArray
{
	Set rows = ##class(%DynamicArray).%New()
	Set saleDate = $Select(timestamp'="":$ZDATEH($Extract(timestamp, 1, 10), 3), 1:"")
	If saleDate = "" Quit rows
	Set saleHour = +$Extract(timestamp, 12, 13)
	If saleHour < 0 Quit rows

	Set stmt = ##class(%SQL.Statement).%New()
	Set query = "SELECT CadenceId, CadenceDate, CadenceHour, StoreCode, CategoryCode, InternalSKU, UnitsSold, RevenueSold, UnitsBudget, RevenueBudget, UnitsCumulative, RevenueCumulative, VarianceUnits, VarianceRevenue, LastUpdated FROM Gold.SalesCadence WHERE CadenceDate = ? AND CadenceHour = ? AND StoreCode = ? AND CategoryCode = ? AND InternalSKU = ? ORDER BY InternalSKU"
	Set sc = stmt.%Prepare(query)
	If $SYSTEM.Status.IsError(sc) Quit rows

	Set categoryResult = 0
	Set rs = stmt.%Execute(saleDate, saleHour, storeCode, categoryCode, "__CATEGORY__")
	If rs.%Next() {
		Do rows.%Push(..PaceRowToObject(rs))
		Set categoryResult = 1
	}

	If internalSKU'="" {
		Set skuResult = 0
		Set rs = stmt.%Execute(saleDate, saleHour, storeCode, categoryCode, $ZCONVERT(internalSKU, "U"))
		If rs.%Next() {
			Do rows.%Push(..PaceRowToObject(rs))
			Set skuResult = 1
		}
	}
	Quit rows
}

ClassMethod BuildBudgetContextData(storeCode As %String, categoryCode As %String, internalSKU As %String = "") As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set data.storeCode = storeCode
	Set data.categoryCode = categoryCode
	Set internalSKU = $Select(internalSKU'="":$ZCONVERT(internalSKU, "U"), 1:"")
	Set data.internalSku = internalSKU
	Set data.timestamp = $ZDATETIME($HOROLOG, 3, 1)
	Set data.budgetDate = ""
	Set data.targetUnits = 0
	Set data.targetRevenue = 0

	Set stmt = ##class(%SQL.Statement).%New()
	If internalSKU'="" {
		Set sc = stmt.%Prepare("SELECT BudgetDate, TargetUnits, TargetRevenue FROM MD.SalesBudget WHERE StoreCode = ? AND CategoryCode = ? AND InternalSKU = ? ORDER BY BudgetDate DESC")
		If '$SYSTEM.Status.IsError(sc) {
			Set rs = stmt.%Execute(storeCode, categoryCode, internalSKU)
			If rs.%Next() {
				Set data.budgetDate = $ZDATE(rs.%GetData(1), 3)
				Set data.targetUnits = rs.%GetData(2)
				Set data.targetRevenue = rs.%GetData(3)
				Quit data
			}
		}
	}
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

ClassMethod BuildCategorySkuData(categoryCode As %String, search As %String = "", limit As %Integer = 50) As %DynamicArray
{
	Set normalizedCategory = $ZCONVERT($ZSTRIP(categoryCode, "<>", " "), "U")
	Set normalizedSearch = $Select(search'="":$ZCONVERT($ZSTRIP(search, "<>", " "), "U"), 1:"")
	Set items = ##class(%DynamicArray).%New()

	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT s.InternalSKU, s.VendorSKU, s.CategoryCode, c.CategoryName, s.UnitOfMeasure FROM MD.SKU s LEFT JOIN MD.Category c ON c.CategoryCode = s.CategoryCode WHERE s.CategoryCode = ? ORDER BY s.InternalSKU")
	If $SYSTEM.Status.IsError(sc) Quit items
	Set rs = stmt.%Execute(normalizedCategory)
	While rs.%Next() {
		Set rowSku = rs.%GetData(1)
		Set rowVendorSku = rs.%GetData(2)
		Set rowCategoryCode = rs.%GetData(3)
		Set rowCategoryName = rs.%GetData(4)
		Set rowUnitOfMeasure = rs.%GetData(5)

		If normalizedSearch'="" {
			Set rowSearch = $ZCONVERT(rowSku _ " " _ rowVendorSku _ " " _ rowCategoryName, "U")
			If rowSearch'[normalizedSearch {
				Continue
			}
		}

		Set item = ##class(%DynamicObject).%New()
		Set item.internalSku = rowSku
		Set item.vendorSku = rowVendorSku
		Set item.categoryCode = rowCategoryCode
		Set item.categoryName = rowCategoryName
		Set item.unitOfMeasure = rowUnitOfMeasure
		Do items.%Push(item)
		If items.%Size() >= limit Quit
	}

	Quit items
}

ClassMethod PercentOf(actual As %Numeric, budget As %Numeric) As %Numeric
{
	If budget = 0 Quit 0
	Quit (actual / budget) * 100
}

ClassMethod BuildBudgetsData(budgetDate As %String = "", storeCode As %String = "", categoryCode As %String = "", internalSKU As %String = "") As %DynamicArray
{
	Set internalSKU = $Select(internalSKU'="":$ZCONVERT(internalSKU, "U"), 1:"")
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
	If internalSKU'="" Set internalSKU = $ZCONVERT($ZSTRIP(internalSKU, "<>", " "), "U")
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
	Set data.PaceDate = $ZDATE(row.%GetData(2), 3)
	Set data.PaceHour = row.%GetData(3)
	Set data.StoreCode = row.%GetData(4)
	Set data.CategoryCode = row.%GetData(5)
	Set data.InternalSKU = $Select(row.%GetData(6) = "__CATEGORY__":"", 1:row.%GetData(6))
	Set data.UnitsSold = row.%GetData(7)
	Set data.RevenueSold = row.%GetData(8)
	Set data.UnitsBudget = row.%GetData(9)
	Set data.RevenueBudget = row.%GetData(10)
	Set data.UnitsCumulative = row.%GetData(11)
	Set data.RevenueCumulative = row.%GetData(12)
	Set data.PctPaceUnits = ..PercentOf(row.%GetData(11), row.%GetData(9))
	Set data.PctPaceRevenue = ..PercentOf(row.%GetData(12), row.%GetData(10))
	Set data.VarianceUnits = row.%GetData(13)
	Set data.VarianceRevenue = row.%GetData(14)
	Set data.LastUpdated = row.%GetData(15)
	Quit data
}

ClassMethod PosRawRowToObject(row As %SQL.StatementResult, payload As %DynamicObject, silverSale As %DynamicObject, goldRows As %DynamicArray) As %DynamicObject
{
	Set data = ##class(%DynamicObject).%New()
	Set data.BronzeId = row.%GetData(1)
	Set data.BronzeSourceId = row.%GetData(2)
	Set data.SourceId = payload.%Get("source_id")
	Set data.ReceivedAt = row.%GetData(3)
	Set data.SourceChannel = row.%GetData(4)
	Set data.Timestamp = payload.%Get("timestamp")
	Set data.StoreCode = payload.%Get("store_code")
	Set data.CategoryCode = payload.%Get("category_code")
	Set data.InternalSKU = payload.%Get("internal_sku")
	Set data.Qty = +payload.%Get("qty")
	Set data.Price = +payload.%Get("price")
	Set data.LineTotal = data.Qty * data.Price
	Set data.Payload = row.%GetData(5)
	Set data.SilverSale = silverSale
	Set data.GoldRows = goldRows
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
