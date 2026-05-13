Class Rules.PaceRules
{

ClassMethod IsCritical(varianceUnits As %Numeric, threshold As %Numeric = -25) As %Boolean
{
    Quit varianceUnits <= threshold
}

ClassMethod IsSustained(consecutiveBelowThreshold As %Integer, requiredHours As %Integer = 3) As %Boolean
{
    Quit consecutiveBelowThreshold >= requiredHours
}

ClassMethod IsStockoutInferred(hoursWithoutSales As %Integer, minimumHours As %Integer = 2) As %Boolean
{
    Quit hoursWithoutSales >= minimumHours
}

}
