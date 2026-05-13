Class Process.BudgetProcessingBPL
{

ClassMethod HandleCsv(csvText As %String) As %Status
{
	Set status = ##class(Service.BudgetImportService).ImportCsv(csvText)
	If $SYSTEM.Status.IsError(status) Quit status
	Quit 1
}

}
