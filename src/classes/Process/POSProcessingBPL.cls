Class Process.POSProcessingBPL
{

ClassMethod HandlePayload(payload As %String, sourceChannel As %String = "REST") As %Status
{
	Set status = ..PersistBronze(payload, sourceChannel, .bronzeId)
	If $SYSTEM.Status.IsError(status) Quit status

	Set status = ..NormalizeSale(payload, bronzeId, .saleId, .storeCode, .categoryCode, .saleDate, .saleHour, .quantity, .unitPrice, .lineTotal)
	If $SYSTEM.Status.IsError(status) Quit status

	Set status = ..UpdateGold(storeCode, categoryCode, saleDate, saleHour, quantity, lineTotal, .paceId, .unitsBudget, .revenueBudget, .unitsCumulative, .revenueCumulative, .varianceUnits)
	If $SYSTEM.Status.IsError(status) Quit status

	Set status = ..EvaluateRules(storeCode, categoryCode, saleDate, paceId, unitsBudget, revenueBudget, unitsCumulative, revenueCumulative, varianceUnits, .recommendationId)
	Quit status
}

ClassMethod PersistBronze(payload As %String, sourceChannel As %String, Output bronzeId As %String) As %Status
{
	Set event = ##class(Bronze.POSEvent).%New()
	Set bronzeId = $SYSTEM.Util.CreateGUID()
	Set event.SourceId = bronzeId
	Set event.ReceivedAt = $ZDATETIME($HOROLOG, 3, 1)
	Set event.SourceChannel = sourceChannel
	Set event.Payload = payload
	Quit event.%Save()
}

ClassMethod NormalizeSale(payload As %String, bronzeId As %String, Output saleId As %String, Output storeCode As %String, Output categoryCode As %String, Output saleDate As %Date, Output saleHour As %Integer, Output quantity As %Integer, Output unitPrice As %Numeric, Output lineTotal As %Numeric) As %Status
{
	Set json = ##class(%DynamicObject).%FromJSON(payload)
	If '$IsObject(json) Quit $SYSTEM.Status.Error(5001, "Invalid POS payload JSON")

	Set saleId = bronzeId _ "-SALE"
	Set storeCode = json.%Get("store_code")
	Set categoryCode = json.%Get("category_code")
	Set quantity = +json.%Get("qty")
	Set unitPrice = +json.%Get("price")
	Set lineTotal = quantity * unitPrice
	Set tsValue = json.%Get("timestamp")

	If tsValue'="" {
		Set saleDate = $ZDATEH($Extract(tsValue, 1, 10), 3)
		Set saleHour = +$Extract(tsValue, 12, 13)
	} Else {
		Set saleDate = $P($HOROLOG, ",", 1)
		Set saleHour = +$Piece($ZTIME($HOROLOG, 3), ":", 1)
	}

	Set sale = ##class(Silver.Sale).%New()
	Set sale.SaleId = saleId
	Set sale.SaleTimestamp = $ZDATETIME($HOROLOG, 3, 1)
	Set sale.StoreCode = storeCode
	Set sale.InternalSKU = json.%Get("internal_sku")
	Set sale.Qty = quantity
	Set sale.Price = unitPrice
	Set sale.CategoryCode = categoryCode
	Set sale.SourceEventId = bronzeId
	Quit sale.%Save()
}

