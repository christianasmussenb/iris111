Class Service.MockDataImportService
{

ClassMethod ImportAll(dataDir As %String = "/iris/data") As %Status
{
	Set sc = ..ImportCategories(dataDir _ "/categories.csv")
	If $SYSTEM.Status.IsError(sc) Quit sc

	Set sc = ..ImportStores(dataDir _ "/stores.csv")
	If $SYSTEM.Status.IsError(sc) Quit sc

	Set sc = ..ImportSkus(dataDir _ "/skus.csv")
	If $SYSTEM.Status.IsError(sc) Quit sc

	Set sc = ..ImportPrices(dataDir _ "/prices.csv")
	If $SYSTEM.Status.IsError(sc) Quit sc

	Set sc = ..ImportBudgets(dataDir _ "/budgets.csv")
	If $SYSTEM.Status.IsError(sc) Quit sc

	Quit $$$OK
}

ClassMethod ImportCategories(filePath As %String) As %Status
{
	Set text = ..ReadTextFile(filePath)
	If text = "" Quit $SYSTEM.Status.Error(5001, "Categories file is required")

	For i = 1:1:$Length(text, $Char(10)) {
		Set line = $ZSTRIP($Piece(text, $Char(10), i), "<>", $Char(13))
		If line = "" Continue
		If i = 1 Continue

		Set categoryCode = $ZStrip($Piece(line, ",", 1), "<>", " ")
		Set categoryName = $ZStrip($Piece(line, ",", 2), "<>", " ")
		If categoryCode = "" Continue

		Set obj = ..GetCategory(categoryCode)
		Set obj.CategoryCode = categoryCode
		Set obj.CategoryName = categoryName
		Set sc = obj.%Save()
		If $SYSTEM.Status.IsError(sc) Quit sc
	}

	Quit $$$OK
}

ClassMethod ImportStores(filePath As %String) As %Status
{
	Set text = ..ReadTextFile(filePath)
	If text = "" Quit $SYSTEM.Status.Error(5001, "Stores file is required")

	For i = 1:1:$Length(text, $Char(10)) {
		Set line = $ZSTRIP($Piece(text, $Char(10), i), "<>", $Char(13))
		If line = "" Continue
		If i = 1 Continue

		Set storeCode = $ZStrip($Piece(line, ",", 1), "<>", " ")
		Set storeName = $ZStrip($Piece(line, ",", 2), "<>", " ")
		Set region = $ZStrip($Piece(line, ",", 3), "<>", " ")
		Set district = $ZStrip($Piece(line, ",", 4), "<>", " ")
		Set timezone = $ZStrip($Piece(line, ",", 5), "<>", " ")
		If storeCode = "" Continue

		Set obj = ..GetStore(storeCode)
		Set obj.StoreCode = storeCode
		Set obj.StoreName = storeName
		Set obj.Region = region
		Set obj.District = district
		Set obj.TimeZone = timezone
		Set sc = obj.%Save()
		If $SYSTEM.Status.IsError(sc) Quit sc
	}

	Quit $$$OK
}

ClassMethod ImportSkus(filePath As %String) As %Status
{
	Set text = ..ReadTextFile(filePath)
	If text = "" Quit $SYSTEM.Status.Error(5001, "SKUs file is required")

	For i = 1:1:$Length(text, $Char(10)) {
		Set line = $ZSTRIP($Piece(text, $Char(10), i), "<>", $Char(13))
		If line = "" Continue
		If i = 1 Continue

		Set internalSKU = $ZStrip($Piece(line, ",", 1), "<>", " ")
		Set vendorSKU = $ZStrip($Piece(line, ",", 2), "<>", " ")
		Set categoryCode = $ZStrip($Piece(line, ",", 3), "<>", " ")
		Set uom = $ZStrip($Piece(line, ",", 4), "<>", " ")
		If internalSKU = "" Continue

		Set obj = ..GetSKU(internalSKU)
		Set obj.InternalSKU = internalSKU
		Set obj.VendorSKU = vendorSKU
		Set obj.CategoryCode = categoryCode
		Set obj.UnitOfMeasure = uom
		Set sc = obj.%Save()
		If $SYSTEM.Status.IsError(sc) Quit sc
	}

	Quit $$$OK
}

ClassMethod ImportPrices(filePath As %String) As %Status
{
	Set text = ..ReadTextFile(filePath)
	If text = "" Quit $SYSTEM.Status.Error(5001, "Prices file is required")

	For i = 1:1:$Length(text, $Char(10)) {
		Set line = $ZSTRIP($Piece(text, $Char(10), i), "<>", $Char(13))
		If line = "" Continue
		If i = 1 Continue

		Set startDate = $ZStrip($Piece(line, ",", 1), "<>", " ")
		Set endDate = $ZStrip($Piece(line, ",", 2), "<>", " ")
		Set storeCode = $ZStrip($Piece(line, ",", 3), "<>", " ")
		Set internalSKU = $ZStrip($Piece(line, ",", 4), "<>", " ")
		Set price = $ZStrip($Piece(line, ",", 5), "<>", " ")
		Set currency = $ZStrip($Piece(line, ",", 6), "<>", " ")
		If startDate = "" || storeCode = "" || internalSKU = "" Continue

		Set obj = ..GetPrice(storeCode, internalSKU, $ZDATEH(startDate, 3))
		Set obj.StoreCode = storeCode
		Set obj.InternalSKU = internalSKU
		Set obj.EffectiveStartDate = $ZDATEH(startDate, 3)
		Set obj.EffectiveEndDate = $Select(endDate'="":$ZDATEH(endDate, 3), 1:"")
		Set obj.Price = +price
		Set obj.Currency = $Select(currency'="":currency, 1:"COP")
		Set obj.LoadedAt = $ZDATETIME($HOROLOG, 3, 1)
		Set sc = obj.%Save()
		If $SYSTEM.Status.IsError(sc) Quit sc
	}

	Quit $$$OK
}

ClassMethod ImportBudgets(filePath As %String) As %Status
{
	Set text = ..ReadTextFile(filePath)
	If text = "" Quit $SYSTEM.Status.Error(5001, "Budgets file is required")

	For i = 1:1:$Length(text, $Char(10)) {
		Set line = $ZSTRIP($Piece(text, $Char(10), i), "<>", $Char(13))
		If line = "" Continue
		If i = 1 Continue

		Set budgetDate = $ZStrip($Piece(line, ",", 1), "<>", " ")
		Set storeCode = $ZStrip($Piece(line, ",", 2), "<>", " ")
		Set categoryCode = $ZStrip($Piece(line, ",", 3), "<>", " ")
		Set targetUnits = $ZStrip($Piece(line, ",", 4), "<>", " ")
		Set targetRevenue = $ZStrip($Piece(line, ",", 5), "<>", " ")
		If budgetDate = "" || storeCode = "" || categoryCode = "" Continue

		Set obj = ..GetBudget($ZDATEH(budgetDate, 3), storeCode, categoryCode, "")
		Set obj.BudgetDate = $ZDATEH(budgetDate, 3)
		Set obj.StoreCode = storeCode
		Set obj.CategoryCode = categoryCode
		Set obj.InternalSKU = ""
		Set obj.TargetUnits = +targetUnits
		Set obj.TargetRevenue = +targetRevenue
		Set obj.LoadedAt = $ZDATETIME($HOROLOG, 3, 1)
		Set sc = obj.%Save()
		If $SYSTEM.Status.IsError(sc) Quit sc
	}

	Quit $$$OK
}

ClassMethod GetCategory(categoryCode As %String) As MD.Category
{
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID FROM MD.Category WHERE CategoryCode = ?")
	If $SYSTEM.Status.IsError(sc) Quit ##class(MD.Category).%New()
	Set rs = stmt.%Execute(categoryCode)
	If rs.%Next() {
		Set obj = ##class(MD.Category).%OpenId(rs.%GetData(1))
		If $IsObject(obj) Quit obj
	}
	Quit ##class(MD.Category).%New()
}

ClassMethod GetStore(storeCode As %String) As MD.Store
{
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID FROM MD.Store WHERE StoreCode = ?")
	If $SYSTEM.Status.IsError(sc) Quit ##class(MD.Store).%New()
	Set rs = stmt.%Execute(storeCode)
	If rs.%Next() {
		Set obj = ##class(MD.Store).%OpenId(rs.%GetData(1))
		If $IsObject(obj) Quit obj
	}
	Quit ##class(MD.Store).%New()
}

ClassMethod GetSKU(internalSKU As %String) As MD.SKU
{
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID FROM MD.SKU WHERE InternalSKU = ?")
	If $SYSTEM.Status.IsError(sc) Quit ##class(MD.SKU).%New()
	Set rs = stmt.%Execute(internalSKU)
	If rs.%Next() {
		Set obj = ##class(MD.SKU).%OpenId(rs.%GetData(1))
		If $IsObject(obj) Quit obj
	}
	Quit ##class(MD.SKU).%New()
}

ClassMethod GetPrice(storeCode As %String, internalSKU As %String, effectiveStartDate As %Date) As MD.SKUPrice
{
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID FROM MD.SKUPrice WHERE StoreCode = ? AND InternalSKU = ? AND EffectiveStartDate = ?")
	If $SYSTEM.Status.IsError(sc) Quit ##class(MD.SKUPrice).%New()
	Set rs = stmt.%Execute(storeCode, internalSKU, effectiveStartDate)
	If rs.%Next() {
		Set obj = ##class(MD.SKUPrice).%OpenId(rs.%GetData(1))
		If $IsObject(obj) Quit obj
	}
	Quit ##class(MD.SKUPrice).%New()
}

ClassMethod GetBudget(budgetDate As %Date, storeCode As %String, categoryCode As %String, internalSKU As %String) As MD.SalesBudget
{
	Set stmt = ##class(%SQL.Statement).%New()
	Set sc = stmt.%Prepare("SELECT %ID FROM MD.SalesBudget WHERE BudgetDate = ? AND StoreCode = ? AND CategoryCode = ? AND InternalSKU = ?")
	If $SYSTEM.Status.IsError(sc) Quit ##class(MD.SalesBudget).%New()
	Set rs = stmt.%Execute(budgetDate, storeCode, categoryCode, internalSKU)
	If rs.%Next() {
		Set obj = ##class(MD.SalesBudget).%OpenId(rs.%GetData(1))
		If $IsObject(obj) Quit obj
	}
	Quit ##class(MD.SalesBudget).%New()
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