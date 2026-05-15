Class Gold.CategoryPace Extends %Persistent
{

Property PaceId As %String(MAXLEN = 80) [ Required ];
Property PaceDate As %Date(FORMAT = 3) [ Required ];
Property PaceHour As %Integer;
Property StoreCode As %String(MAXLEN = 20) [ Required ];
Property CategoryCode As %String(MAXLEN = 50) [ Required ];
Property UnitsSold As %Integer;
Property RevenueSold As %Numeric;
Property UnitsBudget As %Integer;
Property RevenueBudget As %Numeric;
Property UnitsCumulative As %Integer;
Property RevenueCumulative As %Numeric;
Property PctPaceUnits As %Numeric;
Property PctPaceRevenue As %Numeric;
Property VarianceUnits As %Numeric;
Property VarianceRevenue As %Numeric;
Property LastUpdated As %TimeStamp;

Index PaceKeyIdx On (PaceDate, PaceHour, StoreCode, CategoryCode) [ Unique ];

Storage Default
{
<Data name="CategoryPaceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>PaceId</Value>
</Value>
<Value name="3">
<Value>PaceDate</Value>
</Value>
<Value name="4">
<Value>PaceHour</Value>
</Value>
<Value name="5">
<Value>StoreCode</Value>
</Value>
<Value name="6">
<Value>CategoryCode</Value>
</Value>
<Value name="7">
<Value>UnitsSold</Value>
</Value>
<Value name="8">
<Value>RevenueSold</Value>
</Value>
<Value name="9">
<Value>UnitsBudget</Value>
</Value>
<Value name="10">
<Value>RevenueBudget</Value>
</Value>
<Value name="11">
<Value>UnitsCumulative</Value>
</Value>
<Value name="12">
<Value>RevenueCumulative</Value>
</Value>
<Value name="13">
<Value>PctPaceUnits</Value>
</Value>
<Value name="14">
<Value>PctPaceRevenue</Value>
</Value>
<Value name="15">
<Value>VarianceUnits</Value>
</Value>
<Value name="16">
<Value>VarianceRevenue</Value>
</Value>
<Value name="17">
<Value>LastUpdated</Value>
</Value>
</Data>
<DataLocation>^Gold.CategoryPaceD</DataLocation>
<DefaultData>CategoryPaceDefaultData</DefaultData>
<IdLocation>^Gold.CategoryPaceD</IdLocation>
<IndexLocation>^Gold.CategoryPaceI</IndexLocation>
<StreamLocation>^Gold.CategoryPaceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