ClassMethod UpdateGold(storeCode As %String, categoryCode As %String, saleDate As %Date, saleHour As %Integer, quantity As %Integer, lineTotal As %Numeric, Output paceId As %String, Output unitsBudget As %Integer, Output revenueBudget As %Numeric, Output unitsCumulative As %Integer, Output revenueCumulative As %Numeric, Output varianceUnits As %Numeric) As %Status
{
	Set paceId = ..BuildPaceId(storeCode, categoryCode, saleDate, saleHour)
	Set unitsBudget = ..GetBudgetUnits(saleDate, storeCode, categoryCode)
	Set revenueBudget = ..GetBudgetRevenue(saleDate, storeCode, categoryCode)
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID, UnitsCumulative, RevenueCumulative, UnitsSold, RevenueSold FROM Gold.CategoryPace WHERE PaceId = ?")
	If $SYSTEM.Status.IsError(sc) Quit sc
	Set rs = stmt.%Execute(paceId)
	Set existingPace = 0
	If rs.%Next() {
		Set existingPace = ##class(Gold.CategoryPace).%OpenId(rs.%GetData(1))
	}

	If $IsObject(existingPace) {
		Set unitsCumulative = +existingPace.UnitsCumulative + quantity
		Set revenueCumulative = +existingPace.RevenueCumulative + lineTotal
		Set unitsSold = +existingPace.UnitsSold + quantity
		Set revenueSold = +existingPace.RevenueSold + lineTotal
		Set pace = existingPace
	} Else {
		Set unitsCumulative = quantity
		Set revenueCumulative = lineTotal
		Set unitsSold = quantity
		Set revenueSold = lineTotal
		Set pace = ##class(Gold.CategoryPace).%New()
	}

	Set pctPaceUnits = ..CalculatePct(unitsCumulative, unitsBudget)
	Set pctPaceRevenue = ..CalculatePct(revenueCumulative, revenueBudget)
	Set varianceUnits = unitsCumulative - unitsBudget
	Set varianceRevenue = revenueCumulative - revenueBudget
	Set lastUpdated = $ZDATETIME($HOROLOG, 3, 1)

	Set pace.PaceId = paceId
	Set pace.PaceDate = saleDate
	Set pace.PaceHour = saleHour
	Set pace.StoreCode = storeCode
	Set pace.CategoryCode = categoryCode
	Set pace.UnitsSold = unitsSold
	Set pace.RevenueSold = revenueSold
	Set pace.UnitsBudget = unitsBudget
	Set pace.RevenueBudget = revenueBudget
	Set pace.UnitsCumulative = unitsCumulative
	Set pace.RevenueCumulative = revenueCumulative
	Set pace.PctPaceUnits = pctPaceUnits
	Set pace.PctPaceRevenue = pctPaceRevenue
	Set pace.VarianceUnits = varianceUnits
	Set pace.VarianceRevenue = varianceRevenue
	Set pace.LastUpdated = lastUpdated
	Quit pace.%Save()
}

ClassMethod EvaluateRules(storeCode As %String, categoryCode As %String, saleDate As %Date, paceId As %String, unitsBudget As %Integer, revenueBudget As %Numeric, unitsCumulative As %Integer, revenueCumulative As %Numeric, varianceUnits As %Numeric, Output recommendationId As %String) As %Status
{
	Set recommendationId = ""
	Set ruleCode = ""
	Set rulePriority = 99
	Set ruleWindowType = "PACE"
	Set ruleThreshold = -25
	Set ruleObservedValue = varianceUnits
	Set ruleSeverity = "LOW"
	Set businessMessage = "No action required"
	Set executionState = "NEW"
	If ##class(Rules.PaceRules).IsCritical(varianceUnits) {
		Set ruleCode = "PACE_NEGATIVE_CRITICAL"
		Set ruleSeverity = "HIGH"
		Set businessMessage = "Critical pace deviation detected"
	} ElseIf ##class(Rules.PaceRules).IsSustained(..CountBelowThreshold(storeCode, categoryCode, saleDate, -10), 3) {
		Set ruleCode = "PACE_NEGATIVE_SUSTAINED"
		Set ruleWindowType = "HOURLY_STREAK"
		Set ruleThreshold = 3
		Set ruleObservedValue = ..CountBelowThreshold(storeCode, categoryCode, saleDate, -10)
		Set ruleSeverity = "MEDIUM"
		Set businessMessage = "Pace has been below threshold for consecutive windows"
	} ElseIf ##class(Rules.PaceRules).IsStockoutInferred(..CountWithoutSales(storeCode, categoryCode, saleDate), 2) {
		Set ruleCode = "STOCKOUT_INFERRED"
		Set ruleWindowType = "NO_SALES"
		Set ruleThreshold = 2
		Set ruleObservedValue = ..CountWithoutSales(storeCode, categoryCode, saleDate)
		Set ruleSeverity = "HIGH"
		Set businessMessage = "No sales detected for consecutive windows"
	}

	If ruleCode = "" Quit 1
	Set rulePriority = ##class(Rules.ActionSelector).GetPriority(ruleCode)

	Quit ..CreateRecommendation(ruleCode, storeCode, categoryCode, paceId, ruleWindowType, ruleThreshold, ruleObservedValue, rulePriority, ruleSeverity, businessMessage, executionState, .recommendationId)
}

