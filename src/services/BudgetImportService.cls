Class Service.BudgetImportService
{

Include %occStatus

ClassMethod ImportCsv(csvText As %String) As %Status
{
	If csvText = "" {
		Quit $$$ERROR($$$GeneralError, "Budget CSV is required")
	}

	Set lineCount = 0
	Set importedCount = 0
	Set headerSeen = 0

	For i = 1:1:$Length(csvText, $Char(10)) {
		Set line = $ZSTRIP($Piece(csvText, $Char(10), i), "<>", $Char(13))
		If line = "" {
			Continue
		}

		Set lineCount = lineCount + 1

		If 'headerSeen {
			Set headerSeen = 1
			If ..ValidateHeader(line)=0 {
				Quit $$$ERROR($$$GeneralError, "Budget CSV header is invalid")
			}
			Continue
		}

		Set status = ..ImportLine(line)
		If $$$ISERR(status) {
			Quit status
		}

		Set importedCount = importedCount + 1
	}

	Quit $$$OK
}

ClassMethod ImportLine(line As %String) As %Status
{
	Set parts = $Length(line, ",")
	If parts < 5 {
		Quit $$$ERROR($$$GeneralError, "Budget CSV line must contain at least 5 columns")
	}

	Set budgetDate = $ZStrip($Piece(line, ",", 1), "<>", " ")
	Set storeCode = $ZStrip($Piece(line, ",", 2), "<>", " ")
	Set categoryCode = $ZStrip($Piece(line, ",", 3), "<>", " ")
	Set targetUnits = $ZStrip($Piece(line, ",", 4), "<>", " ")
	Set targetRevenue = $ZStrip($Piece(line, ",", 5), "<>", " ")

	If budgetDate = "" || storeCode = "" || categoryCode = "" {
		Quit $$$ERROR($$$GeneralError, "Budget CSV line has required blank fields")
	}

	Set budget = ##class(MD.SalesBudget).%New()
	Set budget.BudgetDate = budgetDate
	Set budget.StoreCode = storeCode
	Set budget.CategoryCode = categoryCode
	Set budget.TargetUnits = +targetUnits
	Set budget.TargetRevenue = +targetRevenue
	Set budget.LoadedAt = $ZDATETIME($HOROLOG, 3, 1)

	Quit budget.%Save()
}

ClassMethod ValidateHeader(headerLine As %String) As %Boolean
{
	Set normalized = $ZCONVERT($ZSTRIP(headerLine, "<>", " "), "L")
	If normalized'["budget_date" Quit 0
	If normalized'["store_code" Quit 0
	If normalized'["category_code" Quit 0
	If normalized'["target_units" Quit 0
	If normalized'["target_revenue" Quit 0
	Quit 1
}

}
