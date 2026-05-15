Class Process.POSProcessingBPL
{

ClassMethod HandlePayload(payload As %String, sourceChannel As %String = "REST") As %Status
{
	Set status = ..PersistBronze(payload, sourceChannel, .bronzeId)
	If $SYSTEM.Status.IsError(status) Quit status

	Set status = ..NormalizeSale(payload, bronzeId, .saleId, .storeCode, .categoryCode, .internalSKU, .saleDate, .saleHour, .quantity, .unitPrice, .lineTotal)
	If $SYSTEM.Status.IsError(status) Quit status

	Set status = ..UpdateCadence(storeCode, categoryCode, internalSKU, saleDate, saleHour, quantity, lineTotal, .paceId, .unitsBudget, .revenueBudget, .unitsCumulative, .revenueCumulative, .varianceUnits)
	If $SYSTEM.Status.IsError(status) Quit status

	Set status = ..EvaluateRules(storeCode, categoryCode, saleDate, saleHour, paceId, unitsBudget, revenueBudget, unitsCumulative, revenueCumulative, varianceUnits, .recommendationId)
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

ClassMethod NormalizeTimestampValue(tsValue As %String) As %String
{
	Set normalized = $ZSTRIP(tsValue, "<>", " ")
	If normalized = "" Quit $ZDATETIME($HOROLOG, 3, 1)

	If normalized["T" {
		Set normalized = $Extract(normalized, 1, 10) _ " " _ $Extract(normalized, 12, 19)
	}

	If $Extract(normalized, $Length(normalized)) = "Z" {
		Set normalized = $Extract(normalized, 1, $Length(normalized) - 1)
	}

	Quit normalized
}

ClassMethod NormalizeSale(payload As %String, bronzeId As %String, Output saleId As %String, Output storeCode As %String, Output categoryCode As %String, Output internalSKU As %String, Output saleDate As %Date, Output saleHour As %Integer, Output quantity As %Integer, Output unitPrice As %Numeric, Output lineTotal As %Numeric) As %Status
{
	Set json = ##class(%DynamicObject).%FromJSON(payload)
	If '$IsObject(json) Quit $SYSTEM.Status.Error(5001, "Invalid POS payload JSON")

	Set saleId = bronzeId _ "-SALE"
	Set storeCode = json.%Get("store_code")
	Set categoryCode = json.%Get("category_code")
	Set internalSKU = $ZCONVERT(json.%Get("internal_sku"), "U")
	Set quantity = +json.%Get("qty")
	Set unitPrice = +json.%Get("price")
	Set lineTotal = quantity * unitPrice
	Set tsValue = json.%Get("timestamp")
	Set normalizedTs = ..NormalizeTimestampValue(tsValue)
	Set saleDate = $ZDATEH($Extract(normalizedTs, 1, 10), 3)
	Set saleHour = +$Extract(normalizedTs, 12, 13)

	Set sale = ##class(Silver.Sale).%New()
	Set sale.SaleId = saleId
	Set sale.SaleTimestamp = normalizedTs
	Set sale.StoreCode = storeCode
	Set sale.InternalSKU = internalSKU
	Set sale.Qty = quantity
	Set sale.Price = unitPrice
	Set sale.CategoryCode = categoryCode
	Set sale.SourceEventId = bronzeId
	Quit sale.%Save()
}

ClassMethod UpdateCadence(storeCode As %String, categoryCode As %String, internalSKU As %String, saleDate As %Date, saleHour As %Integer, quantity As %Integer, lineTotal As %Numeric, Output paceId As %String, Output unitsBudget As %Integer, Output revenueBudget As %Numeric, Output unitsCumulative As %Integer, Output revenueCumulative As %Numeric, Output varianceUnits As %Numeric) As %Status
{
	Set status = ..SaveCadenceRow(storeCode, categoryCode, "__CATEGORY__", saleDate, saleHour, quantity, lineTotal, .paceId, .unitsBudget, .revenueBudget, .unitsCumulative, .revenueCumulative, .varianceUnits)
	If $SYSTEM.Status.IsError(status) Quit status

	If internalSKU'="" {
		Set status = ..SaveCadenceRow(storeCode, categoryCode, internalSKU, saleDate, saleHour, quantity, lineTotal, .skuCadenceId, .skuUnitsBudget, .skuRevenueBudget, .skuUnitsCumulative, .skuRevenueCumulative, .skuVarianceUnits)
		If $SYSTEM.Status.IsError(status) Quit status
	}

	Quit $$$OK
}

ClassMethod SaveCadenceRow(storeCode As %String, categoryCode As %String, internalSKU As %String, saleDate As %Date, saleHour As %Integer, quantity As %Integer, lineTotal As %Numeric, Output cadenceId As %String, Output unitsBudget As %Numeric, Output revenueBudget As %Numeric, Output unitsCumulative As %Numeric, Output revenueCumulative As %Numeric, Output varianceUnits As %Numeric) As %Status
{
	Set cadenceId = ..BuildCadenceId(storeCode, categoryCode, internalSKU, saleDate, saleHour)
	Set dailyUnitsBudget = ..GetBudgetUnits(saleDate, storeCode, categoryCode, internalSKU)
	Set dailyRevenueBudget = ..GetBudgetRevenue(saleDate, storeCode, categoryCode, internalSKU)
	Set unitsBudget = ..ExpectedBudgetAtHour(dailyUnitsBudget, saleHour)
	Set revenueBudget = ..ExpectedBudgetAtHour(dailyRevenueBudget, saleHour)

	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID, UnitsSold, RevenueSold FROM Gold.SalesCadence WHERE CadenceId = ?")
	If $SYSTEM.Status.IsError(sc) Quit sc
	Set rs = stmt.%Execute(cadenceId)
	Set existingCadence = 0
	Set currentHourUnits = quantity
	Set currentHourRevenue = lineTotal
	If rs.%Next() {
		Set existingCadence = ##class(Gold.SalesCadence).%OpenId(rs.%GetData(1))
		Set currentHourUnits = +existingCadence.UnitsSold + quantity
		Set currentHourRevenue = +existingCadence.RevenueSold + lineTotal
	}

	Set priorUnits = 0
	Set priorRevenue = 0
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT UnitsCumulative, RevenueCumulative FROM Gold.SalesCadence WHERE CadenceDate = ? AND CadenceHour < ? AND StoreCode = ? AND CategoryCode = ? AND InternalSKU = ? ORDER BY CadenceHour DESC")
	If $SYSTEM.Status.IsError(sc) Quit sc
	Set rs = stmt.%Execute(saleDate, saleHour, storeCode, categoryCode, internalSKU)
	If rs.%Next() {
		Set priorUnits = +rs.%GetData(1)
		Set priorRevenue = +rs.%GetData(2)
	}

	Set unitsCumulative = priorUnits + currentHourUnits
	Set revenueCumulative = priorRevenue + currentHourRevenue
	Set varianceUnits = unitsCumulative - unitsBudget
	Set varianceRevenue = revenueCumulative - revenueBudget
	Set lastUpdated = $ZDATETIME($HOROLOG, 3, 1)

	Set cadence = $Select($IsObject(existingCadence):existingCadence, 1:##class(Gold.SalesCadence).%New())
	Set cadence.CadenceId = cadenceId
	Set cadence.CadenceDate = saleDate
	Set cadence.CadenceHour = saleHour
	Set cadence.StoreCode = storeCode
	Set cadence.CategoryCode = categoryCode
	Set cadence.InternalSKU = internalSKU
	Set cadence.UnitsSold = currentHourUnits
	Set cadence.RevenueSold = currentHourRevenue
	Set cadence.UnitsBudget = unitsBudget
	Set cadence.RevenueBudget = revenueBudget
	Set cadence.UnitsCumulative = unitsCumulative
	Set cadence.RevenueCumulative = revenueCumulative
	Set cadence.VarianceUnits = varianceUnits
	Set cadence.VarianceRevenue = varianceRevenue
	Set cadence.LastUpdated = lastUpdated
	Quit cadence.%Save()
}

ClassMethod EvaluateRules(storeCode As %String, categoryCode As %String, saleDate As %Date, saleHour As %Integer, paceId As %String, unitsBudget As %Integer, revenueBudget As %Numeric, unitsCumulative As %Integer, revenueCumulative As %Numeric, varianceUnits As %Numeric, Output recommendationId As %String) As %Status
{
	Set recommendationId = ""
	Set ruleCode = ""
	Set rulePriority = 99
	Set ruleWindowType = "CADENCIA"
	Set ruleThreshold = -25
	Set ruleObservedValue = varianceUnits
	Set ruleSeverity = "LOW"
	Set businessMessage = "Sin accion requerida"
	Set executionState = "NEW"
	If ##class(Rules.PaceRules).IsCritical(varianceUnits) {
		Set ruleCode = "PACE_NEGATIVE_CRITICAL"
		Set ruleSeverity = "HIGH"
		Set businessMessage = "Critical cadence deviation detected"
	} ElseIf ##class(Rules.PaceRules).IsSustained(..CountBelowThreshold(storeCode, categoryCode, saleDate, saleHour, -10), 3) {
		Set ruleCode = "PACE_NEGATIVE_SUSTAINED"
		Set ruleWindowType = "RACHA_HORARIA"
		Set ruleThreshold = 3
		Set ruleObservedValue = ..CountBelowThreshold(storeCode, categoryCode, saleDate, saleHour, -10)
		Set ruleSeverity = "MEDIUM"
		Set businessMessage = "Cadence has been below threshold for consecutive windows"
	} ElseIf ##class(Rules.PaceRules).IsStockoutInferred(..CountWithoutSales(storeCode, categoryCode, saleDate, saleHour), 2) {
		Set ruleCode = "STOCKOUT_INFERRED"
		Set ruleWindowType = "SIN_VENTAS"
		Set ruleThreshold = 2
		Set ruleObservedValue = ..CountWithoutSales(storeCode, categoryCode, saleDate, saleHour)
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

ClassMethod BuildCadenceId(storeCode As %String, categoryCode As %String, internalSKU As %String, saleDate As %Date, saleHour As %Integer) As %String
{
	Set scopeSKU = $Select(internalSKU'="":$ZCONVERT(internalSKU, "U"), 1:"__CATEGORY__")
	Quit storeCode _ "|" _ categoryCode _ "|" _ scopeSKU _ "|" _ saleDate _ "|" _ saleHour
}

ClassMethod BuildPaceId(storeCode As %String, categoryCode As %String, saleDate As %Date, saleHour As %Integer) As %String
{
	Quit ..BuildCadenceId(storeCode, categoryCode, "__CATEGORY__", saleDate, saleHour)
}

ClassMethod CalculatePct(actual As %Numeric, budget As %Numeric) As %Numeric
{
	If budget = 0 Quit 0
	Quit (actual / budget) * 100
}

ClassMethod ExpectedBudgetAtHour(dailyBudget As %Numeric, saleHour As %Integer) As %Numeric
{
	Set hourFraction = (saleHour + 1) / 24
	If hourFraction < 0 Set hourFraction = 0
	If hourFraction > 1 Set hourFraction = 1
	Quit dailyBudget * hourFraction
}

ClassMethod GetBudgetUnits(saleDate As %Date, storeCode As %String, categoryCode As %String, internalSKU As %String = "") As %Integer
{
	Set internalSKU = $Select(internalSKU'="":$ZCONVERT(internalSKU, "U"), 1:"")
	Set stmt = ##class(%SQL.Statement).%New()
	If internalSKU'="" {
		Set sc = stmt.%Prepare("SELECT TargetUnits FROM MD.SalesBudget WHERE BudgetDate = ? AND StoreCode = ? AND CategoryCode = ? AND InternalSKU = ?")
		If '$SYSTEM.Status.IsError(sc) {
			Set rs = stmt.%Execute(saleDate, storeCode, categoryCode, internalSKU)
			If rs.%Next() Quit +rs.%GetData(1)
		}
	}
	Set sc = stmt.%Prepare("SELECT TargetUnits FROM MD.SalesBudget WHERE BudgetDate = ? AND StoreCode = ? AND CategoryCode = ? AND (InternalSKU IS NULL OR InternalSKU = '')")
	If '$SYSTEM.Status.IsError(sc) {
		Set rs = stmt.%Execute(saleDate, storeCode, categoryCode)
		If rs.%Next() Quit +rs.%GetData(1)
	}
	Quit +$Get(^IRIS111("budget", saleDate, storeCode, categoryCode, "__CATEGORY__", "units"), 0)
}

ClassMethod GetBudgetRevenue(saleDate As %Date, storeCode As %String, categoryCode As %String, internalSKU As %String = "") As %Numeric
{
	Set internalSKU = $Select(internalSKU'="":$ZCONVERT(internalSKU, "U"), 1:"")
	Set stmt = ##class(%SQL.Statement).%New()
	If internalSKU'="" {
		Set sc = stmt.%Prepare("SELECT TargetRevenue FROM MD.SalesBudget WHERE BudgetDate = ? AND StoreCode = ? AND CategoryCode = ? AND InternalSKU = ?")
		If '$SYSTEM.Status.IsError(sc) {
			Set rs = stmt.%Execute(saleDate, storeCode, categoryCode, internalSKU)
			If rs.%Next() Quit +rs.%GetData(1)
		}
	}
	Set sc = stmt.%Prepare("SELECT TargetRevenue FROM MD.SalesBudget WHERE BudgetDate = ? AND StoreCode = ? AND CategoryCode = ? AND (InternalSKU IS NULL OR InternalSKU = '')")
	If '$SYSTEM.Status.IsError(sc) {
		Set rs = stmt.%Execute(saleDate, storeCode, categoryCode)
		If rs.%Next() Quit +rs.%GetData(1)
	}
	Quit +$Get(^IRIS111("budget", saleDate, storeCode, categoryCode, "__CATEGORY__", "revenue"), 0)
}

