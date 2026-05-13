Class Service.BudgetImportService
{

ClassMethod ImportCsv(csvText As %String) As %Status
{
	If csvText = "" {
		Quit $SYSTEM.Status.Error(5001, "Budget CSV is required")
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
				Quit $SYSTEM.Status.Error(5001, "Budget CSV header is invalid")
			}
			Continue
		}

		Set status = ..ImportLine(line)
		If $SYSTEM.Status.IsError(status) {
			Quit status
		}

		Set importedCount = importedCount + 1
	}

	Quit 1
}

ClassMethod ImportLine(line As %String) As %Status
{
	Set parts = $Length(line, ",")
	If parts < 5 {
		Quit $SYSTEM.Status.Error(5001, "Budget CSV line must contain at least 5 columns")
	}

	Set budgetDate = $ZStrip($Piece(line, ",", 1), "<>", " ")
	Set storeCode = $ZStrip($Piece(line, ",", 2), "<>", " ")
	Set categoryCode = $ZStrip($Piece(line, ",", 3), "<>", " ")
	Set targetUnits = $ZStrip($Piece(line, ",", 4), "<>", " ")
	Set targetRevenue = $ZStrip($Piece(line, ",", 5), "<>", " ")
	Set budgetDate = $ZDATEH(budgetDate, 3)

	If budgetDate = "" || storeCode = "" || categoryCode = "" {
		Quit $SYSTEM.Status.Error(5001, "Budget CSV line has required blank fields")
	}

	Set loadedAt = $ZDATETIME($HOROLOG, 3, 1)
	Set ^IRIS111("budget", budgetDate, storeCode, categoryCode, "units") = +targetUnits
	Set ^IRIS111("budget", budgetDate, storeCode, categoryCode, "revenue") = +targetRevenue
	Set stmt = ##class(%SQL.Statement).%New()
	Set sql = "SELECT %ID FROM MD.SalesBudget WHERE BudgetDate = ? AND StoreCode = ? AND CategoryCode = ?"
	Set sc = stmt.%Prepare(sql)
	If $SYSTEM.Status.IsError(sc) Quit sc
	Set rs = stmt.%Execute(budgetDate, storeCode, categoryCode)

	If rs.%Next() {
		Set rowId = rs.%GetData(1)
		Set stmt = ##class(%SQL.Statement).%New()
		Set sql = "UPDATE MD.SalesBudget SET TargetUnits = ?, TargetRevenue = ?, LoadedAt = ? WHERE %ID = ?"
		Set sc = stmt.%Prepare(sql)
		If $SYSTEM.Status.IsError(sc) Quit sc
		Do stmt.%Execute(+targetUnits, +targetRevenue, loadedAt, rowId)
		Quit 1
	}

	Set stmt = ##class(%SQL.Statement).%New()
	Set sql = "INSERT INTO MD.SalesBudget (BudgetDate, StoreCode, CategoryCode, TargetUnits, TargetRevenue, LoadedAt) VALUES (?, ?, ?, ?, ?, ?)"
	Set sc = stmt.%Prepare(sql)
	If $SYSTEM.Status.IsError(sc) Quit sc
	Do stmt.%Execute(budgetDate, storeCode, categoryCode, +targetUnits, +targetRevenue, loadedAt)
	Quit 1
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
