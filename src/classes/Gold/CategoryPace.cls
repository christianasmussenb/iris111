Class Gold.CategoryPace Extends %Persistent
{

Property PaceId As %String(MAXLEN = 80) [ Required ];
Property PaceDate As %Date [ Required ];
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

}