ClassMethod CountBelowThreshold(storeCode As %String, categoryCode As %String, saleDate As %Date, saleHour As %Integer, threshold As %Numeric = -25) As %Integer
{
	New count
	Set count = 0
	&sql(SELECT COUNT(*) INTO :count
		FROM Gold.SalesCadence
		WHERE StoreCode = :storeCode
		  AND CategoryCode = :categoryCode
		  AND InternalSKU = '__CATEGORY__'
		  AND CadenceDate = :saleDate
		  AND CadenceHour <= :saleHour
		  AND VarianceUnits <= :threshold)
	Quit +$Get(count, 0)
}

ClassMethod CountWithoutSales(storeCode As %String, categoryCode As %String, saleDate As %Date, saleHour As %Integer) As %Integer
{
	New count
	Set count = 0
	&sql(SELECT COUNT(*) INTO :count
		FROM Gold.SalesCadence
		WHERE StoreCode = :storeCode
		  AND CategoryCode = :categoryCode
		  AND InternalSKU = '__CATEGORY__'
		  AND CadenceDate = :saleDate
		  AND CadenceHour <= :saleHour
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
	If ruleCode = "PACE_NEGATIVE_CRITICAL" Quit "Desvio critico de cadencia"
	If ruleCode = "PACE_NEGATIVE_SUSTAINED" Quit "Desvio sostenido de cadencia"
	If ruleCode = "STOCKOUT_INFERRED" Quit "Stockout inferido por cero ventas"
	Quit "Manual review required"
}

}
