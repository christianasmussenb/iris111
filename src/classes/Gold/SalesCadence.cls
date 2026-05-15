Class Gold.SalesCadence Extends %Persistent
{

Property CadenceId As %String(MAXLEN = 120) [ Required ];
Property CadenceDate As %Date(FORMAT = 3) [ Required ];
Property CadenceHour As %Integer [ Required ];
Property StoreCode As %String(MAXLEN = 20) [ Required ];
Property CategoryCode As %String(MAXLEN = 50) [ Required ];
Property InternalSKU As %String(MAXLEN = 50) [ Required ];
Property UnitsSold As %Integer;
Property RevenueSold As %Numeric;
Property UnitsBudget As %Integer;
Property RevenueBudget As %Numeric;
Property UnitsCumulative As %Integer;
Property RevenueCumulative As %Numeric;
Property VarianceUnits As %Numeric;
Property VarianceRevenue As %Numeric;
Property LastUpdated As %TimeStamp;

Index CadenceIdIdx On CadenceId [ Unique ];
Index CadenceLookupIdx On (CadenceDate, CadenceHour, StoreCode, CategoryCode, InternalSKU);

Storage Default
{
<Data name="SalesCadenceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CadenceId</Value>
</Value>
<Value name="3">
<Value>CadenceDate</Value>
</Value>
<Value name="4">
<Value>CadenceHour</Value>
</Value>
<Value name="5">
<Value>StoreCode</Value>
</Value>
<Value name="6">
<Value>CategoryCode</Value>
</Value>
<Value name="7">
<Value>InternalSKU</Value>
</Value>
<Value name="8">
<Value>UnitsSold</Value>
</Value>
<Value name="9">
<Value>RevenueSold</Value>
</Value>
<Value name="10">
<Value>UnitsBudget</Value>
</Value>
<Value name="11">
<Value>RevenueBudget</Value>
</Value>
<Value name="12">
<Value>UnitsCumulative</Value>
</Value>
<Value name="13">
<Value>RevenueCumulative</Value>
</Value>
<Value name="14">
<Value>VarianceUnits</Value>
</Value>
<Value name="15">
<Value>VarianceRevenue</Value>
</Value>
<Value name="16">
<Value>LastUpdated</Value>
</Value>
</Data>
<DataLocation>^Gold.SalesCadenceD</DataLocation>
<DefaultData>SalesCadenceDefaultData</DefaultData>
<IdLocation>^Gold.SalesCadenceD</IdLocation>
<IndexLocation>^Gold.SalesCadenceI</IndexLocation>
<StreamLocation>^Gold.SalesCadenceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}