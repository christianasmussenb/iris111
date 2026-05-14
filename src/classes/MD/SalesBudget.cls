Class MD.SalesBudget Extends %Persistent
{

Property BudgetDate As %Date [ Required ];
Property StoreCode As %String(MAXLEN = 20) [ Required ];
Property CategoryCode As %String(MAXLEN = 50) [ Required ];
Property InternalSKU As %String(MAXLEN = 50);
Property TargetUnits As %Integer;
Property TargetRevenue As %Numeric;
Property LoadedAt As %TimeStamp;

Index BudgetKeyIdx On (BudgetDate, StoreCode, CategoryCode, InternalSKU) [ Unique ];

Storage Default
{
<Data name="SalesBudgetDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>BudgetDate</Value>
</Value>
<Value name="3">
<Value>StoreCode</Value>
</Value>
<Value name="4">
<Value>CategoryCode</Value>
</Value>
<Value name="5">
<Value>InternalSKU</Value>
</Value>
<Value name="6">
<Value>TargetUnits</Value>
</Value>
<Value name="7">
<Value>TargetRevenue</Value>
</Value>
<Value name="8">
<Value>LoadedAt</Value>
</Value>
</Data>
<DataLocation>^MD.SalesBudgetD</DataLocation>
<DefaultData>SalesBudgetDefaultData</DefaultData>
<IdLocation>^MD.SalesBudgetD</IdLocation>
<IndexLocation>^MD.SalesBudgetI</IndexLocation>
<StreamLocation>^MD.SalesBudgetS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