ClassMethod CreateRecommendation(ruleCode As %String, storeCode As %String, categoryCode As %String, paceId As %String, ruleWindowType As %String, ruleThreshold As %Numeric, ruleObservedValue As %Numeric, rulePriority As %Integer, ruleSeverity As %String, businessMessage As %String, executionState As %String, Output recommendationId As %String) As %Status
{
	Set recommendation = ##class(Ops.Recommendation).%New()
	Set recommendationId = $SYSTEM.Util.CreateGUID()
	Set recommendation.RecommendationId = recommendationId
	Set recommendation.StoreCode = storeCode
	Set recommendation.CategoryCode = categoryCode
	Set recommendation.RuleFired = ruleCode
	Set recommendation.RuleWindowType = ruleWindowType
	Set recommendation.RuleThreshold = ruleThreshold
	Set recommendation.RuleObservedValue = ruleObservedValue
	Set recommendation.RulePriority = rulePriority
	Set recommendation.RuleSeverity = ruleSeverity
	Set recommendation.BusinessMessage = businessMessage
	Set recommendation.ExecutionState = executionState
	Set recommendation.RelatedPaceId = paceId
	Set recommendation.ActionCode = ##class(Rules.ActionSelector).SelectAction(ruleCode)
	Set recommendation.ActionDescription = ..ActionDescription(recommendation.ActionCode)
	Set recommendation.Status = "PENDING"
	Set recommendation.TriggeredAt = $ZDATETIME($HOROLOG, 3, 1)
	Set recommendation.Notes = "Generated by POSProcessingBPL"
	Quit recommendation.%Save()
}

ClassMethod BuildPaceId(storeCode As %String, categoryCode As %String, saleDate As %Date, saleHour As %Integer) As %String
{
	Quit storeCode _ "|" _ categoryCode _ "|" _ saleDate _ "|" _ saleHour
}

ClassMethod CalculatePct(actual As %Numeric, budget As %Numeric) As %Numeric
{
	If budget = 0 Quit 0
	Quit (actual / budget) * 100
}

ClassMethod GetBudgetUnits(saleDate As %Date, storeCode As %String, categoryCode As %String) As %Integer
{
	Quit +$Get(^IRIS111("budget", saleDate, storeCode, categoryCode, "units"), 0)
}

ClassMethod GetBudgetRevenue(saleDate As %Date, storeCode As %String, categoryCode As %String) As %Numeric
{
	Quit +$Get(^IRIS111("budget", saleDate, storeCode, categoryCode, "revenue"), 0)
}

ClassMethod CountBelowThreshold(storeCode As %String, categoryCode As %String, saleDate As %Date, threshold As %Numeric = -25) As %Integer
{
	New count
	Set count = 0
	&sql(SELECT COUNT(*) INTO :count
		FROM Gold.CategoryPace
		WHERE StoreCode = :storeCode
		  AND CategoryCode = :categoryCode
		  AND PaceDate = :saleDate
		  AND VarianceUnits <= :threshold)
	Quit +$Get(count, 0)
}

ClassMethod CountWithoutSales(storeCode As %String, categoryCode As %String, saleDate As %Date) As %Integer
{
	New count
	Set count = 0
	&sql(SELECT COUNT(*) INTO :count
		FROM Gold.CategoryPace
		WHERE StoreCode = :storeCode
		  AND CategoryCode = :categoryCode
		  AND PaceDate = :saleDate
		  AND UnitsSold = 0)
	Quit +$Get(count, 0)
}

ClassMethod ActionDescription(actionCode As %String) As %String
{
	If actionCode = "MOVE_PALLET_TO_ENTRY" Quit "Move high-visibility stock to entry"
	If actionCode = "ACTIVATE_PROMOTION" Quit "Activate a promotional price or banner"
	If actionCode = "REFRESH_SHELF_DISPLAY" Quit "Refresh shelf display and facing"
	Quit "Manual review required"
}

ClassMethod RuleDescription(ruleCode As %String) As %String
{
	Set ruleCode = $ZCONVERT(ruleCode, "U")
	If ruleCode = "PACE_NEGATIVE_CRITICAL" Quit "Critical pace deviation"
	If ruleCode = "PACE_NEGATIVE_SUSTAINED" Quit "Sustained pace deviation"
	If ruleCode = "STOCKOUT_INFERRED" Quit "Stockout inferred from zero sales"
	Quit "Manual review required"
}

}
