Class MD.SalesBudget Extends %Persistent
{

Property BudgetDate As %Date [ Required ];
Property StoreCode As %String(MAXLEN = 20) [ Required ];
Property CategoryCode As %String(MAXLEN = 50) [ Required ];
Property TargetUnits As %Integer;
Property TargetRevenue As %Numeric;
Property LoadedAt As %TimeStamp;

Index BudgetKeyIdx On BudgetDate, StoreCode, CategoryCode [ Unique ];

}
