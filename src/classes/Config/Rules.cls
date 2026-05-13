Class Config.Rules Extends %Persistent
{

Property RuleCode As %String(MAXLEN = 50) [ Required ];
Property RuleName As %String(MAXLEN = 100);
Property Severity As %String(MAXLEN = 20);
Property ThresholdValue As %Numeric;
Property WindowHours As %Integer;
Property IsActive As %Boolean [ InitialExpression = 1 ];
Property Description As %String(MAXLEN = 500);

Index RuleCodeIdx On RuleCode [ Unique ];

}
